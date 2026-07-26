const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema, writeAuditLog } = require('./generators.db');
const {
  enrichOwnerMonthlyWorkspace,
  ensureInvoicePaymentColumns
} = require('./generators.simple_payments.service');

const BILLING_SCHEMA_FILE = path.join(__dirname, 'generators.simple_billing.schema.sql');
const PAYMENTS_SCHEMA_FILE = path.join(__dirname, 'generators.simple_payments.schema.sql');
const initializedDatabases = new WeakSet();
const PAYMENT_METHODS = new Set(['cash', 'transfer']);
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function collectorPaymentsDb() {
  const db = ensureGeneratorsSchema();
  if (!initializedDatabases.has(db)) {
    db.exec(fs.readFileSync(BILLING_SCHEMA_FILE, 'utf8'));
    ensureInvoicePaymentColumns(db);
    db.exec(fs.readFileSync(PAYMENTS_SCHEMA_FILE, 'utf8'));
    initializedDatabases.add(db);
  }
  return db;
}

function enrichOwnerMonthlyWorkspaceWithReceivers(auth, workspace, periodPublicId) {
  const enriched = enrichOwnerMonthlyWorkspace(auth, workspace, periodPublicId);
  const db = collectorPaymentsDb();
  const rows = db.prepare(`
    SELECT p.public_id, a.public_id AS receiver_public_id,
      a.full_name AS receiver_name, a.role AS receiver_role
    FROM generator_invoice_payments p
    JOIN generator_monthly_invoices i ON i.id = p.invoice_id
    JOIN generator_reading_periods rp ON rp.id = i.period_id
    JOIN generator_accounts a ON a.id = p.received_by_account_id
    WHERE p.tenant_id = ? AND rp.public_id = ?
  `).all(auth.tenantId, cleanRequired(periodPublicId, 'period_id', 120));
  const receiverByPayment = new Map(rows.map((row) => [row.public_id, {
    id: row.receiver_public_id,
    name: row.receiver_name,
    role: row.receiver_role
  }]));
  return {
    ...enriched,
    invoices: (enriched.invoices || []).map((invoice) => ({
      ...invoice,
      payments: (invoice.payments || []).map((payment) => ({
        ...payment,
        received_by: receiverByPayment.get(payment.id) || null
      }))
    }))
  };
}

function listCollectorAssignedInvoices(auth, query = {}) {
  assertCollector(auth);
  const db = collectorPaymentsDb();
  const q = cleanOptional(query.q, 120);
  const rows = db.prepare(`
    SELECT i.*, p.period_key, p.public_id AS period_public_id,
      s.public_id AS subscriber_public_id, s.full_name AS subscriber_name,
      s.account_number, s.phone, s.area, s.meter_number,
      r.public_id AS route_public_id, r.name AS route_name,
      g.public_id AS generator_public_id, g.name AS generator_name
    FROM generator_monthly_invoices i
    JOIN generator_reading_periods p ON p.id = i.period_id
    JOIN generator_subscribers s ON s.id = i.subscriber_id
    LEFT JOIN generator_routes r ON r.id = s.route_id
    JOIN generator_units g ON g.id = i.generator_unit_id
    WHERE i.tenant_id = ?
      AND EXISTS (
        SELECT 1
        FROM generator_collector_assignments a
        WHERE a.tenant_id = i.tenant_id
          AND a.collector_account_id = ?
          AND a.status = 'active'
          AND (
            (a.assignment_type = 'subscriber' AND a.target_public_id = s.public_id)
            OR (a.assignment_type = 'route' AND r.public_id IS NOT NULL AND a.target_public_id = r.public_id)
            OR (a.assignment_type = 'generator' AND a.target_public_id = g.public_id)
          )
      )
      AND (
        ? IS NULL
        OR i.invoice_number LIKE '%' || ? || '%'
        OR s.full_name LIKE '%' || ? || '%'
        OR s.account_number LIKE '%' || ? || '%'
        OR COALESCE(s.meter_number, '') LIKE '%' || ? || '%'
        OR COALESCE(s.phone, '') LIKE '%' || ? || '%'
      )
    ORDER BY
      CASE COALESCE(i.payment_status, 'unpaid')
        WHEN 'partial' THEN 0
        WHEN 'unpaid' THEN 1
        ELSE 2
      END,
      p.period_key DESC,
      s.full_name COLLATE NOCASE,
      i.id DESC
  `).all(auth.tenantId, auth.accountId, q, q, q, q, q, q);

  const invoiceIds = rows.map((row) => Number(row.id));
  const paymentsByInvoice = new Map();
  if (invoiceIds.length) {
    const placeholders = invoiceIds.map(() => '?').join(',');
    const paymentRows = db.prepare(`
      SELECT p.*, i.public_id AS invoice_public_id,
        a.public_id AS receiver_public_id, a.full_name AS receiver_name, a.role AS receiver_role
      FROM generator_invoice_payments p
      JOIN generator_monthly_invoices i ON i.id = p.invoice_id
      JOIN generator_accounts a ON a.id = p.received_by_account_id
      WHERE p.tenant_id = ? AND p.invoice_id IN (${placeholders})
      ORDER BY p.created_at DESC, p.id DESC
    `).all(auth.tenantId, ...invoiceIds);
    for (const row of paymentRows) {
      const list = paymentsByInvoice.get(row.invoice_public_id) || [];
      list.push(serializePayment(row));
      paymentsByInvoice.set(row.invoice_public_id, list);
    }
  }

  const invoices = rows.map((row) => serializeCollectorInvoice(
    row,
    paymentsByInvoice.get(row.public_id) || []
  ));
  return {
    server_time: new Date().toISOString(),
    online_required: true,
    invoices,
    summary: paymentSummary(invoices),
    assignment_enforced: true,
    separate_cash_box_enabled: false,
    offline_collection_enabled: false
  };
}

