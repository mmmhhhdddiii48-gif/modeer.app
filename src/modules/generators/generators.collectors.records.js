const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema } = require('./generators.db');
const { COLLECTOR_PERMISSION_ALLOWLIST, ASSIGNMENT_TYPES } = require('./generators.collectors.constants');
const { resolveAssignmentTarget } = require('./generators.domain.service');

function listAssignmentsForCollector(tenantId, collectorAccountId) {
  const db = ensureGeneratorsSchema();
  return db.prepare(`
    SELECT public_id, assignment_type, target_public_id, target_label,
      metadata_json, status, created_at, updated_at
    FROM generator_collector_assignments
    WHERE tenant_id = ? AND collector_account_id = ? AND status = 'active'
    ORDER BY assignment_type, target_label COLLATE NOCASE, target_public_id
  `).all(Number(tenantId), Number(collectorAccountId)).map((row) => ({
    id: row.public_id,
    type: row.assignment_type,
    target_id: row.target_public_id,
    label: row.target_label,
    metadata: parseObject(row.metadata_json),
    status: row.status,
    created_at: row.created_at,
    updated_at: row.updated_at
  }));
}

function findOwnedCollectorOrFail(tenantId, collectorPublicId) {
  const normalizedId = cleanRequired(collectorPublicId, 'collector_id', 80);
  const db = ensureGeneratorsSchema();
  const row = db.prepare(`
    SELECT a.*,
      (SELECT MAX(s.server_received_at) FROM generator_sync_operations s WHERE s.account_id = a.id) AS last_server_sync_at,
      (SELECT COUNT(*) FROM generator_collector_assignments ca WHERE ca.collector_account_id = a.id AND ca.status = 'active') AS assignment_count
    FROM generator_accounts a
    WHERE a.tenant_id = ? AND a.role = 'collector' AND a.public_id = ?
    LIMIT 1
  `).get(Number(tenantId), normalizedId);
  if (!row) throw httpError(404, 'GENERATOR_COLLECTOR_NOT_FOUND', 'Collector was not found in this organization.');
  return row;
}

function findOwnedCollectorById(tenantId, collectorId) {
  const db = ensureGeneratorsSchema();
  return db.prepare(`
    SELECT a.*,
      (SELECT MAX(s.server_received_at) FROM generator_sync_operations s WHERE s.account_id = a.id) AS last_server_sync_at,
      (SELECT COUNT(*) FROM generator_collector_assignments ca WHERE ca.collector_account_id = a.id AND ca.status = 'active') AS assignment_count
    FROM generator_accounts a
    WHERE a.tenant_id = ? AND a.role = 'collector' AND a.id = ?
    LIMIT 1
  `).get(Number(tenantId), Number(collectorId));
}

function getCollectorUsage(tenantId) {
  const db = ensureGeneratorsSchema();
  const tenant = db.prepare('SELECT collector_limit FROM generator_tenants WHERE id = ? LIMIT 1').get(Number(tenantId));
  if (!tenant) throw httpError(404, 'GENERATOR_TENANT_NOT_FOUND', 'Generator organization was not found.');
  const row = db.prepare(`
    SELECT
      COUNT(*) AS total_accounts,
      SUM(CASE WHEN status != 'disabled' THEN 1 ELSE 0 END) AS used_slots,
      SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) AS active_count,
      SUM(CASE WHEN status = 'suspended' THEN 1 ELSE 0 END) AS suspended_count,
      SUM(CASE WHEN status = 'disabled' THEN 1 ELSE 0 END) AS disabled_count
    FROM generator_accounts
    WHERE tenant_id = ? AND role = 'collector'
  `).get(Number(tenantId));
  const limit = Number(tenant.collector_limit || 0);
  const used = Number(row.used_slots || 0);
  return {
    limit,
    used_slots: used,
    remaining_slots: Math.max(0, limit - used),
    total_accounts: Number(row.total_accounts || 0),
    active_count: Number(row.active_count || 0),
    suspended_count: Number(row.suspended_count || 0),
    disabled_count: Number(row.disabled_count || 0)
  };
}

function assertCollectorSlotAvailable(tenantId) {
  const usage = getCollectorUsage(tenantId);
  if (usage.used_slots >= usage.limit) {
    throw httpError(409, 'GENERATOR_COLLECTOR_LIMIT_REACHED', 'The collector limit for this subscription has been reached.', usage);
  }
}

function assertLoginFieldsAvailable({ username, phone, excludeAccountId = null }) {
  const db = ensureGeneratorsSchema();
  const row = db.prepare(`
    SELECT id FROM generator_accounts
    WHERE (
      username = ? COLLATE NOCASE
      OR phone = ?
      OR (? IS NOT NULL AND (username = ? COLLATE NOCASE OR phone = ?))
    )
      AND (? IS NULL OR id != ?)
    LIMIT 1
  `).get(
    username,
    username,
    phone,
    phone,
    phone,
    excludeAccountId,
    excludeAccountId
  );
  if (row) throw httpError(409, 'GENERATOR_ACCOUNT_EXISTS', 'A generator account already uses this username or phone.');
}

