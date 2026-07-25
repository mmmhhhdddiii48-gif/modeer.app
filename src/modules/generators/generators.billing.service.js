const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema, writeAuditLog } = require('./generators.db');

const DRAFT_STATUSES = new Set(['draft', 'reviewed']);
const BILLING_SCHEMA_FILE = path.join(__dirname, 'generators.billing.schema.sql');
const initializedBillingDatabases = new WeakSet();

function billingDb() {
  const db = ensureGeneratorsSchema();
  if (!initializedBillingDatabases.has(db)) {
    db.exec(fs.readFileSync(BILLING_SCHEMA_FILE, 'utf8'));
    initializedBillingDatabases.add(db);
  }
  return db;
}

function listOwnerBillingPeriods(auth) {
  assertOwner(auth);
  const db = billingDb();
  const rows = db.prepare(`
    SELECT p.*,
      (SELECT COUNT(*) FROM generator_meter_readings mr WHERE mr.tenant_id = p.tenant_id AND mr.period_id = p.id) AS reading_count,
      (SELECT COUNT(*) FROM generator_billing_tariffs t WHERE t.tenant_id = p.tenant_id AND t.period_id = p.id) AS tariff_count,
      (SELECT COUNT(*) FROM generator_monthly_billing_drafts d WHERE d.tenant_id = p.tenant_id AND d.period_id = p.id) AS draft_count,
      (SELECT COUNT(*) FROM generator_monthly_billing_drafts d WHERE d.tenant_id = p.tenant_id AND d.period_id = p.id AND d.status = 'reviewed') AS reviewed_count,
      (SELECT COALESCE(SUM(d.amount_iqd), 0) FROM generator_monthly_billing_drafts d WHERE d.tenant_id = p.tenant_id AND d.period_id = p.id) AS total_amount_iqd
    FROM generator_reading_periods p
    WHERE p.tenant_id = ?
    ORDER BY p.period_key DESC
  `).all(auth.tenantId);
  return {
    server_time: new Date().toISOString(),
    periods: rows.map(serializeBillingPeriod),
    collection_enabled: false,
    debt_enabled: false
  };
}

