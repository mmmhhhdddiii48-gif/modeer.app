const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema, writeAuditLog } = require('./generators.db');

const BILLING_SCHEMA_FILE = path.join(__dirname, 'generators.billing.schema.sql');
const INVOICE_SCHEMA_FILE = path.join(__dirname, 'generators.invoices.schema.sql');
const initializedInvoiceDatabases = new WeakSet();

function invoiceDb() {
  const db = ensureGeneratorsSchema();
  if (!initializedInvoiceDatabases.has(db)) {
    db.exec(fs.readFileSync(BILLING_SCHEMA_FILE, 'utf8'));
    db.exec(fs.readFileSync(INVOICE_SCHEMA_FILE, 'utf8'));
    initializedInvoiceDatabases.add(db);
  }
  return db;
}

function approveOwnerBillingDraft(auth, draftPublicId, body = {}) {
  assertOwner(auth);
  if (body.confirm !== true) {
    throw httpError(400, 'INVOICE_APPROVAL_CONFIRMATION_REQUIRED', 'confirm=true is required to approve a billing draft.');
  }
  const db = invoiceDb();
  const draft = findDraftOrFail(db, auth.tenantId, draftPublicId);
  const existing = findInvoiceByDraft(db, auth.tenantId, draft.id);
  if (existing) return approvalResult(db, existing, true);
  if (draft.status !== 'reviewed') {
    throw httpError(409, 'INVOICE_DRAFT_NOT_REVIEWED', 'The billing draft must be reviewed before invoice approval.');
  }

  const invoicePublicId = crypto.randomUUID();
  const invoiceNumber = makeInvoiceNumber(draft.period_key, invoicePublicId);
  db.exec('BEGIN IMMEDIATE');
  try {
    const raceExisting = findInvoiceByDraft(db, auth.tenantId, draft.id);
    if (raceExisting) {
      db.exec('COMMIT');
      return approvalResult(db, raceExisting, true);
    }
    const previousBalance = subscriberBalance(db, auth.tenantId, draft.subscriber_id);
    const nextBalance = safeBalance(previousBalance, Number(draft.amount_iqd || 0));
    const invoiceResult = db.prepare(`
      INSERT INTO generator_invoices (
        public_id, tenant_id, invoice_number, period_id, subscriber_id,
        billing_draft_id, meter_reading_id, generator_unit_id, status,
        subscriber_name_snapshot, account_number_snapshot, meter_number_snapshot,
        generator_name_snapshot, contracted_amperes_snapshot,
        price_per_amp_iqd_snapshot, fixed_fee_iqd_snapshot,
        previous_value_snapshot, current_value_snapshot, consumption_snapshot,
        amount_iqd, calculation_method, approved_by_account_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'approved', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      invoicePublicId,
      auth.tenantId,
      invoiceNumber,
      draft.period_id,
      draft.subscriber_id,
      draft.id,
      draft.meter_reading_id,
      draft.generator_unit_id,
      draft.subscriber_name_snapshot,
      draft.account_number_snapshot,
      draft.meter_number_snapshot,
      draft.generator_name_snapshot,
      Number(draft.contracted_amperes_snapshot || 0),
      Number(draft.price_per_amp_iqd_snapshot || 0),
      Number(draft.fixed_fee_iqd_snapshot || 0),
      Number(draft.previous_value_snapshot || 0),
      Number(draft.current_value_snapshot || 0),
      Number(draft.consumption_snapshot || 0),
      Number(draft.amount_iqd || 0),
      draft.calculation_method,
      auth.accountId
    );
    const invoiceId = Number(invoiceResult.lastInsertRowid);
    db.prepare(`
      INSERT INTO generator_debt_ledger_entries (
        public_id, tenant_id, subscriber_id, invoice_id, entry_type,
        debit_iqd, credit_iqd, balance_after_iqd, note, created_by_account_id
      ) VALUES (?, ?, ?, ?, 'invoice_debit', ?, 0, ?, ?, ?)
    `).run(
      crypto.randomUUID(),
      auth.tenantId,
      draft.subscriber_id,
      invoiceId,
      Number(draft.amount_iqd || 0),
      nextBalance,
      `اعتماد فاتورة ${invoiceNumber}`,
      auth.accountId
    );
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    const duplicate = findInvoiceByDraft(db, auth.tenantId, draft.id);
    if (duplicate) return approvalResult(db, duplicate, true);
    throw error;
  }

  const created = findInvoiceByDraft(db, auth.tenantId, draft.id);
  const result = approvalResult(db, created, false);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.invoice.approved',
    entityType: 'generator_invoice',
    entityUuid: created.public_id,
    after: {
      invoice_number: created.invoice_number,
      amount_iqd: Number(created.amount_iqd || 0),
      subscriber_id: draft.subscriber_public_id,
      debt_opened: Number(created.amount_iqd || 0) > 0,
      collection_effect_applied: false,
      cash_effect_applied: false
    }
  });
  return result;
}

function listOwnerInvoices(auth, query = {}) {
  assertOwner(auth);
  const db = invoiceDb();
  const q = cleanOptional(query.q, 120);
  const periodId = query.period_id ? findPeriodOrFail(db, auth.tenantId, query.period_id).id : null;
  const rows = db.prepare(`
    SELECT i.*, p.public_id AS period_public_id, p.period_key,
      s.public_id AS subscriber_public_id, g.public_id AS generator_public_id,
      d.public_id AS billing_draft_public_id, mr.public_id AS reading_public_id,
      COALESCE((SELECT SUM(le.credit_iqd) FROM generator_debt_ledger_entries le
        WHERE le.tenant_id = i.tenant_id AND le.invoice_id = i.id), 0) AS paid_amount_iqd,
      COALESCE((SELECT SUM(le.debit_iqd - le.credit_iqd) FROM generator_debt_ledger_entries le
        WHERE le.tenant_id = i.tenant_id AND le.invoice_id = i.id), 0) AS remaining_amount_iqd
    FROM generator_invoices i
    JOIN generator_reading_periods p ON p.id = i.period_id
    JOIN generator_subscribers s ON s.id = i.subscriber_id
    JOIN generator_units g ON g.id = i.generator_unit_id
    JOIN generator_monthly_billing_drafts d ON d.id = i.billing_draft_id
    JOIN generator_meter_readings mr ON mr.id = i.meter_reading_id
    WHERE i.tenant_id = ?
      AND (? IS NULL OR i.period_id = ?)
      AND (? IS NULL OR i.invoice_number LIKE '%' || ? || '%'
        OR i.subscriber_name_snapshot LIKE '%' || ? || '%'
        OR i.account_number_snapshot LIKE '%' || ? || '%')
    ORDER BY i.approved_at DESC, i.id DESC
  `).all(auth.tenantId, periodId, periodId, q, q, q, q);
  return {
    server_time: new Date().toISOString(),
    invoices: rows.map(serializeInvoice),
    summary: summarizeInvoices(rows),
    collection_enabled: false,
    receipt_enabled: false,
    cash_effect_applied: false
  };
}

function listOwnerDebtLedger(auth, query = {}) {
  assertOwner(auth);
  const db = invoiceDb();
  const q = cleanOptional(query.q, 120);
  const subscriberId = query.subscriber_id
    ? findSubscriberOrFail(db, auth.tenantId, query.subscriber_id).id
    : null;
  const invoiceId = query.invoice_id
    ? findInvoiceOrFail(db, auth.tenantId, query.invoice_id).id
    : null;
  const rows = db.prepare(`
    SELECT le.*, s.public_id AS subscriber_public_id, s.full_name AS subscriber_name,
      s.account_number, i.public_id AS invoice_public_id, i.invoice_number,
      p.public_id AS period_public_id, p.period_key
    FROM generator_debt_ledger_entries le
    JOIN generator_subscribers s ON s.id = le.subscriber_id
    LEFT JOIN generator_invoices i ON i.id = le.invoice_id
    LEFT JOIN generator_reading_periods p ON p.id = i.period_id
    WHERE le.tenant_id = ?
      AND (? IS NULL OR le.subscriber_id = ?)
      AND (? IS NULL OR le.invoice_id = ?)
      AND (? IS NULL OR s.full_name LIKE '%' || ? || '%'
        OR s.account_number LIKE '%' || ? || '%'
        OR COALESCE(i.invoice_number, '') LIKE '%' || ? || '%')
    ORDER BY le.created_at DESC, le.id DESC
  `).all(auth.tenantId, subscriberId, subscriberId, invoiceId, invoiceId, q, q, q, q);
  const totals = db.prepare(`
    SELECT COALESCE(SUM(debit_iqd), 0) AS total_debit_iqd,
      COALESCE(SUM(credit_iqd), 0) AS total_credit_iqd
    FROM generator_debt_ledger_entries WHERE tenant_id = ?
  `).get(auth.tenantId);
  return {
    server_time: new Date().toISOString(),
    entries: rows.map(serializeDebtEntry),
    summary: {
      entry_count: rows.length,
      total_debit_iqd: Number(totals.total_debit_iqd || 0),
      total_credit_iqd: Number(totals.total_credit_iqd || 0),
      total_receivables_iqd: Math.max(0, Number(totals.total_debit_iqd || 0) - Number(totals.total_credit_iqd || 0))
    },
    collection_enabled: false,
    receipt_enabled: false
  };
}

function findInvoiceByDraft(db, tenantId, draftId) {
  return db.prepare(`
    SELECT i.*, p.public_id AS period_public_id, p.period_key,
      s.public_id AS subscriber_public_id, g.public_id AS generator_public_id,
      d.public_id AS billing_draft_public_id, mr.public_id AS reading_public_id,
      COALESCE((SELECT SUM(le.credit_iqd) FROM generator_debt_ledger_entries le
        WHERE le.tenant_id = i.tenant_id AND le.invoice_id = i.id), 0) AS paid_amount_iqd,
      COALESCE((SELECT SUM(le.debit_iqd - le.credit_iqd) FROM generator_debt_ledger_entries le
        WHERE le.tenant_id = i.tenant_id AND le.invoice_id = i.id), 0) AS remaining_amount_iqd
    FROM generator_invoices i
    JOIN generator_reading_periods p ON p.id = i.period_id
    JOIN generator_subscribers s ON s.id = i.subscriber_id
    JOIN generator_units g ON g.id = i.generator_unit_id
    JOIN generator_monthly_billing_drafts d ON d.id = i.billing_draft_id
    JOIN generator_meter_readings mr ON mr.id = i.meter_reading_id
    WHERE i.tenant_id = ? AND i.billing_draft_id = ? LIMIT 1
  `).get(Number(tenantId), Number(draftId)) || null;
}

function findInvoiceOrFail(db, tenantId, publicId) {
  const normalized = cleanRequired(publicId, 'invoice_id', 120);
  const row = db.prepare('SELECT * FROM generator_invoices WHERE tenant_id = ? AND public_id = ? LIMIT 1')
    .get(Number(tenantId), normalized);
  if (!row) throw httpError(404, 'INVOICE_NOT_FOUND', 'Invoice was not found in this organization.');
  return row;
}

function findDraftOrFail(db, tenantId, publicId) {
  const normalized = cleanRequired(publicId, 'draft_id', 120);
  const row = db.prepare(`
    SELECT d.*, p.public_id AS period_public_id, p.period_key,
      s.public_id AS subscriber_public_id, g.public_id AS generator_public_id,
      mr.public_id AS reading_public_id
    FROM generator_monthly_billing_drafts d
    JOIN generator_reading_periods p ON p.id = d.period_id
    JOIN generator_subscribers s ON s.id = d.subscriber_id
    JOIN generator_units g ON g.id = d.generator_unit_id
    JOIN generator_meter_readings mr ON mr.id = d.meter_reading_id
    WHERE d.tenant_id = ? AND d.public_id = ? LIMIT 1
  `).get(Number(tenantId), normalized);
  if (!row) throw httpError(404, 'BILLING_DRAFT_NOT_FOUND', 'Billing draft was not found in this organization.');
  return row;
}

function findPeriodOrFail(db, tenantId, publicId) {
  const normalized = cleanRequired(publicId, 'period_id', 120);
  const row = db.prepare('SELECT * FROM generator_reading_periods WHERE tenant_id = ? AND public_id = ? LIMIT 1')
    .get(Number(tenantId), normalized);
  if (!row) throw httpError(404, 'INVOICE_PERIOD_NOT_FOUND', 'Invoice period was not found in this organization.');
  return row;
}

function findSubscriberOrFail(db, tenantId, publicId) {
  const normalized = cleanRequired(publicId, 'subscriber_id', 120);
  const row = db.prepare('SELECT * FROM generator_subscribers WHERE tenant_id = ? AND public_id = ? LIMIT 1')
    .get(Number(tenantId), normalized);
  if (!row) throw httpError(404, 'DEBT_SUBSCRIBER_NOT_FOUND', 'Subscriber was not found in this organization.');
  return row;
}

function approvalResult(db, invoiceRow, duplicate) {
  const ledger = db.prepare(`
    SELECT le.*, s.public_id AS subscriber_public_id, s.full_name AS subscriber_name,
      s.account_number, i.public_id AS invoice_public_id, i.invoice_number,
      p.public_id AS period_public_id, p.period_key
    FROM generator_debt_ledger_entries le
    JOIN generator_subscribers s ON s.id = le.subscriber_id
    LEFT JOIN generator_invoices i ON i.id = le.invoice_id
    LEFT JOIN generator_reading_periods p ON p.id = i.period_id
    WHERE le.tenant_id = ? AND le.invoice_id = ? AND le.entry_type = 'invoice_debit' LIMIT 1
  `).get(invoiceRow.tenant_id, invoiceRow.id);
  return {
    duplicate,
    invoice: serializeInvoice(invoiceRow),
    debt_entry: serializeDebtEntry(ledger),
    debt_opened: Number(invoiceRow.remaining_amount_iqd || invoiceRow.amount_iqd || 0) > 0,
    collection_enabled: false,
    receipt_enabled: false,
    cash_effect_applied: false
  };
}

function subscriberBalance(db, tenantId, subscriberId) {
  const row = db.prepare(`
    SELECT COALESCE(SUM(debit_iqd - credit_iqd), 0) AS balance
    FROM generator_debt_ledger_entries WHERE tenant_id = ? AND subscriber_id = ?
  `).get(Number(tenantId), Number(subscriberId));
  return Number(row.balance || 0);
}

function serializeInvoice(row) {
  const paid = Number(row.paid_amount_iqd || 0);
  const remaining = Number(row.remaining_amount_iqd == null ? row.amount_iqd : row.remaining_amount_iqd);
  return {
    id: row.public_id,
    invoice_number: row.invoice_number,
    period_id: row.period_public_id || null,
    period_key: row.period_key || null,
    subscriber_id: row.subscriber_public_id || null,
    billing_draft_id: row.billing_draft_public_id || null,
    meter_reading_id: row.reading_public_id || null,
    generator_id: row.generator_public_id || null,
    status: row.status,
    subscriber_name: row.subscriber_name_snapshot,
    account_number: row.account_number_snapshot,
    meter_number: row.meter_number_snapshot,
    generator_name: row.generator_name_snapshot,
    contracted_amperes: Number(row.contracted_amperes_snapshot || 0),
    price_per_amp_iqd: Number(row.price_per_amp_iqd_snapshot || 0),
    fixed_fee_iqd: Number(row.fixed_fee_iqd_snapshot || 0),
    previous_value: Number(row.previous_value_snapshot || 0),
    current_value: Number(row.current_value_snapshot || 0),
    consumption: Number(row.consumption_snapshot || 0),
    amount_iqd: Number(row.amount_iqd || 0),
    paid_amount_iqd: paid,
    remaining_amount_iqd: remaining,
    debt_status: remaining > 0 ? (paid > 0 ? 'partially_paid' : 'open') : 'settled',
    calculation_method: row.calculation_method,
    approved_at: row.approved_at,
    created_at: row.created_at,
    collection_enabled: false
  };
}

function serializeDebtEntry(row) {
  if (!row) return null;
  return {
    id: row.public_id,
    subscriber_id: row.subscriber_public_id || null,
    subscriber_name: row.subscriber_name || null,
    account_number: row.account_number || null,
    invoice_id: row.invoice_public_id || null,
    invoice_number: row.invoice_number || null,
    period_id: row.period_public_id || null,
    period_key: row.period_key || null,
    entry_type: row.entry_type,
    debit_iqd: Number(row.debit_iqd || 0),
    credit_iqd: Number(row.credit_iqd || 0),
    balance_after_iqd: Number(row.balance_after_iqd || 0),
    note: row.note || null,
    created_at: row.created_at
  };
}

function summarizeInvoices(rows) {
  let total = 0;
  let paid = 0;
  let remaining = 0;
  let openCount = 0;
  for (const row of rows) {
    total += Number(row.amount_iqd || 0);
    paid += Number(row.paid_amount_iqd || 0);
    const rowRemaining = Number(row.remaining_amount_iqd || 0);
    remaining += rowRemaining;
    if (rowRemaining > 0) openCount += 1;
  }
  return {
    invoice_count: rows.length,
    open_debt_count: openCount,
    total_amount_iqd: total,
    paid_amount_iqd: paid,
    remaining_amount_iqd: remaining
  };
}

function makeInvoiceNumber(periodKey, publicId) {
  const period = String(periodKey || '').replace(/[^0-9]/g, '') || '000000';
  return `INV-${period}-${String(publicId).slice(0, 8).toUpperCase()}`;
}
function safeBalance(previous, debit) {
  const balance = Number(previous) + Number(debit);
  if (!Number.isSafeInteger(balance) || balance < 0) {
    throw httpError(409, 'DEBT_BALANCE_OVERFLOW', 'Subscriber debt balance is outside the supported integer range.');
  }
  return balance;
}
function cleanRequired(value, field, maxLength) {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) throw httpError(400, 'VALIDATION_ERROR', `${field} is required.`);
  if (normalized.length > maxLength) throw httpError(400, 'VALIDATION_ERROR', `${field} is too long.`);
  return normalized;
}
function cleanOptional(value, maxLength) {
  if (value == null) return null;
  const normalized = String(value).trim();
  if (!normalized) return null;
  if (normalized.length > maxLength) throw httpError(400, 'VALIDATION_ERROR', 'Value is too long.');
  return normalized;
}
function assertOwner(auth) {
  if (!auth || auth.role !== 'owner' || !auth.tenantId || !auth.accountId) {
    throw httpError(403, 'GENERATOR_PERMISSION_DENIED', 'Owner account is required.');
  }
}

module.exports = {
  approveOwnerBillingDraft,
  listOwnerInvoices,
  listOwnerDebtLedger,
  serializeInvoice,
  serializeDebtEntry
};