function recordCollectorInvoicePayment(auth, invoicePublicId, body) {
  assertCollector(auth);
  if (body?.confirm !== true) {
    throw httpError(400, 'PAYMENT_CONFIRM_REQUIRED', 'Confirm the payment before saving.');
  }
  const cleanInvoiceId = cleanRequired(invoicePublicId, 'invoice_id', 120);
  const operationUuid = cleanRequired(body?.operation_uuid, 'operation_uuid', 80);
  if (!UUID_PATTERN.test(operationUuid)) {
    throw httpError(400, 'INVALID_PAYMENT_OPERATION_UUID', 'operation_uuid must be a valid UUID.');
  }
  const amount = positiveMoney(body?.amount_iqd, 'amount_iqd');
  const paymentMethod = normalizePaymentMethod(body?.payment_method);
  const note = cleanOptional(body?.note, 250);
  const db = collectorPaymentsDb();

  let invoice = findInvoice(db, auth.tenantId, cleanInvoiceId);
  assertCollectorAssignedToInvoice(db, auth, invoice);

  const duplicate = findPaymentByOperation(db, auth.tenantId, operationUuid);
  if (duplicate) {
    if (duplicate.invoice_public_id !== cleanInvoiceId) {
      throw httpError(409, 'PAYMENT_OPERATION_CONFLICT', 'This payment operation UUID was already used for another invoice.');
    }
    return {
      duplicate: true,
      payment: serializePayment(duplicate),
      invoice: serializePaymentInvoice(invoice),
      cash_box_effect_applied: false,
      collected_by: 'collector'
    };
  }

  let paid = Number(invoice.paid_amount_iqd || 0);
  let remaining = Number(invoice.remaining_amount_iqd ?? Math.max(0, Number(invoice.amount_iqd) - paid));
  validatePaymentAgainstInvoice(amount, remaining);

  let paymentPublicId;
  db.exec('BEGIN IMMEDIATE');
  try {
    const existing = findPaymentByOperation(db, auth.tenantId, operationUuid);
    if (existing) {
      if (existing.invoice_public_id !== cleanInvoiceId) {
        throw httpError(409, 'PAYMENT_OPERATION_CONFLICT', 'This payment operation UUID was already used for another invoice.');
      }
      db.exec('COMMIT');
      return {
        duplicate: true,
        payment: serializePayment(existing),
        invoice: serializePaymentInvoice(findInvoice(db, auth.tenantId, cleanInvoiceId)),
        cash_box_effect_applied: false,
        collected_by: 'collector'
      };
    }

    invoice = findInvoice(db, auth.tenantId, cleanInvoiceId);
    assertCollectorAssignedToInvoice(db, auth, invoice);
    paid = Number(invoice.paid_amount_iqd || 0);
    remaining = Number(invoice.remaining_amount_iqd ?? Math.max(0, Number(invoice.amount_iqd) - paid));
    validatePaymentAgainstInvoice(amount, remaining);

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

  const payment = findPaymentByPublicId(db, auth.tenantId, paymentPublicId);
  const updatedInvoice = findInvoice(db, auth.tenantId, cleanInvoiceId);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.collector.payment_recorded',
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
      payment_status: updatedInvoice.payment_status,
      received_by_role: 'collector'
    }
  });
  return {
    duplicate: false,
    payment: serializePayment(payment),
    invoice: serializePaymentInvoice(updatedInvoice),
    cash_box_effect_applied: false,
    collected_by: 'collector'
  };
}

