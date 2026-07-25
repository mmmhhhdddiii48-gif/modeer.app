const express = require('express');
const { asyncHandler } = require('../../utils/asyncHandler');
const {
  loginGeneratorAccount,
  refreshGeneratorSession,
  logoutGeneratorSession,
  getCurrentGeneratorContext
} = require('./generators.auth.service');
const {
  requireGeneratorAuth,
  requireGeneratorRole,
  requireGeneratorPermission
} = require('./generators.auth.middleware');
const { recordSyncOperation, getGeneratorSyncStatus } = require('./generators.sync.service');
const { ensureGeneratorsSchema } = require('./generators.db');
const {
  COLLECTOR_PERMISSION_ALLOWLIST,
  listOwnerCollectors,
  getOwnerCollector,
  createOwnerCollector,
  updateOwnerCollector,
  updateOwnerCollectorStatus,
  updateOwnerCollectorPermissions,
  resetOwnerCollectorPassword,
  listOwnerCollectorAssignments,
  replaceOwnerCollectorAssignments,
  listCollectorOwnAssignments
} = require('./generators.collectors.service');
const {
  listOwnerGenerators,
  getOwnerGenerator,
  createOwnerGenerator,
  updateOwnerGenerator,
  updateOwnerGeneratorStatus,
  listOwnerRoutes,
  getOwnerRoute,
  createOwnerRoute,
  updateOwnerRoute,
  updateOwnerRouteStatus,
  listOwnerSubscribers,
  getOwnerSubscriber,
  createOwnerSubscriber,
  updateOwnerSubscriber,
  updateOwnerSubscriberStatus,
  listOwnerAssignmentCatalog,
  listCollectorAssignedDomain
} = require('./generators.domain.service');

const generatorsRouter = express.Router();
const ownerOnly = [requireGeneratorRole('owner')];
const collectorOnly = [requireGeneratorRole('collector')];

function ownerPermission(permission) {
  return [...ownerOnly, requireGeneratorPermission(permission)];
}

function collectorPermissions(...permissions) {
  return [
    ...collectorOnly,
    ...permissions.map((permission) => requireGeneratorPermission(permission))
  ];
}

generatorsRouter.get('/health', (_req, res) => {
  ensureGeneratorsSchema();
  res.json({ ok: true, data: { module: 'generators', stage: 'Stage03', status: 'ready' } });
});

generatorsRouter.post('/auth/login', asyncHandler((req, res) => {
  res.status(200).json({ ok: true, data: loginGeneratorAccount(req.body || {}) });
}));

generatorsRouter.post('/auth/refresh', asyncHandler((req, res) => {
  res.status(200).json({ ok: true, data: refreshGeneratorSession(req.body || {}) });
}));

generatorsRouter.post('/auth/logout', asyncHandler((req, res) => {
  res.status(200).json({ ok: true, data: logoutGeneratorSession(req.body || {}) });
}));

generatorsRouter.use(requireGeneratorAuth);

generatorsRouter.get('/auth/me', asyncHandler((req, res) => {
  res.json({ ok: true, data: getCurrentGeneratorContext(req.generatorAuth.accountId) });
}));

generatorsRouter.get('/owner/foundation', ...ownerOnly, (req, res) => {
  res.json({
    ok: true,
    data: {
      role: 'owner',
      tenant_id: req.generatorAuth.tenantPublicId,
      stage: 'Stage03',
      modules: ['dashboard', 'generators', 'routes', 'subscribers', 'collectors', 'readings', 'invoices', 'collections', 'expenses', 'maintenance', 'reports', 'sync-audit'],
      collector_provisioning_enabled: true,
      verified_assignment_targets_enabled: true,
      domain_contracts_enabled: true,
      hard_delete_enabled: false,
      collector_permission_allowlist: COLLECTOR_PERMISSION_ALLOWLIST,
      financial_workflows_enabled: false
    }
  });
});

// Owner collector management from Stage02.
generatorsRouter.get('/owner/collectors', ...ownerPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerCollectors(req.generatorAuth) });
}));

generatorsRouter.post('/owner/collectors', ...ownerPermission('collectors.manage'), asyncHandler((req, res) => {
  res.status(201).json({ ok: true, data: createOwnerCollector(req.generatorAuth, req.body || {}) });
}));

generatorsRouter.get('/owner/collectors/:collectorId', ...ownerPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: getOwnerCollector(req.generatorAuth, req.params.collectorId) });
}));

generatorsRouter.patch('/owner/collectors/:collectorId', ...ownerPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerCollector(req.generatorAuth, req.params.collectorId, req.body || {}) });
}));

generatorsRouter.patch('/owner/collectors/:collectorId/status', ...ownerPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerCollectorStatus(req.generatorAuth, req.params.collectorId, req.body || {}) });
}));

generatorsRouter.put('/owner/collectors/:collectorId/permissions', ...ownerPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerCollectorPermissions(req.generatorAuth, req.params.collectorId, req.body || {}) });
}));

