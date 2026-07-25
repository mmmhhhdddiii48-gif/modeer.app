const crypto = require('node:crypto');
const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema, writeAuditLog } = require('./generators.db');

const PERIOD_KEY_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;
const READING_CONFLICT_CODES = new Set([
  'METER_READING_ALREADY_EXISTS',
  'METER_READING_PREVIOUS_CHANGED'
]);

function listOwnerReadingPeriods(auth) {
  assertOwner(auth);
  const db = ensureGeneratorsSchema();
  const rows = db.prepare(`
    SELECT p.*,
      (SELECT COUNT(*) FROM generator_meter_readings mr WHERE mr.period_id = p.id) AS reading_count,
      (SELECT COUNT(*) FROM generator_subscribers s WHERE s.tenant_id = p.tenant_id AND s.status = 'active') AS active_subscriber_count
    FROM generator_reading_periods p
    WHERE p.tenant_id = ?
    ORDER BY p.period_key DESC
  `).all(auth.tenantId);
  return {
    server_time: new Date().toISOString(),
    periods: rows.map(serializePeriod)
  };
}

function createOwnerReadingPeriod(auth, body) {
  assertOwner(auth);
  const periodKey = normalizePeriodKey(body?.period_key);
  const title = cleanOptional(body?.title, 120) || `دورة قراءة ${periodKey}`;
  const { startsAt, endsAt } = periodDates(periodKey);
  const db = ensureGeneratorsSchema();
  const publicId = crypto.randomUUID();
  try {
    const result = db.prepare(`
      INSERT INTO generator_reading_periods (
        public_id, tenant_id, period_key, title, starts_at, ends_at,
        status, opened_by_account_id
      ) VALUES (?, ?, ?, ?, ?, ?, 'open', ?)
    `).run(publicId, auth.tenantId, periodKey, title, startsAt, endsAt, auth.accountId);
    const period = findPeriodById(auth.tenantId, Number(result.lastInsertRowid));
    writeAuditLog({
      tenantId: auth.tenantId,
      actorAccountId: auth.accountId,
      action: 'generator.reading.period_created',
      entityType: 'generator_reading_period',
      entityUuid: publicId,
      after: serializePeriod(period)
    });
    return serializePeriod(period);
  } catch (error) {
    const text = String(error?.message || '');
    if (/uq_generator_reading_one_open_period|UNIQUE constraint failed: generator_reading_periods\.tenant_id/i.test(text)) {
      throw httpError(409, 'METER_READING_OPEN_PERIOD_EXISTS', 'Another meter-reading period is already open. Lock it before opening a new period.');
    }
    if (/generator_reading_periods\.tenant_id, generator_reading_periods\.period_key/i.test(text)) {
      throw httpError(409, 'METER_READING_PERIOD_EXISTS', 'This meter-reading period already exists.');
    }
    throw error;
  }
}

function lockOwnerReadingPeriod(auth, periodPublicId, body) {
  assertOwner(auth);
  if (body?.confirm !== true) {
    throw httpError(400, 'METER_READING_LOCK_CONFIRMATION_REQUIRED', 'confirm=true is required to lock a meter-reading period.');
  }
  const db = ensureGeneratorsSchema();
  const current = findPeriodOrFail(auth.tenantId, periodPublicId);
  if (current.status !== 'open') {
    throw httpError(409, 'METER_READING_PERIOD_ALREADY_LOCKED', 'The meter-reading period is already locked.');
  }
  db.prepare(`
    UPDATE generator_reading_periods
    SET status = 'locked', locked_by_account_id = ?, locked_at = datetime('now')
    WHERE id = ? AND tenant_id = ? AND status = 'open'
  `).run(auth.accountId, current.id, auth.tenantId);
  const updated = findPeriodById(auth.tenantId, current.id);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.reading.period_locked',
    entityType: 'generator_reading_period',
    entityUuid: current.public_id,
    before: serializePeriod(current),
    after: serializePeriod(updated)
  });
  return serializePeriod(updated);
}

