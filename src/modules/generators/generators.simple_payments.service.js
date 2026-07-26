const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema, writeAuditLog } = require('./generators.db');

const BILLING_SCHEMA_FILE = path.join(__dirname, 'generators.simple_billing.schema.sql');
const PAYMENTS_SCHEMA_FILE = path.join(__dirname, 'generators.simple_payments.schema.sql');
const initializedDatabases = new WeakSet();
const PAYMENT_METHODS = new Set(['cash', 'transfer']);
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function paymentsDb() {
  const db = ensureGeneratorsSchema();
  if (!initializedDatabases.has(db)) {
    db.exec(fs.readFileSync(BILLING_SCHEMA_FILE, 'utf8'));
    ensureInvoicePaymentColumns(db);
    db.exec(fs.readFileSync(PAYMENTS_SCHEMA_FILE, 'utf8'));
    initializedDatabases.add(db);
  }
  return db;
}

function ensureInvoicePaymentColumns(db) {
  const columns = new Set(
    db.prepare("PRAGMA table_info('generator_monthly_invoices')").all().map((row) => row.name)
  );
  if (!columns.has('paid_amount_iqd')) {
    db.exec('ALTER TABLE generator_monthly_invoices ADD COLUMN paid_amount_iqd INTEGER NOT NULL DEFAULT 0');
  }
  if (!columns.has('remaining_amount_iqd')) {
    db.exec('ALTER TABLE generator_monthly_invoices ADD COLUMN remaining_amount_iqd INTEGER');
  }
  if (!columns.has('payment_status')) {
    db.exec("ALTER TABLE generator_monthly_invoices ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'unpaid'");
  }
  if (!columns.has('last_payment_at')) {
    db.exec('ALTER TABLE generator_monthly_invoices ADD COLUMN last_payment_at TEXT');
  }
  db.exec(`
    UPDATE generator_monthly_invoices
    SET remaining_amount_iqd = MAX(0, amount_iqd - COALESCE(paid_amount_iqd, 0))
    WHERE remaining_amount_iqd IS NULL
  `);
}

function enrichOwnerMonthlyPeriods(auth, data) {
  assertOwner(auth);
  const db = paymentsDb();
  const totals = db.prepare(`
    SELECT period_id,
      COALESCE(SUM(paid_amount_iqd), 0) AS paid_iqd,
      COALESCE(SUM(COALESCE(remaining_amount_iqd, amount_iqd - paid_amount_iqd)), 0) AS remaining_iqd
    FROM generator_monthly_invoices
    WHERE tenant_id = ?
    GROUP BY period_id
  `).all(auth.tenantId);
  const byPeriod = new Map(totals.map((row) => [Number(row.period_id), row]));
  const periodIds = db.prepare(`
    SELECT id, public_id FROM generator_reading_periods WHERE tenant_id = ?
  `).all(auth.tenantId);
  const publicToDb = new Map(periodIds.map((row) => [row.public_id, Number(row.id)]));
  return {
    ...data,
    periods: (data.periods || []).map((period) => {
      const row = byPeriod.get(publicToDb.get(period.id));
      return {
        ...period,
        paid_iqd: Number(row?.paid_iqd || 0),
        remaining_iqd: Number(row?.remaining_iqd ?? period.total_iqd ?? 0)
      };
    }),
    collection_enabled: true,
    receipt_enabled: true
  };
}