function getOwnerBillingWorkspace(auth, periodPublicId, query = {}) {
  assertOwner(auth);
  const db = billingDb();
  const period = findPeriodOrFail(db, auth.tenantId, periodPublicId);
  const q = cleanOptional(query.q, 120);
  const status = query.status == null || query.status === '' ? null : normalizeDraftStatus(query.status);

  const generatorRows = db.prepare(`
    SELECT g.public_id AS generator_id, g.code AS generator_code, g.name AS generator_name,
      COUNT(mr.id) AS reading_count,
      t.public_id AS tariff_id, t.price_per_amp_iqd, t.fixed_fee_iqd,
      t.calculation_method, t.created_at AS tariff_created_at, t.updated_at AS tariff_updated_at,
      EXISTS (
        SELECT 1 FROM generator_monthly_billing_drafts d
        WHERE d.tenant_id = ? AND d.period_id = ? AND d.generator_unit_id = g.id
      ) AS tariff_locked
    FROM generator_meter_readings mr
    JOIN generator_subscribers s ON s.id = mr.subscriber_id
    JOIN generator_units g ON g.id = s.generator_unit_id
    LEFT JOIN generator_billing_tariffs t
      ON t.tenant_id = mr.tenant_id AND t.period_id = mr.period_id AND t.generator_unit_id = g.id
    WHERE mr.tenant_id = ? AND mr.period_id = ?
    GROUP BY g.id, t.id
    ORDER BY g.name COLLATE NOCASE
  `).all(auth.tenantId, period.id, auth.tenantId, period.id);

  const drafts = db.prepare(`
    SELECT d.*, p.public_id AS period_public_id, p.period_key,
      s.public_id AS subscriber_public_id, g.public_id AS generator_public_id,
      mr.public_id AS reading_public_id
    FROM generator_monthly_billing_drafts d
    JOIN generator_reading_periods p ON p.id = d.period_id
    JOIN generator_subscribers s ON s.id = d.subscriber_id
    JOIN generator_units g ON g.id = d.generator_unit_id
    JOIN generator_meter_readings mr ON mr.id = d.meter_reading_id
    WHERE d.tenant_id = ? AND d.period_id = ?
      AND (? IS NULL OR d.status = ?)
      AND (? IS NULL OR d.subscriber_name_snapshot LIKE '%' || ? || '%'
        OR d.account_number_snapshot LIKE '%' || ? || '%'
        OR COALESCE(d.meter_number_snapshot, '') LIKE '%' || ? || '%')
    ORDER BY d.subscriber_name_snapshot COLLATE NOCASE, d.id
  `).all(auth.tenantId, period.id, status, status, q, q, q, q);

  const coverage = db.prepare(`
    SELECT
      (SELECT COUNT(*) FROM generator_meter_readings mr WHERE mr.tenant_id = ? AND mr.period_id = ?) AS reading_count,
      (SELECT COUNT(DISTINCT s.generator_unit_id)
       FROM generator_meter_readings mr JOIN generator_subscribers s ON s.id = mr.subscriber_id
       WHERE mr.tenant_id = ? AND mr.period_id = ?) AS required_tariff_count,
      (SELECT COUNT(*) FROM generator_billing_tariffs t WHERE t.tenant_id = ? AND t.period_id = ?) AS tariff_count,
      (SELECT COUNT(*) FROM generator_monthly_billing_drafts d WHERE d.tenant_id = ? AND d.period_id = ?) AS draft_count,
      (SELECT COUNT(*) FROM generator_monthly_billing_drafts d WHERE d.tenant_id = ? AND d.period_id = ? AND d.status = 'reviewed') AS reviewed_count,
      (SELECT COALESCE(SUM(d.amount_iqd), 0) FROM generator_monthly_billing_drafts d WHERE d.tenant_id = ? AND d.period_id = ?) AS total_amount_iqd
  `).get(
    auth.tenantId, period.id,
    auth.tenantId, period.id,
    auth.tenantId, period.id,
    auth.tenantId, period.id,
    auth.tenantId, period.id,
    auth.tenantId, period.id
  );

  const readingCount = Number(coverage.reading_count || 0);
  const requiredTariffCount = Number(coverage.required_tariff_count || 0);
  const tariffCount = Number(coverage.tariff_count || 0);
  const draftCount = Number(coverage.draft_count || 0);
  const reviewedCount = Number(coverage.reviewed_count || 0);

  return {
    server_time: new Date().toISOString(),
    period: serializeBillingPeriod({
      ...period,
      reading_count: readingCount,
      tariff_count: tariffCount,
      draft_count: draftCount,
      reviewed_count: reviewedCount,
      total_amount_iqd: Number(coverage.total_amount_iqd || 0)
    }),
    generators: generatorRows.map(serializeTariffGenerator),
    drafts: drafts.map(serializeBillingDraft),
    summary: {
      reading_count: readingCount,
      required_tariff_count: requiredTariffCount,
      tariff_count: tariffCount,
      missing_tariff_count: Math.max(0, requiredTariffCount - tariffCount),
      draft_count: draftCount,
      reviewed_count: reviewedCount,
      pending_review_count: Math.max(0, draftCount - reviewedCount),
      total_amount_iqd: Number(coverage.total_amount_iqd || 0),
      can_generate: period.status === 'locked' && readingCount > 0 && tariffCount >= requiredTariffCount
    },
    calculation_method: 'contracted_amperes',
    collection_enabled: false,
    debt_enabled: false
  };
}

