const { verifyPassword } = require('../../utils/password');
const { httpError } = require('../../utils/httpError');
const {
  findAccountByLogin,
  findAccountContext,
  createRefreshTokenRecord,
  findRefreshTokenRecord,
  rotateRefreshToken,
  revokeRefreshToken,
  writeAuditLog
} = require('./generators.db');
const {
  signGeneratorAccessToken,
  createRawRefreshToken,
  hashRefreshToken,
  refreshTokenExpiryIso
} = require('./generators.token');

function loginGeneratorAccount(body) {
  const login = typeof body?.login === 'string' ? body.login.trim() : '';
  const password = typeof body?.password === 'string' ? body.password : '';
  if (!login || !password) throw httpError(400, 'VALIDATION_ERROR', 'login and password are required.');

  const context = findAccountByLogin(login);
  if (!context || !verifyPassword(password, context.password_hash)) {
    throw httpError(401, 'INVALID_CREDENTIALS', 'Invalid login or password.');
  }
  assertMobileAccountAllowed(context);

  const session = issueSession(context);
  writeAuditLog({
    tenantId: context.tenant_id,
    actorAccountId: context.id,
    action: 'generator.auth.login',
    entityType: 'generator_account',
    entityUuid: context.public_id,
    after: { role: context.role }
  });
  return session;
}

function refreshGeneratorSession(body) {
  const refreshToken = typeof body?.refresh_token === 'string' ? body.refresh_token.trim() : '';
  if (!refreshToken) throw httpError(400, 'VALIDATION_ERROR', 'refresh_token is required.');

  const oldHash = hashRefreshToken(refreshToken);
  const record = findRefreshTokenRecord(oldHash);
  if (!record || record.revoked_at || Date.parse(record.expires_at) <= Date.now()) {
    throw httpError(401, 'INVALID_REFRESH_TOKEN', 'Refresh token is invalid, expired, or revoked.');
  }

  const context = findAccountContext(record.account_id);
  assertMobileAccountAllowed(context);
  const access = signGeneratorAccessToken(context);
  const newRefreshToken = createRawRefreshToken();
  const newExpiry = refreshTokenExpiryIso();
  rotateRefreshToken(oldHash, context.id, hashRefreshToken(newRefreshToken), newExpiry);

  writeAuditLog({
    tenantId: context.tenant_id,
    actorAccountId: context.id,
    action: 'generator.auth.refresh',
    entityType: 'generator_account',
    entityUuid: context.public_id
  });

  return serializeSession(context, access, newRefreshToken, newExpiry);
}

function logoutGeneratorSession(body) {
  const refreshToken = typeof body?.refresh_token === 'string' ? body.refresh_token.trim() : '';
  if (refreshToken) revokeRefreshToken(hashRefreshToken(refreshToken));
  return { logged_out: true };
}

function getCurrentGeneratorContext(accountId) {
  const context = findAccountContext(Number(accountId));
  assertMobileAccountAllowed(context);
  return serializeContext(context);
}

function issueSession(context) {
  const access = signGeneratorAccessToken(context);
  const rawRefreshToken = createRawRefreshToken();
  const refreshExpiresAt = refreshTokenExpiryIso();
  createRefreshTokenRecord(context.id, hashRefreshToken(rawRefreshToken), refreshExpiresAt);
  return serializeSession(context, access, rawRefreshToken, refreshExpiresAt);
}

function serializeSession(context, access, refreshToken, refreshExpiresAt) {
  return {
    access_token: access.token,
    token_type: 'Bearer',
    expires_in: access.expiresIn,
    refresh_token: refreshToken,
    refresh_expires_at: refreshExpiresAt,
    account: serializeContext(context).account,
    tenant: serializeContext(context).tenant,
    permissions: permissionsForRole(context.role)
  };
}

function serializeContext(context) {
  return {
    account: {
      id: context.public_id,
      full_name: context.full_name,
      username: context.username,
      phone: context.phone,
      role: context.role,
      status: context.status
    },
    tenant: context.tenant_id == null ? null : {
      id: context.tenant_public_id,
      name: context.tenant_name,
      phone: context.tenant_phone,
      status: context.tenant_status,
      subscription_starts_at: context.subscription_starts_at,
      subscription_expires_at: context.subscription_expires_at,
      collector_limit: Number(context.collector_limit || 0)
    },
    permissions: permissionsForRole(context.role)
  };
}

function assertMobileAccountAllowed(context) {
  if (!context) throw httpError(401, 'GENERATOR_ACCOUNT_NOT_FOUND', 'Generator account was not found.');
  if (!['owner', 'collector'].includes(context.role)) {
    throw httpError(403, 'GENERATOR_ROLE_NOT_ALLOWED', 'This account cannot use the generators mobile app.');
  }
  if (context.status !== 'active') {
    throw httpError(403, 'GENERATOR_ACCOUNT_INACTIVE', 'Generator account is not active.');
  }
  if (!context.tenant_id || context.tenant_status !== 'active') {
    throw httpError(403, 'GENERATOR_TENANT_INACTIVE', 'Generator organization is not active.');
  }
  if (context.subscription_expires_at && Date.parse(context.subscription_expires_at) <= Date.now()) {
    throw httpError(403, 'GENERATOR_SUBSCRIPTION_EXPIRED', 'Generator organization subscription has expired.');
  }
}

function permissionsForRole(role) {
  if (role === 'owner') {
    return [
      'dashboard.read', 'generators.manage', 'subscribers.manage', 'collectors.manage',
      'readings.manage', 'invoices.manage', 'collections.manage', 'expenses.manage',
      'maintenance.manage', 'reports.read', 'sync.audit.read'
    ];
  }
  if (role === 'collector') {
    return [
      'assignments.read', 'subscribers.assigned.read', 'readings.create',
      'collections.create', 'collections.own.read', 'sync.own.read'
    ];
  }
  return [];
}

module.exports = {
  loginGeneratorAccount,
  refreshGeneratorSession,
  logoutGeneratorSession,
  getCurrentGeneratorContext,
  assertMobileAccountAllowed,
  permissionsForRole
};
