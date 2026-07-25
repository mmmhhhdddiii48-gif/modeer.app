const { httpError } = require('../../utils/httpError');
const { writeAuditLog } = require('./generators.db');

function addStatusFilter(filters, args, rawStatus, allowed, column) {
  if (rawStatus == null || String(rawStatus).trim() === '') return;
  filters.push(`${column} = ?`);
  args.push(normalizeEnum(rawStatus, 'status', allowed));
}

function addSearchFilter(filters, args, rawQuery, columns) {
  const q = cleanOptional(rawQuery, 120);
  if (!q) return;
  filters.push(`(${columns.map((column) => `${column} LIKE ?`).join(' OR ')})`);
  for (let index = 0; index < columns.length; index += 1) args.push(`%${q}%`);
}

function auditEntity(auth, action, entityType, entityUuid, before, after) {
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action,
    entityType,
    entityUuid,
    before,
    after
  });
}

function assertOwner(auth) {
  if (!auth || auth.role !== 'owner' || !auth.tenantId || !auth.accountId) {
    throw httpError(403, 'GENERATOR_PERMISSION_DENIED', 'Owner account is required.');
  }
}

function assertCollector(auth) {
  if (!auth || auth.role !== 'collector' || !auth.tenantId || !auth.accountId) {
    throw httpError(403, 'GENERATOR_PERMISSION_DENIED', 'Collector account is required.');
  }
}

function normalizeCode(value, field) {
  const normalized = cleanRequired(value, field, 80);
  if (!/^[\p{L}\p{N}._\-/]+$/u.test(normalized)) {
    throw httpError(400, 'INVALID_DOMAIN_CODE', `${field} contains unsupported characters.`);
  }
  return normalized;
}

function normalizeEnum(value, field, allowed, fallback) {
  const normalized = value == null || String(value).trim() === '' ? fallback : String(value).trim();
  if (!allowed.includes(normalized)) {
    throw httpError(400, 'INVALID_DOMAIN_VALUE', `${field} must be one of: ${allowed.join(', ')}.`);
  }
  return normalized;
}

function nullableNumber(value, field) {
  if (value == null || value === '') return null;
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0) throw httpError(400, 'INVALID_DOMAIN_NUMBER', `${field} must be zero or greater.`);
  return number;
}

function nonNegativeInteger(value, field) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < 0) throw httpError(400, 'INVALID_DOMAIN_NUMBER', `${field} must be a non-negative integer.`);
  return number;
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

function placeholders(count) {
  return Array.from({ length: count }, () => '?').join(', ');
}

function parseObject(value) {
  try {
    const parsed = JSON.parse(value || '{}');
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch (_) {
    return {};
  }
}

function throwInactiveAssignmentTarget(type) {
  throw httpError(409, 'GENERATOR_ASSIGNMENT_TARGET_INACTIVE', `The selected ${type} is not active and cannot be assigned.`);
}

function normalizeDomainWriteError(error, code, message) {
  if (error?.code === 'SQLITE_CONSTRAINT_UNIQUE' || /UNIQUE constraint failed/i.test(String(error?.message || ''))) {
    return httpError(409, code, message);
  }
  return error;
}

function normalizeSubscriberWriteError(error) {
  if (error?.code === 'SQLITE_CONSTRAINT_UNIQUE' || /UNIQUE constraint failed/i.test(String(error?.message || ''))) {
    const message = String(error?.message || '');
    if (/meter_number/i.test(message)) {
      return httpError(409, 'GENERATOR_METER_NUMBER_EXISTS', 'This meter number already belongs to another subscriber in this organization.');
    }
    return httpError(409, 'GENERATOR_SUBSCRIBER_ACCOUNT_EXISTS', 'A subscriber with this account number already exists in this organization.');
  }
  return error;
}

module.exports = {
  addStatusFilter,
  addSearchFilter,
  auditEntity,
  assertOwner,
  assertCollector,
  normalizeCode,
  normalizeEnum,
  nullableNumber,
  nonNegativeInteger,
  cleanRequired,
  cleanOptional,
  placeholders,
  parseObject,
  throwInactiveAssignmentTarget,
  normalizeDomainWriteError,
  normalizeSubscriberWriteError,
};
