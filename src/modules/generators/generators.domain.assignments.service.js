const { ensureGeneratorsSchema } = require('./generators.db');
const { ASSIGNMENT_TYPES } = require('./generators.domain.constants');
const { findGeneratorOrFail, findRouteOrFail, findSubscriberOrFail, listCatalogGenerators, listCatalogRoutes, listCatalogSubscribers, selectAssignedSubscribers, selectRoutesForGenerators, selectDomainRoutes, selectDomainGenerators, serializeGenerator, serializeRoute, serializeSubscriber } = require('./generators.domain.records');
const { assertOwner, assertCollector, normalizeEnum, cleanRequired, cleanOptional, parseObject, throwInactiveAssignmentTarget } = require('./generators.domain.validation');

function listOwnerAssignmentCatalog(auth, query = {}) {
  assertOwner(auth);
  const requestedType = query.type == null || query.type === '' ? null : normalizeEnum(query.type, 'type', ASSIGNMENT_TYPES);
  const q = cleanOptional(query.q, 120);
  const result = {};
  if (!requestedType || requestedType === 'generator') {
    result.generators = listCatalogGenerators(auth.tenantId, q);
  }
  if (!requestedType || requestedType === 'route') {
    result.routes = listCatalogRoutes(auth.tenantId, q);
  }
  if (!requestedType || requestedType === 'subscriber') {
    result.subscribers = listCatalogSubscribers(auth.tenantId, q);
  }
  return { type: requestedType, ...result };
}

function resolveAssignmentTarget(tenantId, type, targetPublicId, options = {}) {
  const normalizedType = normalizeEnum(type, 'assignment_type', ASSIGNMENT_TYPES);
  const targetId = cleanRequired(targetPublicId, 'target_id', 120);
  const requireActive = options.requireActive !== false;
  let target;
  if (normalizedType === 'generator') {
    target = serializeGenerator(findGeneratorOrFail(tenantId, targetId));
    if (requireActive && target.status !== 'active') throwInactiveAssignmentTarget(normalizedType);
    return {
      type: normalizedType,
      target_id: target.id,
      label: target.name,
      metadata: { code: target.code, area: target.area, status: target.status }
    };
  }
  if (normalizedType === 'route') {
    target = serializeRoute(findRouteOrFail(tenantId, targetId));
    if (requireActive && target.status !== 'active') throwInactiveAssignmentTarget(normalizedType);
    return {
      type: normalizedType,
      target_id: target.id,
      label: target.name,
      metadata: {
        code: target.code,
        area: target.area,
        status: target.status,
        generator_id: target.generator?.id || null,
        generator_name: target.generator?.name || null
      }
    };
  }
  target = serializeSubscriber(findSubscriberOrFail(tenantId, targetId));
  if (requireActive && target.status !== 'active') throwInactiveAssignmentTarget(normalizedType);
  return {
    type: normalizedType,
    target_id: target.id,
    label: target.full_name,
    metadata: {
      account_number: target.account_number,
      phone: target.phone,
      status: target.status,
      generator_id: target.generator.id,
      generator_name: target.generator.name,
      route_id: target.route?.id || null,
      route_name: target.route?.name || null
    }
  };
}

function listCollectorAssignedDomain(auth) {
  assertCollector(auth);
  const db = ensureGeneratorsSchema();
  const assignmentRows = db.prepare(`
    SELECT assignment_type, target_public_id, target_label, metadata_json, created_at, updated_at
    FROM generator_collector_assignments
    WHERE tenant_id = ? AND collector_account_id = ? AND status = 'active'
    ORDER BY assignment_type, target_label COLLATE NOCASE
  `).all(auth.tenantId, auth.accountId);

  const directGenerators = new Set();
  const directRoutes = new Set();
  const directSubscribers = new Set();
  for (const row of assignmentRows) {
    if (row.assignment_type === 'generator') directGenerators.add(row.target_public_id);
    if (row.assignment_type === 'route') directRoutes.add(row.target_public_id);
    if (row.assignment_type === 'subscriber') directSubscribers.add(row.target_public_id);
  }

  const subscribers = selectAssignedSubscribers(db, auth.tenantId, directSubscribers, directRoutes, directGenerators);
  const routeIds = new Set(directRoutes);
  for (const route of selectRoutesForGenerators(db, auth.tenantId, directGenerators)) {
    routeIds.add(route.public_id);
  }
  const generatorIds = new Set(directGenerators);
  for (const subscriber of subscribers) {
    if (subscriber.route_public_id) routeIds.add(subscriber.route_public_id);
    if (subscriber.generator_public_id) generatorIds.add(subscriber.generator_public_id);
  }
  const routes = selectDomainRoutes(db, auth.tenantId, routeIds);
  for (const route of routes) {
    if (route.generator_public_id) generatorIds.add(route.generator_public_id);
  }
  const generators = selectDomainGenerators(db, auth.tenantId, generatorIds);

  return {
    server_time: new Date().toISOString(),
    assignments: assignmentRows.map((row) => ({
      type: row.assignment_type,
      target_id: row.target_public_id,
      label: row.target_label,
      metadata: parseObject(row.metadata_json),
      created_at: row.created_at,
      updated_at: row.updated_at
    })),
    generators: generators.map(serializeGenerator),
    routes: routes.map(serializeRoute),
    subscribers: subscribers.map(serializeSubscriber),
    financial_workflows_enabled: false
  };
}

function getDomainSummary(tenantId) {
  const db = ensureGeneratorsSchema();
  const generators = db.prepare(`
    SELECT COUNT(*) AS total, SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) AS active
    FROM generator_units WHERE tenant_id = ?
  `).get(Number(tenantId));
  const routes = db.prepare(`
    SELECT COUNT(*) AS total, SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) AS active
    FROM generator_routes WHERE tenant_id = ?
  `).get(Number(tenantId));
  const subscribers = db.prepare(`
    SELECT COUNT(*) AS total, SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) AS active
    FROM generator_subscribers WHERE tenant_id = ?
  `).get(Number(tenantId));
  return {
    generators_total: Number(generators.total || 0),
    generators_active: Number(generators.active || 0),
    routes_total: Number(routes.total || 0),
    routes_active: Number(routes.active || 0),
    subscribers_total: Number(subscribers.total || 0),
    subscribers_active: Number(subscribers.active || 0)
  };
}

module.exports = {
  listOwnerAssignmentCatalog,
  resolveAssignmentTarget,
  listCollectorAssignedDomain,
  getDomainSummary,
};