function listOwnerMeterReadings(auth, query = {}) {
  assertOwner(auth);
  const db = ensureGeneratorsSchema();
  const period = query.period_id
    ? findPeriodOrFail(auth.tenantId, query.period_id)
    : db.prepare(`
        SELECT * FROM generator_reading_periods
        WHERE tenant_id = ? ORDER BY CASE status WHEN 'open' THEN 0 ELSE 1 END, period_key DESC LIMIT 1
      `).get(auth.tenantId);
  if (!period) return { period: null, readings: [], summary: emptyReadingSummary() };
  const q = cleanOptional(query.q, 120);
  const rows = db.prepare(`
    SELECT mr.*, s.public_id AS subscriber_public_id, g.public_id AS generator_public_id,
      g.name AS generator_name, r.public_id AS route_public_id, r.name AS route_name,
      a.public_id AS collector_public_id, a.full_name AS collector_name
    FROM generator_meter_readings mr
    JOIN generator_subscribers s ON s.id = mr.subscriber_id
    JOIN generator_units g ON g.id = s.generator_unit_id
    LEFT JOIN generator_routes r ON r.id = s.route_id
    JOIN generator_accounts a ON a.id = mr.collector_account_id
    WHERE mr.tenant_id = ? AND mr.period_id = ?
      AND (? IS NULL OR mr.subscriber_name_snapshot LIKE '%' || ? || '%'
        OR mr.account_number_snapshot LIKE '%' || ? || '%'
        OR COALESCE(mr.meter_number_snapshot, '') LIKE '%' || ? || '%')
    ORDER BY mr.server_received_at DESC, mr.id DESC
  `).all(auth.tenantId, period.id, q, q, q, q);
  const summary = db.prepare(`
    SELECT COUNT(*) AS reading_count,
      COALESCE(SUM(consumption), 0) AS total_consumption,
      (SELECT COUNT(*) FROM generator_subscribers WHERE tenant_id = ? AND status = 'active') AS active_subscriber_count
    FROM generator_meter_readings WHERE tenant_id = ? AND period_id = ?
  `).get(auth.tenantId, auth.tenantId, period.id);
  return {
    period: serializePeriod(period),
    readings: rows.map(serializeReading),
    summary: {
      reading_count: Number(summary.reading_count || 0),
      active_subscriber_count: Number(summary.active_subscriber_count || 0),
      remaining_count: Math.max(0, Number(summary.active_subscriber_count || 0) - Number(summary.reading_count || 0)),
      total_consumption: Number(summary.total_consumption || 0)
    }
  };
}

function getCollectorReadingContext(auth) {
  assertCollectorWithPermission(auth);
  const db = ensureGeneratorsSchema();
  const period = db.prepare(`
    SELECT * FROM generator_reading_periods
    WHERE tenant_id = ? AND status = 'open'
    ORDER BY period_key DESC LIMIT 1
  `).get(auth.tenantId);
  if (!period) {
    return { server_time: new Date().toISOString(), period: null, subscribers: [], reading_enabled: false };
  }
  const rows = db.prepare(`
    SELECT s.public_id AS subscriber_id, s.full_name, s.account_number, s.meter_number,
      s.area, s.address, g.public_id AS generator_id, g.name AS generator_name,
      r.public_id AS route_id, r.name AS route_name,
      COALESCE((
        SELECT previous.current_value
        FROM generator_meter_readings previous
        JOIN generator_reading_periods pp ON pp.id = previous.period_id
        WHERE previous.tenant_id = s.tenant_id AND previous.subscriber_id = s.id
          AND pp.period_key < ?
        ORDER BY pp.period_key DESC, previous.id DESC LIMIT 1
      ), 0) AS previous_value,
      current.public_id AS current_reading_id,
      current.current_value AS current_value,
      current.consumption AS current_consumption,
      current.server_received_at AS current_server_received_at
    FROM generator_subscribers s
    JOIN generator_units g ON g.id = s.generator_unit_id
    LEFT JOIN generator_routes r ON r.id = s.route_id
    LEFT JOIN generator_meter_readings current
      ON current.tenant_id = s.tenant_id AND current.period_id = ? AND current.subscriber_id = s.id
    WHERE s.tenant_id = ? AND s.status = 'active'
      AND EXISTS (
        SELECT 1 FROM generator_collector_assignments ca
        WHERE ca.tenant_id = s.tenant_id AND ca.collector_account_id = ? AND ca.status = 'active'
          AND (
            (ca.assignment_type = 'subscriber' AND ca.target_public_id = s.public_id)
            OR (ca.assignment_type = 'route' AND ca.target_public_id = r.public_id)
            OR (ca.assignment_type = 'generator' AND ca.target_public_id = g.public_id)
          )
      )
    ORDER BY COALESCE(r.name, ''), s.full_name COLLATE NOCASE
  `).all(period.period_key, period.id, auth.tenantId, auth.accountId);
  return {
    server_time: new Date().toISOString(),
    period: serializePeriod(period),
    subscribers: rows.map((row) => ({
      id: row.subscriber_id,
      full_name: row.full_name,
      account_number: row.account_number,
      meter_number: row.meter_number,
      area: row.area,
      address: row.address,
      generator: { id: row.generator_id, name: row.generator_name },
      route: row.route_id ? { id: row.route_id, name: row.route_name } : null,
      previous_value: Number(row.previous_value || 0),
      current_reading: row.current_reading_id ? {
        id: row.current_reading_id,
        current_value: Number(row.current_value),
        consumption: Number(row.current_consumption),
        server_received_at: row.current_server_received_at
      } : null
    })),
    reading_enabled: true
  };
}

