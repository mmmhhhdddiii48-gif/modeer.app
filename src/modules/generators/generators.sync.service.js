const crypto = require('node:crypto');
const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema, writeAuditLog } = require('./generators.db');
const { applyMeterReadingOperation, isReadingConflictCode } = require('./generators.readings.service');

const STAGE04_OPERATION_TYPES = new Set(['sync.probe', 'auth.session_seen', 'reading.create']);
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function recordSyncOperation(auth, body) {
  const operationUuid = typeof body?.operation_uuid === 'string' ? body.operation_uuid.trim() : '';
  const operationType = typeof body?.operation_type === 'string' ? body.operation_type.trim() : '';
  const clientCreatedAt = typeof body?.client_created_at === 'string' ? body.client_created_at.trim() : '';
  const payload = body?.payload == null ? {} : body.payload;
  if (!UUID_PATTERN.test(operationUuid)) throw httpError(400, 'INVALID_OPERATION_UUID', 'operation_uuid must be a valid UUID.');
  if (!STAGE04_OPERATION_TYPES.has(operationType)) {
    throw httpError(409, 'STAGE04_OPERATION_NOT_ENABLED', 'This generator operation is not enabled in Stage04.');
  }
  if (!clientCreatedAt || !Number.isFinite(Date.parse(clientCreatedAt))) {
    throw httpError(400, 'INVALID_CLIENT_CREATED_AT', 'client_created_at must be a valid ISO date.');
  }
  const payloadJson = stableStringify(payload);
  const payloadHash = crypto.createHash('sha256').update(`${operationType}:${payloadJson}`).digest('hex');
  const db = ensureGeneratorsSchema();
  const existing = db.prepare('SELECT * FROM generator_sync_operations WHERE tenant_id = ? AND operation_uuid = ? LIMIT 1')
    .get(auth.tenantId, operationUuid);
  if (existing) {
    if (existing.payload_hash !== payloadHash || existing.operation_type !== operationType) {
      throw httpError(409, 'IDEMPOTENCY_CONFLICT', 'This operation UUID was already used with different content.');
    }
    return serializeOperation(existing, true);
  }

  db.exec('BEGIN IMMEDIATE');
  try {
    const outcome = executeOperation(auth, operationType, payload, clientCreatedAt, operationUuid);
    db.prepare(`
      INSERT INTO generator_sync_operations (
        tenant_id, account_id, operation_uuid, operation_type, payload_hash,
        payload_json, client_created_at, status, conflict_code, response_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      auth.tenantId,
      auth.accountId,
      operationUuid,
      operationType,
      payloadHash,
      payloadJson,
      clientCreatedAt,
      outcome.status,
      outcome.conflictCode,
      JSON.stringify(outcome.response)
    );
    const created = db.prepare('SELECT * FROM generator_sync_operations WHERE tenant_id = ? AND operation_uuid = ?')
      .get(auth.tenantId, operationUuid);
    writeAuditLog({
      tenantId: auth.tenantId,
      actorAccountId: auth.accountId,
      action: 'generator.sync.operation_recorded',
      entityType: 'sync_operation',
      entityUuid: operationUuid,
      after: { operation_type: operationType, status: created.status, conflict_code: created.conflict_code },
      clientCreatedAt
    });
    db.exec('COMMIT');
    return serializeOperation(created, false);
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

function executeOperation(auth, operationType, payload, clientCreatedAt, operationUuid) {
  if (operationType !== 'reading.create') {
    return { status: 'received', conflictCode: null, response: { stage: 'Stage04', accepted: true } };
  }
  try {
    const reading = applyMeterReadingOperation(auth, payload, clientCreatedAt, operationUuid);
    return {
      status: 'applied',
      conflictCode: null,
      response: { stage: 'Stage04', accepted: true, reading }
    };
  } catch (error) {
    if (!error || !Number.isInteger(error.statusCode) || error.statusCode < 400 || error.statusCode >= 500) throw error;
    const status = isReadingConflictCode(error.code) ? 'conflict' : 'rejected';
    return {
      status,
      conflictCode: error.code || null,
      response: {
        stage: 'Stage04',
        accepted: false,
        error: {
          code: error.code || 'METER_READING_REJECTED',
          message: error.publicMessage || error.message || 'Meter reading was rejected.',
          details: error.details || null
        }
      }
    };
  }
}

function getGeneratorSyncStatus(auth) {
  const db = ensureGeneratorsSchema();
  const summary = db.prepare(`
    SELECT COUNT(*) AS received_count,
      SUM(CASE WHEN status = 'applied' THEN 1 ELSE 0 END) AS applied_count,
      SUM(CASE WHEN status = 'conflict' THEN 1 ELSE 0 END) AS conflict_count,
      SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS rejected_count,
      MAX(server_received_at) AS last_server_received_at
    FROM generator_sync_operations
    WHERE tenant_id = ? AND account_id = ?
  `).get(auth.tenantId, auth.accountId);
  return {
    server_time: new Date().toISOString(),
    received_count: Number(summary.received_count || 0),
    applied_count: Number(summary.applied_count || 0),
    conflict_count: Number(summary.conflict_count || 0),
    rejected_count: Number(summary.rejected_count || 0),
    last_server_received_at: summary.last_server_received_at || null,
    stage: 'Stage04',
    enabled_operation_types: Array.from(STAGE04_OPERATION_TYPES)
  };
}

function serializeOperation(row, duplicate) {
  return {
    operation_uuid: row.operation_uuid,
    operation_type: row.operation_type,
    status: row.status,
    conflict_code: row.conflict_code || null,
    duplicate,
    client_created_at: row.client_created_at,
    server_received_at: row.server_received_at,
    response: safeJson(row.response_json, {})
  };
}
function stableStringify(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  const keys = Object.keys(value).sort();
  return `{${keys.map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(',')}}`;
}
function safeJson(value, fallback) { try { return JSON.parse(value); } catch (_) { return fallback; } }

module.exports = { recordSyncOperation, getGeneratorSyncStatus, stableStringify };