function upsertOwnerBillingTariff(auth, periodPublicId, generatorPublicId, body) {
  assertOwner(auth);
  const pricePerAmp = normalizeMoney(body?.price_per_amp_iqd, 'price_per_amp_iqd');
  const fixedFee = normalizeMoney(body?.fixed_fee_iqd ?? 0, 'fixed_fee_iqd');
  const db = billingDb();
  const period = findPeriodOrFail(db, auth.tenantId, periodPublicId);
  if (period.status !== 'locked') {
    throw httpError(409, 'BILLING_PERIOD_NOT_LOCKED', 'Lock the meter-reading period before configuring monthly billing.');
  }
  const generator = findGeneratorOrFail(db, auth.tenantId, generatorPublicId);
  const readingCount = db.prepare(`
    SELECT COUNT(*) AS count
    FROM generator_meter_readings mr
    JOIN generator_subscribers s ON s.id = mr.subscriber_id
    WHERE mr.tenant_id = ? AND mr.period_id = ? AND s.generator_unit_id = ?
  `).get(auth.tenantId, period.id, generator.id);
  if (Number(readingCount.count || 0) === 0) {
    throw httpError(409, 'BILLING_GENERATOR_HAS_NO_READINGS', 'This generator has no confirmed readings in the selected period.');
  }
  const draftCount = db.prepare(`
    SELECT COUNT(*) AS count FROM generator_monthly_billing_drafts
    WHERE tenant_id = ? AND period_id = ? AND generator_unit_id = ?
  `).get(auth.tenantId, period.id, generator.id);
  if (Number(draftCount.count || 0) > 0) {
    throw httpError(409, 'BILLING_TARIFF_LOCKED_BY_DRAFTS', 'Tariff cannot be changed after billing drafts were generated for this generator.');
  }
  const current = db.prepare(`
    SELECT * FROM generator_billing_tariffs
    WHERE tenant_id = ? AND period_id = ? AND generator_unit_id = ? LIMIT 1
  `).get(auth.tenantId, period.id, generator.id);
  if (current) {
    db.prepare(`
      UPDATE generator_billing_tariffs
      SET price_per_amp_iqd = ?, fixed_fee_iqd = ?, configured_by_account_id = ?
      WHERE id = ? AND tenant_id = ?
    `).run(pricePerAmp, fixedFee, auth.accountId, current.id, auth.tenantId);
  } else {
    db.prepare(`
      INSERT INTO generator_billing_tariffs (
        public_id, tenant_id, period_id, generator_unit_id,
        price_per_amp_iqd, fixed_fee_iqd, calculation_method, configured_by_account_id
      ) VALUES (?, ?, ?, ?, ?, ?, 'contracted_amperes', ?)
    `).run(crypto.randomUUID(), auth.tenantId, period.id, generator.id, pricePerAmp, fixedFee, auth.accountId);
  }
  const updated = db.prepare(`
    SELECT * FROM generator_billing_tariffs
    WHERE tenant_id = ? AND period_id = ? AND generator_unit_id = ? LIMIT 1
  `).get(auth.tenantId, period.id, generator.id);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: current ? 'generator.billing.tariff_updated' : 'generator.billing.tariff_created',
    entityType: 'generator_billing_tariff',
    entityUuid: updated.public_id,
    before: current ? serializeTariff(current) : null,
    after: serializeTariff(updated)
  });
  return {
    period_id: period.public_id,
    generator: { id: generator.public_id, code: generator.code, name: generator.name },
    tariff: serializeTariff(updated),
    financial_effect_applied: false
  };
}

