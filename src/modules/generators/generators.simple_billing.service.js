const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema, writeAuditLog } = require('./generators.db');

const SCHEMA_FILE = path.join(__dirname, 'generators.simple_billing.schema.sql');
const initializedDatabases = new WeakSet();

function billingDb() {
  const db = ensureGeneratorsSchema();
  if (!initializedDatabases.has(db)) {
    db.exec(fs.readFileSync(SCHEMA_FILE, 'utf8'));
    initializedDatabases.add(db);
  }
  return db;
}

function listOwnerMonthlyPeriods(auth) {
  assertOwner(auth);
  const db = billingDb();
  const rows = db.prepare(`
    SELECT p.*,
      (SELECT COUNT(*) FROM generator_meter_readings r
       WHERE r.tenant_id = p.tenant_id AND r.period_id = p.id) AS reading_count,
      (SELECT COUNT(*) FROM generator_monthly_prices x
       WHERE x.tenant_id = p.tenant_id AND x.period_id = p.id) AS price_count,
      (SELECT COUNT(*) FROM generator_monthly_invoices i
       WHERE i.tenant_id = p.tenant_id AND i.period_id = p.id) AS invoice_count,
      (SELECT COALESCE(SUM(i.amount_iqd), 0) FROM generator_monthly_invoices i
       WHERE i.tenant_id = p.tenant_id AND i.period_id = p.id) AS total_iqd
    FROM generator_reading_periods p
    WHERE p.tenant_id = ?
    ORDER BY p.period_key DESC
  `).all(auth.tenantId);
  return {
    server_time: new Date().toISOString(),
    periods: rows.map(serializePeriod),
    flow: ['lock_readings', 'set_price', 'create_invoices'],
    collection_enabled: false
  };
}

function getOwnerMonthlyWorkspace(auth, periodPublicId, query = {}) {
  assertOwner(auth);
  const db = billingDb();
  const period = findPeriod(db, auth.tenantId, periodPublicId);
  const q = cleanOptional(query.q, 120);
  const generatorRows = db.prepare(`
    SELECT g.id AS generator_db_id, g.public_id AS generator_id, g.code AS generator_code,
      g.name AS generator_name, COUNT(r.id) AS reading_count,
      x.public_id AS price_id, x.price_per_amp_iqd, x.fixed_fee_iqd,
      EXISTS (
        SELECT 1 FROM generator_monthly_invoices i
        WHERE i.tenant_id = ? AND i.period_id = ? AND i.generator_unit_id = g.id
      ) AS price_locked
    FROM generator_meter_readings r
    JOIN generator_subscribers s ON s.id = r.subscriber_id
    JOIN generator_units g ON g.id = s.generator_unit_id
    LEFT JOIN generator_monthly_prices x
      ON x.tenant_id = r.tenant_id AND x.period_id = r.period_id
      AND x.generator_unit_id = g.id
    WHERE r.tenant_id = ? AND r.period_id = ?
    GROUP BY g.id, x.id
    ORDER BY g.name COLLATE NOCASE
  `).all(auth.tenantId, period.id, auth.tenantId, period.id);

  const invoiceRows = db.prepare(`
    SELECT i.*, p.public_id AS period_public_id, p.period_key,
      s.public_id AS subscriber_public_id, g.public_id AS generator_public_id
    FROM generator_monthly_invoices i
    JOIN generator_reading_periods p ON p.id = i.period_id
    JOIN generator_subscribers s ON s.id = i.subscriber_id
    JOIN generator_units g ON g.id = i.generator_unit_id
    WHERE i.tenant_id = ? AND i.period_id = ?
      AND (? IS NULL OR i.subscriber_name_snapshot LIKE '%' || ? || '%'
        OR i.account_number_snapshot LIKE '%' || ? || '%'
        OR i.invoice_number LIKE '%' || ? || '%')
    ORDER BY i.subscriber_name_snapshot COLLATE NOCASE, i.id
  `).all(auth.tenantId, period.id, q, q, q, q);

  const readingCount = Number(db.prepare(
    'SELECT COUNT(*) AS count FROM generator_meter_readings WHERE tenant_id = ? AND period_id = ?'
  ).get(auth.tenantId, period.id).count || 0);
  const requiredPriceCount = generatorRows.length;
  const priceCount = generatorRows.filter((row) => row.price_id).length;
  const invoiceCount = invoiceRows.length;
  const totalIqd = invoiceRows.reduce((sum, row) => sum + Number(row.amount_iqd || 0), 0);

  return {
    server_time: new Date().toISOString(),
    period: serializePeriod({
      ...period,
      reading_count: readingCount,
      price_count: priceCount,
      invoice_count: invoiceCount,
      total_iqd: totalIqd
    }),
    generators: generatorRows.map(serializeGeneratorPrice),
    invoices: invoiceRows.map(serializeInvoice),
    summary: {
      reading_count: readingCount,
      required_price_count: requiredPriceCount,
      price_count: priceCount,
      missing_price_count: Math.max(0, requiredPriceCount - priceCount),
      invoice_count: invoiceCount,
      total_iqd: totalIqd,
      unpaid_iqd: totalIqd,
      can_create_invoices:
        period.status === 'locked' &&
        readingCount > 0 &&
        priceCount === requiredPriceCount
    },
    invoice_is_debt: true,
    collection_enabled: false
  };
}