function validatePaymentAgainstInvoice(amount, remaining) {
  if (remaining <= 0) {
    throw httpError(409, 'INVOICE_ALREADY_PAID', 'This invoice is already fully paid.');
  }
  if (amount > remaining) {
    throw httpError(409, 'PAYMENT_EXCEEDS_REMAINING', 'Payment amount is greater than the remaining invoice amount.', {
      remaining_amount_iqd: remaining
    });
  }
}

function findInvoice(db, tenantId, publicId) {
  const row = db.prepare(`
    SELECT i.*, p.period_key, p.public_id AS period_public_id,
      s.public_id AS subscriber_public_id, s.full_name AS subscriber_name,
      s.account_number, s.phone, s.area, s.meter_number,
      r.public_id AS route_public_id, r.name AS route_name,
      g.public_id AS generator_public_id, g.name AS generator_name
    FROM generator_monthly_invoices i
    JOIN generator_reading_periods p ON p.id = i.period_id
    JOIN generator_subscribers s ON s.id = i.subscriber_id
    LEFT JOIN generator_routes r ON r.id = s.route_id
    JOIN generator_units g ON g.id = i.generator_unit_id
    WHERE i.tenant_id = ? AND i.public_id = ? LIMIT 1
  `).get(Number(tenantId), cleanRequired(publicId, 'invoice_id', 120));
  if (!row) throw httpError(404, 'MONTHLY_INVOICE_NOT_FOUND', 'Invoice was not found.');
  return row;
}

function findPaymentByOperation(db, tenantId, operationUuid) {
  return db.prepare(`
    SELECT p.*, i.public_id AS invoice_public_id,
      a.public_id AS receiver_public_id, a.full_name AS receiver_name, a.role AS receiver_role
    FROM generator_invoice_payments p
    JOIN generator_monthly_invoices i ON i.id = p.invoice_id
    JOIN generator_accounts a ON a.id = p.received_by_account_id
    WHERE p.tenant_id = ? AND p.operation_uuid = ? LIMIT 1
  `).get(Number(tenantId), operationUuid);
}

function findPaymentByPublicId(db, tenantId, paymentPublicId) {
  return db.prepare(`
    SELECT p.*, i.public_id AS invoice_public_id,
      a.public_id AS receiver_public_id, a.full_name AS receiver_name, a.role AS receiver_role
    FROM generator_invoice_payments p
    JOIN generator_monthly_invoices i ON i.id = p.invoice_id
    JOIN generator_accounts a ON a.id = p.received_by_account_id
    WHERE p.tenant_id = ? AND p.public_id = ? LIMIT 1
  `).get(Number(tenantId), paymentPublicId);
}

