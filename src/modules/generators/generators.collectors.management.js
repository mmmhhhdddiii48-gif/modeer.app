const crypto = require('node:crypto');
const { hashPassword } = require('../../utils/password');
const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema, revokeAllRefreshTokensForAccount, writeAuditLog } = require('./generators.db');
const { DEFAULT_COLLECTOR_PERMISSIONS } = require('./generators.collectors.constants');
const { findOwnedCollectorOrFail, findOwnedCollectorById, getCollectorUsage, assertCollectorSlotAvailable, assertLoginFieldsAvailable, serializeCollector, normalizePermissions, parsePermissions, normalizeUsername, validatePassword, cleanRequired, cleanOptional, assertOwner, normalizeAccountWriteError } = require('./generators.collectors.records');

function listOwnerCollectors(auth) {
  assertOwner(auth);
  const db = ensureGeneratorsSchema();
  const rows = db.prepare(`
    SELECT a.*,
      (SELECT MAX(s.server_received_at)
       FROM generator_sync_operations s
       WHERE s.account_id = a.id) AS last_server_sync_at,
      (SELECT COUNT(*)
       FROM generator_collector_assignments ca
       WHERE ca.collector_account_id = a.id AND ca.status = 'active') AS assignment_count
    FROM generator_accounts a
    WHERE a.tenant_id = ? AND a.role = 'collector'
    ORDER BY CASE a.status WHEN 'active' THEN 0 WHEN 'suspended' THEN 1 ELSE 2 END,
      a.full_name COLLATE NOCASE
  `).all(auth.tenantId);
  return {
    collectors: rows.map(serializeCollector),
    usage: getCollectorUsage(auth.tenantId)
  };
}

function getOwnerCollector(auth, collectorPublicId) {
  assertOwner(auth);
  return serializeCollector(findOwnedCollectorOrFail(auth.tenantId, collectorPublicId));
}

function createOwnerCollector(auth, body) {
  assertOwner(auth);
  const fullName = cleanRequired(body?.full_name, 'full_name', 120);
  const username = normalizeUsername(body?.username);
  const phone = cleanOptional(body?.phone, 40);
  const password = validatePassword(body?.password);
  const permissions = normalizePermissions(body?.permissions, DEFAULT_COLLECTOR_PERMISSIONS);
  const db = ensureGeneratorsSchema();

  assertCollectorSlotAvailable(auth.tenantId);
  assertLoginFieldsAvailable({ username, phone });

  const publicId = crypto.randomUUID();
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = db.prepare(`
      INSERT INTO generator_accounts (
        public_id, tenant_id, role, username, phone, full_name,
        password_hash, status, permissions_json
      ) VALUES (?, ?, 'collector', ?, ?, ?, ?, 'active', ?)
    `).run(
      publicId,
      auth.tenantId,
      username,
      phone,
      fullName,
      hashPassword(password),
      JSON.stringify(permissions)
    );
    const accountId = Number(result.lastInsertRowid);
    writeAuditLog({
      tenantId: auth.tenantId,
      actorAccountId: auth.accountId,
      action: 'generator.collector.created',
      entityType: 'generator_account',
      entityUuid: publicId,
      after: { full_name: fullName, username, phone, status: 'active', permissions }
    });
    db.exec('COMMIT');
    return {
      collector: serializeCollector(findOwnedCollectorById(auth.tenantId, accountId)),
      usage: getCollectorUsage(auth.tenantId)
    };
  } catch (error) {
    db.exec('ROLLBACK');
    throw normalizeAccountWriteError(error);
  }
}