function serializeCollector(row) {
  return {
    id: row.public_id,
    full_name: row.full_name,
    username: row.username,
    phone: row.phone,
    status: row.status,
    permissions: parsePermissions(row.permissions_json),
    assignment_count: Number(row.assignment_count || 0),
    last_server_sync_at: row.last_server_sync_at || null,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function normalizePermissions(value, fallback) {
  const source = value === undefined ? fallback : value;
  if (!Array.isArray(source)) throw httpError(400, 'INVALID_COLLECTOR_PERMISSIONS', 'permissions must be an array.');
  const normalized = [...new Set(source.map((item) => String(item || '').trim()).filter(Boolean))];
  const denied = normalized.filter((permission) => !COLLECTOR_PERMISSION_ALLOWLIST.includes(permission));
  if (denied.length) {
    throw httpError(400, 'INVALID_COLLECTOR_PERMISSION', 'One or more collector permissions are not allowed.', { denied });
  }
  return normalized;
}

function normalizeAssignments(value, tenantId) {
  if (!Array.isArray(value)) throw httpError(400, 'INVALID_ASSIGNMENTS', 'assignments must be an array.');
  if (value.length > 500) throw httpError(400, 'ASSIGNMENT_LIMIT_EXCEEDED', 'A maximum of 500 assignments can be submitted at once.');
  const seen = new Set();
  return value.map((item, index) => {
    const type = String(item?.type || '').trim();
    if (!ASSIGNMENT_TYPES.has(type)) {
      throw httpError(400, 'INVALID_ASSIGNMENT_TYPE', `assignments[${index}].type is invalid.`);
    }
    const targetId = cleanRequired(item?.target_id, `assignments[${index}].target_id`, 120);
    const key = `${type}:${targetId}`;
    if (seen.has(key)) throw httpError(400, 'DUPLICATE_ASSIGNMENT', `Duplicate assignment ${key}.`);
    seen.add(key);

    // Stage03 resolves the target from the server database. The client cannot
    // forge labels, metadata, another tenant, or an unknown public ID.
    return resolveAssignmentTarget(tenantId, type, targetId, { requireActive: true });
  });
}

function parsePermissions(value) {
  try {
    const parsed = JSON.parse(value || '[]');
    return Array.isArray(parsed) ? parsed.filter((item) => typeof item === 'string') : [];
  } catch (_) {
    return [];
  }
}

function parseObject(value) {
  try {
    const parsed = JSON.parse(value || '{}');
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch (_) {
    return {};
  }
}

function normalizeUsername(value) {
  const username = cleanRequired(value, 'username', 80);
  if (!/^[A-Za-z0-9._@+-]+$/.test(username)) {
    throw httpError(400, 'INVALID_USERNAME', 'username contains unsupported characters.');
  }
  return username;
}

function validatePassword(value) {
  const password = typeof value === 'string' ? value : '';
  if (password.length < 8 || password.length > 128) {
    throw httpError(400, 'INVALID_PASSWORD', 'password must be between 8 and 128 characters.');
  }
  return password;
}

function cleanRequired(value, field, maxLength) {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) throw httpError(400, 'VALIDATION_ERROR', `${field} is required.`);
  if (maxLength && normalized.length > maxLength) throw httpError(400, 'VALIDATION_ERROR', `${field} is too long.`);
  return normalized;
}

function cleanOptional(value, maxLength) {
  if (value == null) return null;
  const normalized = String(value).trim();
  if (!normalized) return null;
  if (maxLength && normalized.length > maxLength) throw httpError(400, 'VALIDATION_ERROR', 'Value is too long.');
  return normalized;
}

function assertOwner(auth) {
  if (!auth || auth.role !== 'owner' || !auth.tenantId || !auth.accountId) {
    throw httpError(403, 'GENERATOR_PERMISSION_DENIED', 'Owner account is required.');
  }
}

function normalizeAccountWriteError(error) {
  if (error?.code === 'SQLITE_CONSTRAINT_UNIQUE' || /UNIQUE constraint failed/i.test(String(error?.message || ''))) {
    return httpError(409, 'GENERATOR_ACCOUNT_EXISTS', 'A generator account already uses this username or phone.');
  }
  return error;
}

module.exports = {
  listAssignmentsForCollector,
  findOwnedCollectorOrFail,
  findOwnedCollectorById,
  getCollectorUsage,
  assertCollectorSlotAvailable,
  assertLoginFieldsAvailable,
  serializeCollector,
  normalizePermissions,
  normalizeAssignments,
  parsePermissions,
  parseObject,
  normalizeUsername,
  validatePassword,
  cleanRequired,
  cleanOptional,
  assertOwner,
  normalizeAccountWriteError,
};