function assertCollectorAssignedToInvoice(db, auth, invoice) {
  const assigned = db.prepare(`
    SELECT 1 AS ok
    FROM generator_collector_assignments a
    WHERE a.tenant_id = ?
      AND a.collector_account_id = ?
      AND a.status = 'active'
      AND (
        (a.assignment_type = 'subscriber' AND a.target_public_id = ?)
        OR (a.assignment_type = 'route' AND ? IS NOT NULL AND a.target_public_id = ?)
        OR (a.assignment_type = 'generator' AND a.target_public_id = ?)
      )
    LIMIT 1
  `).get(
    auth.tenantId,
    auth.accountId,
    invoice.subscriber_public_id,
    invoice.route_public_id,
    invoice.route_public_id,
    invoice.generator_public_id
  );
  if (!assigned) {
    throw httpError(403, 'COLLECTOR_INVOICE_NOT_ASSIGNED', 'This invoice is not assigned to the collector.');
  }
}

function serializePayment(row) {
  return {
    id: row.public_id,
    invoice_id: row.invoice_public_id || null,
    receipt_number: row.receipt_number,
    amount_iqd: Number(row.amount_iqd || 0),
    payment_method: row.payment_method,
    note: row.note || null,
    received_by: row.receiver_public_id ? {
      id: row.receiver_public_id,
      name: row.receiver_name,
      role: row.receiver_role
    } : null,
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
    subscriber_name: row.subscriber_name,
    account_number: row.account_number,
    period_id: row.period_public_id || null,
    period_key: row.period_key,
    amount_iqd: Number(row.amount_iqd || 0),
    paid_amount_iqd: paid,
    remaining_amount_iqd: remaining,
    status: row.payment_status || paymentStatus(row.amount_iqd, paid),
    last_payment_at: row.last_payment_at || null
  };
}

function serializeCollectorInvoice(row, payments) {
  const paid = Number(row.paid_amount_iqd || 0);
  const remaining = Number(row.remaining_amount_iqd ?? Math.max(0, Number(row.amount_iqd) - paid));
  return {
    id: row.public_id,
    invoice_number: row.invoice_number,
    period_id: row.period_public_id,
    period_key: row.period_key,
    subscriber_id: row.subscriber_public_id,
    subscriber_name: row.subscriber_name,
    account_number: row.account_number,
    phone: row.phone || null,
    area: row.area || null,
    meter_number: row.meter_number || null,
    route_name: row.route_name || null,
    generator_id: row.generator_public_id,
    generator_name: row.generator_name,
    contracted_amperes: Number(row.contracted_amperes_snapshot || 0),
    price_per_amp_iqd: Number(row.price_per_amp_iqd_snapshot || 0),
    fixed_fee_iqd: Number(row.fixed_fee_iqd_snapshot || 0),
    consumption: Number(row.consumption_snapshot || 0),
    amount_iqd: Number(row.amount_iqd || 0),
    paid_amount_iqd: paid,
    remaining_amount_iqd: remaining,
    debt_iqd: remaining,
    status: row.payment_status || paymentStatus(row.amount_iqd, paid),
    last_payment_at: row.last_payment_at || null,
    payments
  };
}

function paymentSummary(invoices) {
  const totalIqd = invoices.reduce((sum, invoice) => sum + Number(invoice.amount_iqd || 0), 0);
  const paidIqd = invoices.reduce((sum, invoice) => sum + Number(invoice.paid_amount_iqd || 0), 0);
  const remainingIqd = invoices.reduce((sum, invoice) => sum + Number(invoice.remaining_amount_iqd || 0), 0);
  return {
    invoice_count: invoices.length,
    total_iqd: totalIqd,
    paid_iqd: paidIqd,
    remaining_iqd: remainingIqd,
    unpaid_iqd: remainingIqd,
    unpaid_count: invoices.filter((invoice) => invoice.status === 'unpaid').length,
    partial_count: invoices.filter((invoice) => invoice.status === 'partial').length,
    paid_count: invoices.filter((invoice) => invoice.status === 'paid').length
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

function assertCollector(auth) {
  if (!auth || auth.role !== 'collector' || !auth.tenantId || !auth.accountId) {
    throw httpError(403, 'GENERATOR_PERMISSION_DENIED', 'Collector account is required.');
  }
}

module.exports = {
  enrichOwnerMonthlyWorkspaceWithReceivers,
  listCollectorAssignedInvoices,
  recordCollectorInvoicePayment
};
