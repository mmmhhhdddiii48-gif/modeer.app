const { httpError } = require('../../utils/httpError');
const { readBearerToken, verifyGeneratorAccessToken } = require('./generators.token');
const { findAccountContext } = require('./generators.db');
const { assertMobileAccountAllowed, permissionsForContext } = require('./generators.auth.service');

function requireGeneratorAuth(req, _res, next) {
  try {
    const claims = verifyGeneratorAccessToken(readBearerToken(req));
    const context = findAccountContext(Number(claims.sub));
    assertMobileAccountAllowed(context);

    if (String(context.tenant_id) !== String(claims.tid) || context.role !== claims.role) {
      throw httpError(401, 'GENERATOR_TOKEN_CONTEXT_CHANGED', 'Generator account context has changed. Please sign in again.');
    }

    req.generatorAuth = {
      accountId: Number(context.id),
      accountPublicId: context.public_id,
      tenantId: Number(context.tenant_id),
      tenantPublicId: context.tenant_public_id,
      role: context.role,
      permissions: permissionsForContext(context)
    };
    next();
  } catch (error) {
    next(error);
  }
}

function requireGeneratorRole(...roles) {
  return function generatorRoleGuard(req, _res, next) {
    if (!req.generatorAuth || !roles.includes(req.generatorAuth.role)) {
      return next(httpError(403, 'GENERATOR_PERMISSION_DENIED', 'You do not have permission for this generator action.'));
    }
    return next();
  };
}

function requireGeneratorPermission(permission) {
  return function generatorPermissionGuard(req, _res, next) {
    const permissions = Array.isArray(req.generatorAuth?.permissions) ? req.generatorAuth.permissions : [];
    if (!permissions.includes(permission)) {
      return next(httpError(403, 'GENERATOR_PERMISSION_DENIED', 'You do not have permission for this generator action.'));
    }
    return next();
  };
}

module.exports = { requireGeneratorAuth, requireGeneratorRole, requireGeneratorPermission };