function updateOwnerCollector(auth, collectorPublicId, body) {
  assertOwner(auth);
  const current = findOwnedCollectorOrFail(auth.tenantId, collectorPublicId);
  const fullName = body?.full_name === undefined ? current.full_name : cleanRequired(body.full_name, 'full_name', 120);
  const username = body?.username === undefined ? current.username : normalizeUsername(body.username);
  const phone = body?.phone === undefined ? current.phone : cleanOptional(body.phone, 40);
  assertLoginFieldsAvailable({ username, phone, excludeAccountId: current.id });

  const db = ensureGeneratorsSchema();
  try {
    db.prepare(`
      UPDATE generator_accounts
      SET full_name = ?, username = ?, phone = ?
      WHERE id = ? AND tenant_id = ? AND role = 'collector'
    `).run(fullName, username, phone, current.id, auth.tenantId);
  } catch (error) {
    throw normalizeAccountWriteError(error);
  }

  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.collector.profile_updated',
    entityType: 'generator_account',
    entityUuid: current.public_id,
    before: { full_name: current.full_name, username: current.username, phone: current.phone },
    after: { full_name: fullName, username, phone }
  });
  return serializeCollector(findOwnedCollectorById(auth.tenantId, current.id));
}

function updateOwnerCollectorStatus(auth, collectorPublicId, body) {
  assertOwner(auth);
  const current = findOwnedCollectorOrFail(auth.tenantId, collectorPublicId);
  const status = String(body?.status || '').trim();
  if (!['active', 'suspended', 'disabled'].includes(status)) {
    throw httpError(400, 'INVALID_COLLECTOR_STATUS', 'status must be active, suspended, or disabled.');
  }
  if (current.status === 'disabled' && status !== 'disabled') {
    assertCollectorSlotAvailable(auth.tenantId);
  }

  const db = ensureGeneratorsSchema();
  db.prepare(`
    UPDATE generator_accounts SET status = ?
    WHERE id = ? AND tenant_id = ? AND role = 'collector'
  `).run(status, current.id, auth.tenantId);

  if (status !== 'active') revokeAllRefreshTokensForAccount(current.id);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.collector.status_updated',
    entityType: 'generator_account',
    entityUuid: current.public_id,
    before: { status: current.status },
    after: { status }
  });
  return {
    collector: serializeCollector(findOwnedCollectorById(auth.tenantId, current.id)),
    usage: getCollectorUsage(auth.tenantId)
  };
}

function updateOwnerCollectorPermissions(auth, collectorPublicId, body) {
  assertOwner(auth);
  const current = findOwnedCollectorOrFail(auth.tenantId, collectorPublicId);
  const permissions = normalizePermissions(body?.permissions, []);
  const db = ensureGeneratorsSchema();
  db.prepare(`
    UPDATE generator_accounts SET permissions_json = ?
    WHERE id = ? AND tenant_id = ? AND role = 'collector'
  `).run(JSON.stringify(permissions), current.id, auth.tenantId);

  revokeAllRefreshTokensForAccount(current.id);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.collector.permissions_updated',
    entityType: 'generator_account',
    entityUuid: current.public_id,
    before: { permissions: parsePermissions(current.permissions_json) },
    after: { permissions }
  });
  return serializeCollector(findOwnedCollectorById(auth.tenantId, current.id));
}

function resetOwnerCollectorPassword(auth, collectorPublicId, body) {
  assertOwner(auth);
  const current = findOwnedCollectorOrFail(auth.tenantId, collectorPublicId);
  const password = validatePassword(body?.new_password);
  const db = ensureGeneratorsSchema();
  db.prepare(`
    UPDATE generator_accounts SET password_hash = ?
    WHERE id = ? AND tenant_id = ? AND role = 'collector'
  `).run(hashPassword(password), current.id, auth.tenantId);
  revokeAllRefreshTokensForAccount(current.id);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.collector.password_reset',
    entityType: 'generator_account',
    entityUuid: current.public_id
  });
  return { password_reset: true, collector_id: current.public_id };
}

module.exports = {
  listOwnerCollectors,
  getOwnerCollector,
  createOwnerCollector,
  updateOwnerCollector,
  updateOwnerCollectorStatus,
  updateOwnerCollectorPermissions,
  resetOwnerCollectorPassword,
};