function generateOwnerBillingDrafts(auth, periodPublicId) {
  assertOwner(auth);
  const db = billingDb();
  const period = findPeriodOrFail(db, auth.tenantId, periodPublicId);
  if (period.status !== 'locked') {
    throw httpError(409, 'BILLING_PERIOD_NOT_LOCKED', 'Billing drafts can only be generated after the meter-reading period is locked.');
  }
  const rows = db.prepare(`
    SELECT mr.*, s.id AS subscriber_db_id, s.public_id AS subscriber_public_id,
      s.full_name, s.account_number, s.meter_number, s.contracted_amperes,
      g.id AS generator_db_id, g.public_id AS generator_public_id, g.name AS generator_name,
      t.id AS tariff_db_id, t.public_id AS tariff_public_id,
      t.price_per_amp_iqd, t.fixed_fee_iqd, t.calculation_method
    FROM generator_meter_readings mr
    JOIN generator_subscribers s ON s.id = mr.subscriber_id
    JOIN generator_units g ON g.id = s.generator_unit_id
    LEFT JOIN generator_billing_tariffs t
      ON t.tenant_id = mr.tenant_id AND t.period_id = mr.period_id AND t.generator_unit_id = g.id
    WHERE mr.tenant_id = ? AND mr.period_id = ?
    ORDER BY mr.id
  `).all(auth.tenantId, period.id);
  if (rows.length === 0) {
    throw httpError(409, 'BILLING_NO_CONFIRMED_READINGS', 'There are no confirmed meter readings in this period.');
  }
  const missing = rows
    .filter((row) => !row.tariff_db_id)
    .map((row) => ({ generator_id: row.generator_public_id, generator_name: row.generator_name }));
  const uniqueMissing = [...new Map(missing.map((item) => [item.generator_id, item])).values()];
  if (uniqueMissing.length) {
    throw httpError(409, 'BILLING_TARIFF_MISSING', 'Configure a tariff for every generator that has confirmed readings.', {
      missing_generators: uniqueMissing
    });
  }

  let createdCount = 0;
  db.exec('BEGIN IMMEDIATE');
  try {
    const insert = db.prepare(`
      INSERT OR IGNORE INTO generator_monthly_billing_drafts (
        public_id, tenant_id, period_id, subscriber_id, meter_reading_id, tariff_id,
        generator_unit_id, status, subscriber_name_snapshot, account_number_snapshot,
        meter_number_snapshot, generator_name_snapshot, contracted_amperes_snapshot,
        price_per_amp_iqd_snapshot, fixed_fee_iqd_snapshot, previous_value_snapshot,
        current_value_snapshot, consumption_snapshot, amount_iqd, calculation_method,
        generated_by_account_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'contracted_amperes', ?)
    `);
    for (const row of rows) {
      const amperes = Number(row.contracted_amperes || 0);
      const price = Number(row.price_per_amp_iqd || 0);
      const fee = Number(row.fixed_fee_iqd || 0);
      const amount = safeAmount(amperes, price, fee);
      const result = insert.run(
        crypto.randomUUID(), auth.tenantId, period.id, row.subscriber_db_id, row.id,
        row.tariff_db_id, row.generator_db_id, row.full_name, row.account_number,
        row.meter_number, row.generator_name, amperes, price, fee,
        Number(row.previous_value), Number(row.current_value), Number(row.consumption),
        amount, auth.accountId
      );
      createdCount += Number(result.changes || 0);
    }
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.billing.drafts_generated',
    entityType: 'generator_reading_period',
    entityUuid: period.public_id,
    after: { created_count: createdCount, total_reading_count: rows.length, financial_effect_applied: false }
  });
  return {
    created_count: createdCount,
    existing_count: rows.length - createdCount,
    workspace: getOwnerBillingWorkspace(auth, period.public_id),
    financial_effect_applied: false
  };
}

function updateOwnerBillingDraftStatus(auth, draftPublicId, body) {
  assertOwner(auth);
  const status = normalizeDraftStatus(body?.status);
  const db = billingDb();
  const current = findDraftOrFail(db, auth.tenantId, draftPublicId);
  if (current.status === status) return serializeBillingDraft(current);
  db.prepare(`
    UPDATE generator_monthly_billing_drafts
    SET status = ?, reviewed_by_account_id = ?, reviewed_at = ?
    WHERE id = ? AND tenant_id = ?
  `).run(
    status,
    status === 'reviewed' ? auth.accountId : null,
    status === 'reviewed' ? new Date().toISOString() : null,
    current.id,
    auth.tenantId
  );
  const updated = findDraftOrFail(db, auth.tenantId, draftPublicId);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.billing.draft_status_changed',
    entityType: 'generator_monthly_billing_draft',
    entityUuid: current.public_id,
    before: { status: current.status },
    after: { status: updated.status, financial_effect_applied: false }
  });
  return serializeBillingDraft(updated);
}