function saveOwnerMonthlyPrice(auth, periodPublicId, generatorPublicId, body) {
  assertOwner(auth);
  const db = billingDb();
  const period = findPeriod(db, auth.tenantId, periodPublicId);
  if (period.status !== 'locked') {
    throw httpError(409, 'MONTHLY_PERIOD_NOT_LOCKED', 'Lock the reading period before setting the monthly price.');
  }
  const generator = db.prepare(
    'SELECT * FROM generator_units WHERE tenant_id = ? AND public_id = ? LIMIT 1'
  ).get(auth.tenantId, cleanRequired(generatorPublicId, 'generator_id', 120));
  if (!generator) {
    throw httpError(404, 'MONTHLY_GENERATOR_NOT_FOUND', 'Generator was not found.');
  }
  const readingCount = Number(db.prepare(`
    SELECT COUNT(*) AS count
    FROM generator_meter_readings r
    JOIN generator_subscribers s ON s.id = r.subscriber_id
    WHERE r.tenant_id = ? AND r.period_id = ? AND s.generator_unit_id = ?
  `).get(auth.tenantId, period.id, generator.id).count || 0);
  if (!readingCount) {
    throw httpError(409, 'MONTHLY_GENERATOR_HAS_NO_READINGS', 'This generator has no readings in the selected month.');
  }
  const invoiceCount = Number(db.prepare(`
    SELECT COUNT(*) AS count FROM generator_monthly_invoices
    WHERE tenant_id = ? AND period_id = ? AND generator_unit_id = ?
  `).get(auth.tenantId, period.id, generator.id).count || 0);
  if (invoiceCount) {
    throw httpError(409, 'MONTHLY_PRICE_LOCKED', 'The price cannot be changed after invoices were created.');
  }

  const price = money(body?.price_per_amp_iqd, 'price_per_amp_iqd');
  const fee = money(body?.fixed_fee_iqd ?? 0, 'fixed_fee_iqd');
  const current = db.prepare(`
    SELECT * FROM generator_monthly_prices
    WHERE tenant_id = ? AND period_id = ? AND generator_unit_id = ? LIMIT 1
  `).get(auth.tenantId, period.id, generator.id);
  if (current) {
    db.prepare(`
      UPDATE generator_monthly_prices
      SET price_per_amp_iqd = ?, fixed_fee_iqd = ?, configured_by_account_id = ?
      WHERE id = ? AND tenant_id = ?
    `).run(price, fee, auth.accountId, current.id, auth.tenantId);
  } else {
    db.prepare(`
      INSERT INTO generator_monthly_prices (
        public_id, tenant_id, period_id, generator_unit_id,
        price_per_amp_iqd, fixed_fee_iqd, configured_by_account_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(crypto.randomUUID(), auth.tenantId, period.id, generator.id, price, fee, auth.accountId);
  }
  const updated = db.prepare(`
    SELECT * FROM generator_monthly_prices
    WHERE tenant_id = ? AND period_id = ? AND generator_unit_id = ? LIMIT 1
  `).get(auth.tenantId, period.id, generator.id);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: current ? 'generator.monthly_price.updated' : 'generator.monthly_price.created',
    entityType: 'generator_monthly_price',
    entityUuid: updated.public_id,
    before: current,
    after: updated
  });
  return {
    generator: { id: generator.public_id, code: generator.code, name: generator.name },
    price: serializePrice(updated)
  };
}

function createOwnerMonthlyInvoices(auth, periodPublicId, body) {
  assertOwner(auth);
  if (body?.confirm !== true) {
    throw httpError(400, 'MONTHLY_CONFIRM_REQUIRED', 'Confirm invoice creation.');
  }
  const db = billingDb();
  const period = findPeriod(db, auth.tenantId, periodPublicId);
  if (period.status !== 'locked') {
    throw httpError(409, 'MONTHLY_PERIOD_NOT_LOCKED', 'Lock the reading period before creating invoices.');
  }
  const rows = db.prepare(`
    SELECT r.*, s.id AS subscriber_db_id, s.public_id AS subscriber_public_id,
      s.full_name, s.account_number, s.meter_number, s.contracted_amperes,
      g.id AS generator_db_id, g.public_id AS generator_public_id, g.name AS generator_name,
      x.id AS price_db_id, x.price_per_amp_iqd, x.fixed_fee_iqd
    FROM generator_meter_readings r
    JOIN generator_subscribers s ON s.id = r.subscriber_id
    JOIN generator_units g ON g.id = s.generator_unit_id
    LEFT JOIN generator_monthly_prices x
      ON x.tenant_id = r.tenant_id AND x.period_id = r.period_id
      AND x.generator_unit_id = g.id
    WHERE r.tenant_id = ? AND r.period_id = ?
    ORDER BY r.id
  `).all(auth.tenantId, period.id);
  if (!rows.length) {
    throw httpError(409, 'MONTHLY_NO_READINGS', 'There are no readings in this month.');
  }
  const missing = [...new Map(
    rows.filter((row) => !row.price_db_id)
      .map((row) => [row.generator_public_id, {
        id: row.generator_public_id,
        name: row.generator_name
      }])
  ).values()];
  if (missing.length) {
    throw httpError(409, 'MONTHLY_PRICE_MISSING', 'Set a price for every generator first.', {
      missing_generators: missing
    });
  }

  let createdCount = 0;
  db.exec('BEGIN IMMEDIATE');
  try {
    const existingCount = Number(db.prepare(`
      SELECT COUNT(*) AS count FROM generator_monthly_invoices
      WHERE tenant_id = ? AND period_id = ?
    `).get(auth.tenantId, period.id).count || 0);
    let sequence = existingCount + 1;
    const insert = db.prepare(`
      INSERT OR IGNORE INTO generator_monthly_invoices (
        public_id, tenant_id, period_id, subscriber_id, meter_reading_id,
        generator_unit_id, invoice_number, status,
        subscriber_name_snapshot, account_number_snapshot, meter_number_snapshot,
        generator_name_snapshot, contracted_amperes_snapshot,
        price_per_amp_iqd_snapshot, fixed_fee_iqd_snapshot,
        previous_value_snapshot, current_value_snapshot, consumption_snapshot,
        amount_iqd, created_by_account_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'unpaid', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    for (const row of rows) {
      const amount = safeAmount(row.contracted_amperes, row.price_per_amp_iqd, row.fixed_fee_iqd);
      const number = `INV-${period.period_key.replace('-', '')}-${String(sequence).padStart(4, '0')}`;
      const result = insert.run(
        crypto.randomUUID(), auth.tenantId, period.id, row.subscriber_db_id,
        row.id, row.generator_db_id, number,
        row.full_name, row.account_number, row.meter_number, row.generator_name,
        Number(row.contracted_amperes || 0), Number(row.price_per_amp_iqd || 0),
        Number(row.fixed_fee_iqd || 0), Number(row.previous_value),
        Number(row.current_value), Number(row.consumption), amount, auth.accountId
      );
      if (Number(result.changes || 0)) {
        createdCount += 1;
        sequence += 1;
      }
    }
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.monthly_invoices.created',
    entityType: 'generator_reading_period',
    entityUuid: period.public_id,
    after: { created_count: createdCount, invoice_is_debt: true }
  });
  return {
    created_count: createdCount,
    existing_count: rows.length - createdCount,
    workspace: getOwnerMonthlyWorkspace(auth, period.public_id),
    invoice_is_debt: true,
    collection_enabled: false
  };
}

function findPeriod(db, tenantId, publicId) {
  const row = db.prepare(
    'SELECT * FROM generator_reading_periods WHERE tenant_id = ? AND public_id = ? LIMIT 1'
  ).get(Number(tenantId), cleanRequired(publicId, 'period_id', 120));
  if (!row) throw httpError(404, 'MONTHLY_PERIOD_NOT_FOUND', 'Reading month was not found.');
  return row;
}
function serializePeriod(row) {
  return {
    id: row.public_id,
    period_key: row.period_key,
    title: row.title,
    status: row.status,
    locked_at: row.locked_at || null,
    reading_count: Number(row.reading_count || 0),
    price_count: Number(row.price_count || 0),
    invoice_count: Number(row.invoice_count || 0),
    total_iqd: Number(row.total_iqd || 0)
  };
}
function serializeGeneratorPrice(row) {
  return {
    generator: {
      id: row.generator_id,
      code: row.generator_code,
      name: row.generator_name
    },
    reading_count: Number(row.reading_count || 0),
    price: row.price_id ? {
      id: row.price_id,
      price_per_amp_iqd: Number(row.price_per_amp_iqd || 0),
      fixed_fee_iqd: Number(row.fixed_fee_iqd || 0)
    } : null,
    price_locked: Boolean(row.price_locked)
  };
}
function serializePrice(row) {
  return {
    id: row.public_id,
    price_per_amp_iqd: Number(row.price_per_amp_iqd || 0),
    fixed_fee_iqd: Number(row.fixed_fee_iqd || 0)
  };
}
function serializeInvoice(row) {
  return {
    id: row.public_id,
    invoice_number: row.invoice_number,
    period_id: row.period_public_id || null,
    period_key: row.period_key || null,
    subscriber_id: row.subscriber_public_id || null,
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
    debt_iqd: Number(row.amount_iqd || 0),
    created_at: row.created_at
  };
}
function money(value, field) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < 0 || number > 1_000_000_000) {
    throw httpError(400, 'INVALID_MONTHLY_MONEY', `${field} must be a non-negative integer in IQD.`);
  }
  return number;
}
function safeAmount(amperes, price, fee) {
  const amount = Number(amperes || 0) * Number(price || 0) + Number(fee || 0);
  if (!Number.isSafeInteger(amount) || amount < 0) {
    throw httpError(409, 'MONTHLY_AMOUNT_INVALID', 'Calculated invoice amount is invalid.');
  }
  return amount;
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
  listOwnerMonthlyPeriods,
  getOwnerMonthlyWorkspace,
  saveOwnerMonthlyPrice,
  createOwnerMonthlyInvoices
};
