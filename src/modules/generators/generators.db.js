const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { getDatabase } = require('../../db');
const { hashPassword } = require('../../utils/password');
const { httpError } = require('../../utils/httpError');

const SCHEMA_FILE = path.join(__dirname, 'generators.schema.sql');
const initializedDatabases = new WeakSet();

function ensureGeneratorsSchema(db = getDatabase()) {
  if (!initializedDatabases.has(db)) {
    db.exec(fs.readFileSync(SCHEMA_FILE, 'utf8'));
    initializedDatabases.add(db);
  }
  return db;
}

function findAccountByLogin(login) {
  const db = ensureGeneratorsSchema();
  return db.prepare(`
    SELECT a.*, t.public_id AS tenant_public_id, t.name AS tenant_name,
      t.phone AS tenant_phone, t.status AS tenant_status,
      t.subscription_starts_at, t.subscription_expires_at, t.collector_limit
    FROM generator_accounts a
    LEFT JOIN generator_tenants t ON t.id = a.tenant_id
    WHERE a.username = ? COLLATE NOCASE OR a.phone = ?
    LIMIT 1
  `).get(login, login) || null;
}

function findAccountContext(accountId) {
  const db = ensureGeneratorsSchema();
  return db.prepare(`
    SELECT a.*, t.public_id AS tenant_public_id, t.name AS tenant_name,
      t.phone AS tenant_phone, t.status AS tenant_status,
      t.subscription_starts_at, t.subscription_expires_at, t.collector_limit
    FROM generator_accounts a
    LEFT JOIN generator_tenants t ON t.id = a.tenant_id
    WHERE a.id = ?
    LIMIT 1
  `).get(Number(accountId)) || null;
}

function createRefreshTokenRecord(accountId, tokenHash, expiresAt) {
  const db = ensureGeneratorsSchema();
  const result = db.prepare(`
    INSERT INTO generator_refresh_tokens (account_id, token_hash, expires_at)
    VALUES (?, ?, ?)
  `).run(Number(accountId), tokenHash, expiresAt);
  return Number(result.lastInsertRowid);
}

function findRefreshTokenRecord(tokenHash) {
  const db = ensureGeneratorsSchema();
  return db.prepare(`
    SELECT rt.*, a.tenant_id, a.role, a.status AS account_status
    FROM generator_refresh_tokens rt
    JOIN generator_accounts a ON a.id = rt.account_id
    WHERE rt.token_hash = ?
    LIMIT 1
  `).get(tokenHash) || null;
}

function rotateRefreshToken(oldTokenHash, accountId, newTokenHash, newExpiresAt) {
  const db = ensureGeneratorsSchema();
  db.exec('BEGIN IMMEDIATE');
  try {
    const current = db.prepare(`
      SELECT id, revoked_at, expires_at FROM generator_refresh_tokens
      WHERE token_hash = ? AND account_id = ? LIMIT 1
    `).get(oldTokenHash, Number(accountId));
    if (!current || current.revoked_at) {
      throw httpError(401, 'INVALID_REFRESH_TOKEN', 'Refresh token is invalid or revoked.');
    }
    db.prepare(`
      UPDATE generator_refresh_tokens
      SET revoked_at = datetime('now'), last_used_at = datetime('now')
      WHERE id = ?
    `).run(current.id);
    createRefreshTokenRecord(accountId, newTokenHash, newExpiresAt);
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

function revokeRefreshToken(tokenHash) {
  const db = ensureGeneratorsSchema();
  db.prepare(`
    UPDATE generator_refresh_tokens
    SET revoked_at = COALESCE(revoked_at, datetime('now')), last_used_at = datetime('now')
    WHERE token_hash = ?
  `).run(tokenHash);
}

function revokeAllRefreshTokensForAccount(accountId) {
  const db = ensureGeneratorsSchema();
  db.prepare(`
    UPDATE generator_refresh_tokens
    SET revoked_at = COALESCE(revoked_at, datetime('now'))
    WHERE account_id = ?
  `).run(Number(accountId));
}

function writeAuditLog({ tenantId = null, actorAccountId = null, action, entityType, entityUuid = null, before = null, after = null, clientCreatedAt = null }) {
  const db = ensureGeneratorsSchema();
  db.prepare(`
    INSERT INTO generator_audit_logs (
      tenant_id, actor_account_id, action, entity_type, entity_uuid,
      before_json, after_json, client_created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    tenantId == null ? null : Number(tenantId),
    actorAccountId == null ? null : Number(actorAccountId),
    action,
    entityType,
    entityUuid,
    before == null ? null : JSON.stringify(before),
    after == null ? null : JSON.stringify(after),
    clientCreatedAt || null
  );
}

function provisionTenantOwnerForStage01(input) {
  const name = cleanRequired(input?.tenantName, 'tenantName');
  const username = cleanRequired(input?.username, 'username');
  const password = cleanRequired(input?.password, 'password');
  const fullName = cleanRequired(input?.fullName || name, 'fullName');
  const collectorLimit = Number.isInteger(Number(input?.collectorLimit)) ? Number(input.collectorLimit) : 1;
  if (collectorLimit < 0) throw httpError(400, 'INVALID_COLLECTOR_LIMIT', 'collectorLimit must be zero or greater.');

  const db = ensureGeneratorsSchema();
  const existing = findAccountByLogin(username);
  if (existing) throw httpError(409, 'GENERATOR_ACCOUNT_EXISTS', 'A generator account already uses this username or phone.');

  const tenantPublicId = crypto.randomUUID();
  const accountPublicId = crypto.randomUUID();
  db.exec('BEGIN IMMEDIATE');
  try {
    const tenantResult = db.prepare(`
      INSERT INTO generator_tenants (
        public_id, name, phone, status, subscription_starts_at,
        subscription_expires_at, collector_limit
      ) VALUES (?, ?, ?, 'active', ?, ?, ?)
    `).run(
      tenantPublicId,
      name,
      cleanOptional(input?.phone),
      cleanOptional(input?.subscriptionStartsAt),
      cleanOptional(input?.subscriptionExpiresAt),
      collectorLimit
    );
    const tenantId = Number(tenantResult.lastInsertRowid);
    const accountResult = db.prepare(`
      INSERT INTO generator_accounts (
        public_id, tenant_id, role, username, phone, full_name,
        password_hash, status, permissions_json
      ) VALUES (?, ?, 'owner', ?, ?, ?, ?, 'active', ?)
    `).run(
      accountPublicId,
      tenantId,
      username,
      cleanOptional(input?.phone),
      fullName,
      hashPassword(password),
      JSON.stringify(['owner.*'])
    );
    const accountId = Number(accountResult.lastInsertRowid);
    writeAuditLog({
      tenantId,
      actorAccountId: accountId,
      action: 'generator.stage01.owner_provisioned',
      entityType: 'generator_account',
      entityUuid: accountPublicId,
      after: { role: 'owner', username, tenant_public_id: tenantPublicId }
    });
    db.exec('COMMIT');
    return findAccountContext(accountId);
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

function cleanRequired(value, field) {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) throw httpError(400, 'VALIDATION_ERROR', `${field} is required.`);
  return normalized;
}
function cleanOptional(value) {
  if (value == null) return null;
  const normalized = String(value).trim();
  return normalized || null;
}

module.exports = {
  ensureGeneratorsSchema,
  findAccountByLogin,
  findAccountContext,
  createRefreshTokenRecord,
  findRefreshTokenRecord,
  rotateRefreshToken,
  revokeRefreshToken,
  revokeAllRefreshTokensForAccount,
  writeAuditLog,
  provisionTenantOwnerForStage01
};