function findPeriodOrFail(db, tenantId, publicId) {
  const normalized = cleanRequired(publicId, 'period_id', 120);
  const row = db.prepare(`
    SELECT * FROM generator_reading_periods WHERE tenant_id = ? AND public_id = ? LIMIT 1
  `).get(Number(tenantId), normalized);
  if (!row) throw httpError(404, 'BILLING_PERIOD_NOT_FOUND', 'Billing period was not found in this organization.');
  return row;
}

function findGeneratorOrFail(db, tenantId, publicId) {
  const normalized = cleanRequired(publicId, 'generator_id', 120);
  const row = db.prepare(`SELECT * FROM generator_units WHERE tenant_id = ? AND public_id = ? LIMIT 1`)
    .get(Number(tenantId), normalized);
  if (!row) throw httpError(404, 'BILLING_GENERATOR_NOT_FOUND', 'Generator was not found in this organization.');
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

function serializeBillingPeriod(row) {
  return {
    id: row.public_id,
    period_key: row.period_key,
    title: row.title,
    status: row.status,
    locked_at: row.locked_at || null,
    reading_count: Number(row.reading_count || 0),
    tariff_count: Number(row.tariff_count || 0),
    draft_count: Number(row.draft_count || 0),
    reviewed_count: Number(row.reviewed_count || 0),
    total_amount_iqd: Number(row.total_amount_iqd || 0),
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function serializeTariffGenerator(row) {
  return {
    generator: { id: row.generator_id, code: row.generator_code, name: row.generator_name },
    reading_count: Number(row.reading_count || 0),
    tariff: row.tariff_id ? {
      id: row.tariff_id,
      price_per_amp_iqd: Number(row.price_per_amp_iqd || 0),
      fixed_fee_iqd: Number(row.fixed_fee_iqd || 0),
      calculation_method: row.calculation_method,
      created_at: row.tariff_created_at,
      updated_at: row.tariff_updated_at
    } : null,
    tariff_locked: Boolean(row.tariff_locked)
  };
}

function serializeTariff(row) {
  return {
    id: row.public_id,
    price_per_amp_iqd: Number(row.price_per_amp_iqd || 0),
    fixed_fee_iqd: Number(row.fixed_fee_iqd || 0),
    calculation_method: row.calculation_method,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function serializeBillingDraft(row) {
  return {
    id: row.public_id,
    period_id: row.period_public_id || null,
    period_key: row.period_key || null,
    subscriber_id: row.subscriber_public_id || null,
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
    calculation_method: row.calculation_method,
    reviewed_at: row.reviewed_at || null,
    created_at: row.created_at,
    updated_at: row.updated_at,
    financial_effect_applied: false
  };
}

function normalizeMoney(value, field) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < 0 || number > 1_000_000_000) {
    throw httpError(400, 'INVALID_BILLING_MONEY_VALUE', `${field} must be a non-negative integer amount in IQD.`);
  }
  return number;
}
function normalizeDraftStatus(value) {
  const status = typeof value === 'string' ? value.trim() : '';
  if (!DRAFT_STATUSES.has(status)) throw httpError(400, 'INVALID_BILLING_DRAFT_STATUS', 'status must be draft or reviewed.');
  return status;
}
function safeAmount(amperes, price, fee) {
  const amount = Number(amperes) * Number(price) + Number(fee);
  if (!Number.isSafeInteger(amount) || amount < 0) {
    throw httpError(409, 'BILLING_AMOUNT_OVERFLOW', 'Calculated billing amount is outside the supported integer range.');
  }
  return amount;
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
  listOwnerBillingPeriods,
  getOwnerBillingWorkspace,
  upsertOwnerBillingTariff,
  generateOwnerBillingDrafts,
  updateOwnerBillingDraftStatus,
  serializeBillingPeriod,
  serializeBillingDraft
};