function enrichOwnerMonthlyWorkspace(auth, workspace, periodPublicId) {
  assertOwner(auth);
  const db = paymentsDb();
  const period = findPeriod(db, auth.tenantId, periodPublicId);
  const invoiceRows = db.prepare(`
    SELECT public_id, amount_iqd,
      COALESCE(paid_amount_iqd, 0) AS paid_amount_iqd,
      COALESCE(remaining_amount_iqd, amount_iqd - COALESCE(paid_amount_iqd, 0)) AS remaining_amount_iqd,
      COALESCE(payment_status, 'unpaid') AS payment_status,
      last_payment_at
    FROM generator_monthly_invoices
    WHERE tenant_id = ? AND period_id = ?
  `).all(auth.tenantId, period.id);
  const paymentRows = db.prepare(`
    SELECT p.*, i.public_id AS invoice_public_id
    FROM generator_invoice_payments p
    JOIN generator_monthly_invoices i ON i.id = p.invoice_id
    WHERE p.tenant_id = ? AND i.period_id = ?
    ORDER BY p.created_at DESC, p.id DESC
  `).all(auth.tenantId, period.id);
  const paymentsByInvoice = new Map();
  for (const row of paymentRows) {
    const list = paymentsByInvoice.get(row.invoice_public_id) || [];
    list.push(serializePayment(row));
    paymentsByInvoice.set(row.invoice_public_id, list);
  }
  const stateByInvoice = new Map(invoiceRows.map((row) => [row.public_id, row]));
  const invoices = (workspace.invoices || []).map((invoice) => {
    const state = stateByInvoice.get(invoice.id);
    const paid = Number(state?.paid_amount_iqd || 0);
    const remaining = Number(state?.remaining_amount_iqd ?? Math.max(0, invoice.amount_iqd - paid));
    return {
      ...invoice,
      status: state?.payment_status || paymentStatus(invoice.amount_iqd, paid),
      paid_amount_iqd: paid,
      remaining_amount_iqd: remaining,
      debt_iqd: remaining,
      last_payment_at: state?.last_payment_at || null,
      payments: paymentsByInvoice.get(invoice.id) || []
    };
  });
  const totalIqd = invoices.reduce((sum, invoice) => sum + Number(invoice.amount_iqd || 0), 0);
  const paidIqd = invoices.reduce((sum, invoice) => sum + Number(invoice.paid_amount_iqd || 0), 0);
  const remainingIqd = invoices.reduce((sum, invoice) => sum + Number(invoice.remaining_amount_iqd || 0), 0);
  return {
    ...workspace,
    invoices,
    summary: {
      ...workspace.summary,
      total_iqd: totalIqd,
      paid_iqd: paidIqd,
      remaining_iqd: remainingIqd,
      unpaid_iqd: remainingIqd,
      unpaid_count: invoices.filter((invoice) => invoice.status === 'unpaid').length,
      partial_count: invoices.filter((invoice) => invoice.status === 'partial').length,
      paid_count: invoices.filter((invoice) => invoice.status === 'paid').length
    },
    invoice_is_debt: true,
    collection_enabled: true,
    receipt_enabled: true,
    separate_debt_ledger_enabled: false
  };
}