function applyMeterReadingOperation(auth, payload, clientCreatedAt, operationUuid) {
  assertCollectorWithPermission(auth);
  const periodId = cleanRequired(payload?.period_id, 'period_id', 120);
  const subscriberId = cleanRequired(payload?.subscriber_id, 'subscriber_id', 120);
  const previousValue = normalizeReadingValue(payload?.previous_value, 'previous_value');
  const currentValue = normalizeReadingValue(payload?.current_value, 'current_value');
  const note = cleanOptional(payload?.note, 500);
  if (currentValue < previousValue) {
    throw httpError(400, 'METER_READING_DECREASE_NOT_ALLOWED', 'current_value cannot be lower than previous_value.');
  }

  const db = ensureGeneratorsSchema();
  const period = findPeriodOrFail(auth.tenantId, periodId);
  if (period.status !== 'open') {
    throw httpError(409, 'METER_READING_PERIOD_NOT_OPEN', 'The meter-reading period is locked and cannot accept new readings.');
  }
  const subscriber = findAssignedSubscriberOrFail(db, auth, subscriberId);
  const expectedPrevious = latestPreviousValue(db, auth.tenantId, subscriber.id, period.period_key);
  if (!numbersEqual(previousValue, expectedPrevious)) {
    throw httpError(409, 'METER_READING_PREVIOUS_CHANGED', 'The previous reading changed on the server.', {
      submitted_previous_value: previousValue,
      server_previous_value: expectedPrevious
    });
  }
  const existing = db.prepare(`
    SELECT * FROM generator_meter_readings
    WHERE tenant_id = ? AND period_id = ? AND subscriber_id = ? LIMIT 1
  `).get(auth.tenantId, period.id, subscriber.id);
  if (existing) {
    throw httpError(409, 'METER_READING_ALREADY_EXISTS', 'A reading already exists for this subscriber in the current period.', {
      existing_reading: serializeReading(existing)
    });
  }

  const publicId = crypto.randomUUID();
  const consumption = currentValue - expectedPrevious;
  db.prepare(`
    INSERT INTO generator_meter_readings (
      public_id, tenant_id, period_id, subscriber_id, collector_account_id,
      operation_uuid, previous_value, current_value, consumption,
      subscriber_name_snapshot, account_number_snapshot, meter_number_snapshot,
      note, client_created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    publicId,
    auth.tenantId,
    period.id,
    subscriber.id,
    auth.accountId,
    operationUuid,
    expectedPrevious,
    currentValue,
    consumption,
    subscriber.full_name,
    subscriber.account_number,
    subscriber.meter_number,
    note,
    clientCreatedAt
  );
  const created = db.prepare('SELECT * FROM generator_meter_readings WHERE public_id = ?').get(publicId);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.reading.created',
    entityType: 'generator_meter_reading',
    entityUuid: publicId,
    after: serializeReading(created),
    clientCreatedAt
  });
  return serializeReading(created);
}

function findAssignedSubscriberOrFail(db, auth, subscriberPublicId) {
  const row = db.prepare(`
    SELECT s.*, g.public_id AS generator_public_id, g.name AS generator_name,
      r.public_id AS route_public_id, r.name AS route_name
    FROM generator_subscribers s
    JOIN generator_units g ON g.id = s.generator_unit_id
    LEFT JOIN generator_routes r ON r.id = s.route_id
    WHERE s.tenant_id = ? AND s.public_id = ? AND s.status = 'active'
      AND EXISTS (
        SELECT 1 FROM generator_collector_assignments ca
        WHERE ca.tenant_id = s.tenant_id AND ca.collector_account_id = ? AND ca.status = 'active'
          AND (
            (ca.assignment_type = 'subscriber' AND ca.target_public_id = s.public_id)
            OR (ca.assignment_type = 'route' AND ca.target_public_id = r.public_id)
            OR (ca.assignment_type = 'generator' AND ca.target_public_id = g.public_id)
          )
      )
    LIMIT 1
  `).get(auth.tenantId, subscriberPublicId, auth.accountId);
  if (!row) throw httpError(403, 'METER_READING_SUBSCRIBER_NOT_ASSIGNED', 'This subscriber is not active or not assigned to the collector.');
  return row;
}

function latestPreviousValue(db, tenantId, subscriberId, periodKey) {
  const row = db.prepare(`
    SELECT mr.current_value
    FROM generator_meter_readings mr
    JOIN generator_reading_periods p ON p.id = mr.period_id
    WHERE mr.tenant_id = ? AND mr.subscriber_id = ? AND p.period_key < ?
    ORDER BY p.period_key DESC, mr.id DESC LIMIT 1
  `).get(tenantId, subscriberId, periodKey);
  return row ? Number(row.current_value) : 0;
}

function findPeriodOrFail(tenantId, publicId) {
  const normalized = cleanRequired(publicId, 'period_id', 120);
  const db = ensureGeneratorsSchema();
  const row = db.prepare('SELECT * FROM generator_reading_periods WHERE tenant_id = ? AND public_id = ? LIMIT 1')
    .get(Number(tenantId), normalized);
  if (!row) throw httpError(404, 'METER_READING_PERIOD_NOT_FOUND', 'Meter-reading period was not found in this organization.');
  return row;
}

function findPeriodById(tenantId, id) {
  const db = ensureGeneratorsSchema();
  return db.prepare('SELECT * FROM generator_reading_periods WHERE tenant_id = ? AND id = ? LIMIT 1')
    .get(Number(tenantId), Number(id));
}

function serializePeriod(row) {
  return {
    id: row.public_id,
    period_key: row.period_key,
    title: row.title,
    starts_at: row.starts_at,
    ends_at: row.ends_at,
    status: row.status,
    locked_at: row.locked_at || null,
    reading_count: Number(row.reading_count || 0),
    active_subscriber_count: Number(row.active_subscriber_count || 0),
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function serializeReading(row) {
  return {
    id: row.public_id,
    operation_uuid: row.operation_uuid,
    period_id: row.period_public_id || null,
    subscriber_id: row.subscriber_public_id || null,
    subscriber_name: row.subscriber_name_snapshot,
    account_number: row.account_number_snapshot,
    meter_number: row.meter_number_snapshot,
    previous_value: Number(row.previous_value),
    current_value: Number(row.current_value),
    consumption: Number(row.consumption),
    note: row.note,
    collector: row.collector_public_id ? { id: row.collector_public_id, name: row.collector_name } : null,
    generator: row.generator_public_id ? { id: row.generator_public_id, name: row.generator_name } : null,
    route: row.route_public_id ? { id: row.route_public_id, name: row.route_name } : null,
    client_created_at: row.client_created_at,
    server_received_at: row.server_received_at,
    status: row.status
  };
}

function normalizePeriodKey(value) {
  const key = typeof value === 'string' ? value.trim() : '';
  if (!PERIOD_KEY_PATTERN.test(key)) throw httpError(400, 'INVALID_READING_PERIOD_KEY', 'period_key must use YYYY-MM format.');
  return key;
}

function periodDates(periodKey) {
  const [year, month] = periodKey.split('-').map(Number);
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return {
    startsAt: `${periodKey}-01`,
    endsAt: `${periodKey}-${String(lastDay).padStart(2, '0')}`
  };
}

function normalizeReadingValue(value, field) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0 || number > 1e12) {
    throw httpError(400, 'INVALID_METER_READING_VALUE', `${field} must be a non-negative finite number.`);
  }
  return Number(number.toFixed(3));
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
function numbersEqual(a, b) { return Math.abs(Number(a) - Number(b)) < 0.0005; }
function emptyReadingSummary() { return { reading_count: 0, active_subscriber_count: 0, remaining_count: 0, total_consumption: 0 }; }
function assertOwner(auth) {
  if (!auth || auth.role !== 'owner' || !auth.tenantId || !auth.accountId) {
    throw httpError(403, 'GENERATOR_PERMISSION_DENIED', 'Owner account is required.');
  }
}
function assertCollectorWithPermission(auth) {
  const permissions = Array.isArray(auth?.permissions) ? auth.permissions : [];
  if (!auth || auth.role !== 'collector' || !auth.tenantId || !auth.accountId || !permissions.includes('readings.create')) {
    throw httpError(403, 'GENERATOR_PERMISSION_DENIED', 'Collector reading permission is required.');
  }
}
function isReadingConflictCode(code) { return READING_CONFLICT_CODES.has(code); }

module.exports = {
  listOwnerReadingPeriods,
  createOwnerReadingPeriod,
  lockOwnerReadingPeriod,
  listOwnerMeterReadings,
  getCollectorReadingContext,
  applyMeterReadingOperation,
  isReadingConflictCode,
  serializePeriod,
  serializeReading
};