generatorsRouter.post('/owner/collectors/:collectorId/reset-password', ...ownerPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: resetOwnerCollectorPassword(req.generatorAuth, req.params.collectorId, req.body || {}) });
}));

generatorsRouter.get('/owner/collectors/:collectorId/assignments', ...ownerPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerCollectorAssignments(req.generatorAuth, req.params.collectorId) });
}));

generatorsRouter.put('/owner/collectors/:collectorId/assignments', ...ownerPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: replaceOwnerCollectorAssignments(req.generatorAuth, req.params.collectorId, req.body || {}) });
}));

// Stage03 generators CRUD contracts: create/read/update/status only, never hard delete.
generatorsRouter.get('/owner/generators', ...ownerPermission('generators.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerGenerators(req.generatorAuth, req.query || {}) });
}));

generatorsRouter.post('/owner/generators', ...ownerPermission('generators.manage'), asyncHandler((req, res) => {
  res.status(201).json({ ok: true, data: createOwnerGenerator(req.generatorAuth, req.body || {}) });
}));

generatorsRouter.get('/owner/generators/:generatorId', ...ownerPermission('generators.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: getOwnerGenerator(req.generatorAuth, req.params.generatorId) });
}));

generatorsRouter.patch('/owner/generators/:generatorId', ...ownerPermission('generators.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerGenerator(req.generatorAuth, req.params.generatorId, req.body || {}) });
}));

generatorsRouter.patch('/owner/generators/:generatorId/status', ...ownerPermission('generators.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerGeneratorStatus(req.generatorAuth, req.params.generatorId, req.body || {}) });
}));

// Stage03 routes CRUD contracts.
generatorsRouter.get('/owner/routes', ...ownerPermission('generators.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerRoutes(req.generatorAuth, req.query || {}) });
}));

generatorsRouter.post('/owner/routes', ...ownerPermission('generators.manage'), asyncHandler((req, res) => {
  res.status(201).json({ ok: true, data: createOwnerRoute(req.generatorAuth, req.body || {}) });
}));

generatorsRouter.get('/owner/routes/:routeId', ...ownerPermission('generators.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: getOwnerRoute(req.generatorAuth, req.params.routeId) });
}));

generatorsRouter.patch('/owner/routes/:routeId', ...ownerPermission('generators.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerRoute(req.generatorAuth, req.params.routeId, req.body || {}) });
}));

generatorsRouter.patch('/owner/routes/:routeId/status', ...ownerPermission('generators.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerRouteStatus(req.generatorAuth, req.params.routeId, req.body || {}) });
}));

// Stage03 subscribers CRUD contracts.
generatorsRouter.get('/owner/subscribers', ...ownerPermission('subscribers.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerSubscribers(req.generatorAuth, req.query || {}) });
}));

generatorsRouter.post('/owner/subscribers', ...ownerPermission('subscribers.manage'), asyncHandler((req, res) => {
  res.status(201).json({ ok: true, data: createOwnerSubscriber(req.generatorAuth, req.body || {}) });
}));

generatorsRouter.get('/owner/subscribers/:subscriberId', ...ownerPermission('subscribers.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: getOwnerSubscriber(req.generatorAuth, req.params.subscriberId) });
}));

generatorsRouter.patch('/owner/subscribers/:subscriberId', ...ownerPermission('subscribers.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerSubscriber(req.generatorAuth, req.params.subscriberId, req.body || {}) });
}));

generatorsRouter.patch('/owner/subscribers/:subscriberId/status', ...ownerPermission('subscribers.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerSubscriberStatus(req.generatorAuth, req.params.subscriberId, req.body || {}) });
}));

generatorsRouter.get('/owner/assignment-catalog', ...ownerPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerAssignmentCatalog(req.generatorAuth, req.query || {}) });
}));

generatorsRouter.get('/collector/foundation', ...collectorOnly, (req, res) => {
  res.json({
    ok: true,
    data: {
      role: 'collector',
      tenant_id: req.generatorAuth.tenantPublicId,
      stage: 'Stage03',
      modules: ['assigned-generators', 'assigned-routes', 'assigned-subscribers', 'readings', 'collections', 'own-history', 'sync-status'],
      permissions: req.generatorAuth.permissions,
      assigned_domain_enabled: true,
      financial_workflows_enabled: false
    }
  });
});

generatorsRouter.get('/collector/assignments', ...collectorPermissions('assignments.read'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listCollectorOwnAssignments(req.generatorAuth) });
}));

generatorsRouter.get('/collector/domain', ...collectorPermissions('assignments.read', 'subscribers.assigned.read'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listCollectorAssignedDomain(req.generatorAuth) });
}));

generatorsRouter.post('/sync/operations', asyncHandler((req, res) => {
  const data = recordSyncOperation(req.generatorAuth, req.body || {});
  res.status(data.duplicate ? 200 : 201).json({ ok: true, data });
}));

generatorsRouter.get('/sync/status', asyncHandler((req, res) => {
  res.json({ ok: true, data: getGeneratorSyncStatus(req.generatorAuth) });
}));

module.exports = { generatorsRouter };
