const crypto = require('node:crypto');
const { ensureGeneratorsSchema } = require('./generators.db');
const { getDomainSummary } = require('./generators.domain.assignments.service');
const { ROUTE_STATUSES } = require('./generators.domain.constants');
const { normalizeRouteInput, assertRouteGeneratorChangeSafe } = require('./generators.domain.inputs');
const { findRouteOrFail, findRouteById, serializeRoute } = require('./generators.domain.records');
const { addStatusFilter, addSearchFilter, auditEntity, assertOwner, normalizeEnum, cleanRequired, normalizeDomainWriteError } = require('./generators.domain.validation');

function listOwnerRoutes(auth, query = {}) {
  assertOwner(auth);
  const db = ensureGeneratorsSchema();
  const filters = ['r.tenant_id = ?'];
  const args = [auth.tenantId];
  addStatusFilter(filters, args, query.status, ROUTE_STATUSES, 'r.status');
  addSearchFilter(filters, args, query.q, ['r.code', 'r.name', 'r.area']);
  if (query.generator_id) {
    filters.push('g.public_id = ?');
    args.push(cleanRequired(query.generator_id, 'generator_id', 80));
  }
  const rows = db.prepare(`
    SELECT r.*, g.public_id AS generator_public_id, g.name AS generator_name,
      g.code AS generator_code, g.status AS generator_status,
      (SELECT COUNT(*) FROM generator_subscribers s WHERE s.tenant_id = r.tenant_id AND s.route_id = r.id) AS subscriber_count
    FROM generator_routes r
    LEFT JOIN generator_units g ON g.id = r.generator_unit_id AND g.tenant_id = r.tenant_id
    WHERE ${filters.join(' AND ')}
    ORDER BY CASE r.status WHEN 'active' THEN 0 ELSE 1 END, r.name COLLATE NOCASE
    LIMIT 500
  `).all(...args);
  return { routes: rows.map(serializeRoute), summary: getDomainSummary(auth.tenantId) };
}

function getOwnerRoute(auth, routePublicId) {
  assertOwner(auth);
  return serializeRoute(findRouteOrFail(auth.tenantId, routePublicId));
}

function createOwnerRoute(auth, body) {
  assertOwner(auth);
  const db = ensureGeneratorsSchema();
  const input = normalizeRouteInput(body, null, auth.tenantId);
  const publicId = crypto.randomUUID();
  try {
    const result = db.prepare(`
      INSERT INTO generator_routes (
        public_id, tenant_id, generator_unit_id, code, name, area, notes, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(publicId, auth.tenantId, input.generator_unit_id, input.code, input.name, input.area, input.notes, input.status);
    const created = findRouteById(auth.tenantId, Number(result.lastInsertRowid));
    auditEntity(auth, 'generator.domain.route_created', 'generator_route', publicId, null, serializeRoute(created));
    return serializeRoute(created);
  } catch (error) {
    throw normalizeDomainWriteError(error, 'GENERATOR_ROUTE_CODE_EXISTS', 'A route with this code already exists in this organization.');
  }
}

function updateOwnerRoute(auth, routePublicId, body) {
  assertOwner(auth);
  const current = findRouteOrFail(auth.tenantId, routePublicId);
  const input = normalizeRouteInput(body, current, auth.tenantId);
  assertRouteGeneratorChangeSafe(auth.tenantId, current.id, input.generator_unit_id);
  const db = ensureGeneratorsSchema();
  try {
    db.prepare(`
      UPDATE generator_routes
      SET generator_unit_id = ?, code = ?, name = ?, area = ?, notes = ?
      WHERE id = ? AND tenant_id = ?
    `).run(input.generator_unit_id, input.code, input.name, input.area, input.notes, current.id, auth.tenantId);
  } catch (error) {
    throw normalizeDomainWriteError(error, 'GENERATOR_ROUTE_CODE_EXISTS', 'A route with this code already exists in this organization.');
  }
  const updated = findRouteById(auth.tenantId, current.id);
  auditEntity(auth, 'generator.domain.route_updated', 'generator_route', current.public_id, serializeRoute(current), serializeRoute(updated));
  return serializeRoute(updated);
}

function updateOwnerRouteStatus(auth, routePublicId, body) {
  assertOwner(auth);
  const current = findRouteOrFail(auth.tenantId, routePublicId);
  const status = normalizeEnum(body?.status, 'status', ROUTE_STATUSES, current.status);
  const db = ensureGeneratorsSchema();
  db.prepare('UPDATE generator_routes SET status = ? WHERE id = ? AND tenant_id = ?')
    .run(status, current.id, auth.tenantId);
  const updated = findRouteById(auth.tenantId, current.id);
  auditEntity(auth, 'generator.domain.route_status_updated', 'generator_route', current.public_id, { status: current.status }, { status });
  return serializeRoute(updated);
}

module.exports = {
  listOwnerRoutes,
  getOwnerRoute,
  createOwnerRoute,
  updateOwnerRoute,
  updateOwnerRouteStatus,
};