function recordOwnerInvoicePayment(auth, invoicePublicId, body) {
  assertOwner(auth);
  if (body?.confirm !== true) {
    throw httpError(400, 'PAYMENT_CONFIRM_REQUIRED', 'Confirm the payment before saving.');
  }
  const operationUuid = cleanRequired(body?.operation_uuid, 'operation_uuid', 80);
  if (!UUID_PATTERN.test(operationUuid)) {
    throw httpError(400, 'INVALID_PAYMENT_OPERATION_UUID', 'operation_uuid must be a valid UUID.');
  }
  const amount = positiveMoney(body?.amount_iqd, 'amount_iqd');
  const paymentMethod = normalizePaymentMethod(body?.payment_method);
  const note = cleanOptional(body?.note, 250);
  const db = paymentsDb();

  const duplicate = findPaymentByOperation(db, auth.tenantId, operationUuid);
  if (duplicate) {
    return {
      duplicate: true,
      payment: serializePayment(duplicate),
      invoice: serializePaymentInvoice(findInvoice(db, auth.tenantId, invoicePublicId))
    };
  }

  let invoice = findInvoice(db, auth.tenantId, invoicePublicId);
  let paid = Number(invoice.paid_amount_iqd || 0);
  let remaining = Number(invoice.remaining_amount_iqd ?? Math.max(0, Number(invoice.amount_iqd) - paid));
  if (remaining <= 0) {
    throw httpError(409, 'INVOICE_ALREADY_PAID', 'This invoice is already fully paid.');
  }
  if (amount > remaining) {
    throw httpError(409, 'PAYMENT_EXCEEDS_REMAINING', 'Payment amount is greater than the remaining invoice amount.', {
      remaining_amount_iqd: remaining
    });
  }

  let paymentPublicId;
  db.exec('BEGIN IMMEDIATE');
  try {
    const existing = findPaymentByOperation(db, auth.tenantId, operationUuid);
    if (existing) {
      db.exec('COMMIT');
      return {
        duplicate: true,
        payment: serializePayment(existing),
        invoice: serializePaymentInvoice(findInvoice(db, auth.tenantId, invoicePublicId))
      };
    }

    invoice = findInvoice(db, auth.tenantId, invoicePublicId);
    paid = Number(invoice.paid_amount_iqd || 0);
    remaining = Number(invoice.remaining_amount_iqd ?? Math.max(0, Number(invoice.amount_iqd) - paid));
    if (amount > remaining) {
      throw httpError(409, 'PAYMENT_EXCEEDS_REMAINING', 'Payment amount is greater than the remaining invoice amount.', {
        remaining_amount_iqd: remaining
      });
    }

    const afterPaid = paid + amount;
    const afterRemaining = Math.max(0, Number(invoice.amount_iqd) - afterPaid);
    const status = afterRemaining === 0 ? 'paid' : 'partial';
    const sequence = Number(db.prepare(`
      SELECT COUNT(*) AS count
      FROM generator_invoice_payments p
      JOIN generator_monthly_invoices i ON i.id = p.invoice_id
      WHERE p.tenant_id = ? AND i.period_id = ?
    `).get(auth.tenantId, invoice.period_id).count || 0) + 1;
    const receiptNumber = `REC-${String(invoice.period_key).replace('-', '')}-${String(sequence).padStart(4, '0')}`;
    paymentPublicId = crypto.randomUUID();
    db.prepare(`
      INSERT INTO generator_invoice_payments (
        public_id, tenant_id, invoice_id, operation_uuid, receipt_number,
        amount_iqd, payment_method, note, received_by_account_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      paymentPublicId,
      auth.tenantId,
      invoice.id,
      operationUuid,
      receiptNumber,
      amount,
      paymentMethod,
      note,
      auth.accountId
    );
    const now = new Date().toISOString();
    db.prepare(`
      UPDATE generator_monthly_invoices
      SET paid_amount_iqd = ?, remaining_amount_iqd = ?, payment_status = ?, last_payment_at = ?
      WHERE id = ? AND tenant_id = ?
    `).run(afterPaid, afterRemaining, status, now, invoice.id, auth.tenantId);
    db.exec('COMMIT');
  } catch (error) {
    try { db.exec('ROLLBACK'); } catch (_) {}
    throw error;
  }

  const payment = db.prepare(`
    SELECT p.*, i.public_id AS invoice_public_id
    FROM generator_invoice_payments p
    JOIN generator_monthly_invoices i ON i.id = p.invoice_id
    WHERE p.tenant_id = ? AND p.public_id = ? LIMIT 1
  `).get(auth.tenantId, paymentPublicId);
  const updatedInvoice = findInvoice(db, auth.tenantId, invoicePublicId);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.invoice.payment_recorded',
    entityType: 'generator_monthly_invoice',
    entityUuid: updatedInvoice.public_id,
    before: {
      paid_amount_iqd: paid,
      remaining_amount_iqd: remaining
    },
    after: {
      payment: serializePayment(payment),
      paid_amount_iqd: Number(updatedInvoice.paid_amount_iqd || 0),
      remaining_amount_iqd: Number(updatedInvoice.remaining_amount_iqd || 0),
      payment_status: updatedInvoice.payment_status
    }
  });
  return {
    duplicate: false,
    payment: serializePayment(payment),
    invoice: serializePaymentInvoice(updatedInvoice),
    cash_box_effect_applied: false
  };
}

function findInvoice(db, tenantId, publicId) {
  const row = db.prepare(`
    SELECT i.*, p.period_key, p.public_id AS period_public_id,
      s.public_id AS subscriber_public_id
    FROM generator_monthly_invoices i
    JOIN generator_reading_periods p ON p.id = i.period_id
    JOIN generator_subscribers s ON s.id = i.subscriber_id
    WHERE i.tenant_id = ? AND i.public_id = ? LIMIT 1
  `).get(Number(tenantId), cleanRequired(publicId, 'invoice_id', 120));
  if (!row) throw httpError(404, 'MONTHLY_INVOICE_NOT_FOUND', 'Invoice was not found.');
  return row;
}

function findPeriod(db, tenantId, publicId) {
  const row = db.prepare(`
    SELECT * FROM generator_reading_periods
    WHERE tenant_id = ? AND public_id = ? LIMIT 1
  `).get(Number(tenantId), cleanRequired(publicId, 'period_id', 120));
  if (!row) throw httpError(404, 'MONTHLY_PERIOD_NOT_FOUND', 'Reading month was not found.');
  return row;
}

function findPaymentByOperation(db, tenantId, operationUuid) {
  return db.prepare(`
    SELECT p.*, i.public_id AS invoice_public_id
    FROM generator_invoice_payments p
    JOIN generator_monthly_invoices i ON i.id = p.invoice_id
    WHERE p.tenant_id = ? AND p.operation_uuid = ? LIMIT 1
  `).get(Number(tenantId), operationUuid);
}

function serializePayment(row) {
  return {
    id: row.public_id,
    invoice_id: row.invoice_public_id || null,
    receipt_number: row.receipt_number,
    amount_iqd: Number(row.amount_iqd || 0),
    payment_method: row.payment_method,
    note: row.note || null,
    created_at: row.created_at
  };
}

function serializePaymentInvoice(row) {
  const paid = Number(row.paid_amount_iqd || 0);
  const remaining = Number(row.remaining_amount_iqd ?? Math.max(0, Number(row.amount_iqd) - paid));
  return {
    id: row.public_id,
    invoice_number: row.invoice_number,
    subscriber_id: row.subscriber_public_id || null,
    period_id: row.period_public_id || null,
    period_key: row.period_key,
    amount_iqd: Number(row.amount_iqd || 0),
    paid_amount_iqd: paid,
    remaining_amount_iqd: remaining,
    status: row.payment_status || paymentStatus(row.amount_iqd, paid),
    last_payment_at: row.last_payment_at || null
  };
}

function paymentStatus(amount, paid) {
  if (Number(paid || 0) <= 0) return 'unpaid';
  if (Number(paid) >= Number(amount)) return 'paid';
  return 'partial';
}

function positiveMoney(value, field) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number <= 0 || number > 1_000_000_000) {
    throw httpError(400, 'INVALID_PAYMENT_AMOUNT', `${field} must be a positive integer in IQD.`);
  }
  return number;
}

function normalizePaymentMethod(value) {
  const method = typeof value === 'string' ? value.trim() : '';
  if (!PAYMENT_METHODS.has(method)) {
    throw httpError(400, 'INVALID_PAYMENT_METHOD', 'payment_method must be cash or transfer.');
  }
  return method;
}

function cleanRequired(value, field, maxLength) {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!text) throw httpError(400, 'VALIDATION_ERROR', `${field} is required.`);
  if (text.length > maxLength) throw httpError(400, 'VALIDATION_ERROR', `${field} is too long.`);
  return text;
}

function cleanOptional(value, maxLength) {
  if (value == null) return null;
  const text = String(value).trim();
  if (!text) return null;
  if (text.length > maxLength) throw httpError(400, 'VALIDATION_ERROR', 'Value is too long.');
  return text;
}

function assertOwner(auth) {
  if (!auth || auth.role !== 'owner' || !auth.tenantId || !auth.accountId) {
    throw httpError(403, 'GENERATOR_PERMISSION_DENIED', 'Owner account is required.');
  }
}

module.exports = {
  enrichOwnerMonthlyPeriods,
  enrichOwnerMonthlyWorkspace,
  recordOwnerInvoicePayment,
  ensureInvoicePaymentColumns
};
