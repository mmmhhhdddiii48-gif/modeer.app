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
const {
  listOwnerReadingPeriods,
  createOwnerReadingPeriod,
  lockOwnerReadingPeriod,
  listOwnerMeterReadings,
  getCollectorReadingContext
} = require('./generators.readings.service');
const {
  listOwnerBillingPeriods,
  getOwnerBillingWorkspace,
  upsertOwnerBillingTariff,
  generateOwnerBillingDrafts,
  updateOwnerBillingDraftStatus
} = require('./generators.billing.service');

const generatorsRouter = express.Router();
const ownerOnly = [requireGeneratorRole('owner')];
const collectorOnly = [requireGeneratorRole('collector')];
function ownerPermission(permission) { return [...ownerOnly, requireGeneratorPermission(permission)]; }
function collectorPermissions(...permissions) {
  return [...collectorOnly, ...permissions.map((permission) => requireGeneratorPermission(permission))];
}

generatorsRouter.get('/health', (_req, res) => {
  ensureGeneratorsSchema();
  res.json({ ok: true, data: { module: 'generators', stage: 'Stage05', status: 'ready' } });
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
      stage: 'Stage05',
      modules: ['dashboard', 'generators', 'routes', 'subscribers', 'collectors', 'readings', 'billing-drafts', 'collections', 'expenses', 'maintenance', 'reports', 'sync-audit'],
      collector_provisioning_enabled: true,
      verified_assignment_targets_enabled: true,
      domain_contracts_enabled: true,
      meter_reading_offline_enabled: true,
      monthly_billing_drafts_enabled: true,
      billing_calculation_method: 'contracted_amperes',
      hard_delete_enabled: false,
      collection_enabled: false,
      debt_enabled: false,
      collector_permission_allowlist: COLLECTOR_PERMISSION_ALLOWLIST,
      financial_workflows_enabled: false
    }
  });
});

// Owner collector management.
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

// Generators, routes, and subscribers.
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

// Meter-reading period management.
generatorsRouter.get('/owner/reading-periods', ...ownerPermission('readings.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerReadingPeriods(req.generatorAuth) });
}));
generatorsRouter.post('/owner/reading-periods', ...ownerPermission('readings.manage'), asyncHandler((req, res) => {
  res.status(201).json({ ok: true, data: createOwnerReadingPeriod(req.generatorAuth, req.body || {}) });
}));
generatorsRouter.patch('/owner/reading-periods/:periodId/lock', ...ownerPermission('readings.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: lockOwnerReadingPeriod(req.generatorAuth, req.params.periodId, req.body || {}) });
}));
generatorsRouter.get('/owner/meter-readings', ...ownerPermission('readings.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerMeterReadings(req.generatorAuth, req.query || {}) });
}));

// Stage05 monthly tariff and review-only billing drafts. No collection/debt side effects.
generatorsRouter.get('/owner/billing/periods', ...ownerPermission('invoices.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerBillingPeriods(req.generatorAuth) });
}));
generatorsRouter.get('/owner/billing/periods/:periodId', ...ownerPermission('invoices.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: getOwnerBillingWorkspace(req.generatorAuth, req.params.periodId, req.query || {}) });
}));
generatorsRouter.put('/owner/billing/periods/:periodId/tariffs/:generatorId', ...ownerPermission('invoices.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: upsertOwnerBillingTariff(req.generatorAuth, req.params.periodId, req.params.generatorId, req.body || {}) });
}));
generatorsRouter.post('/owner/billing/periods/:periodId/generate', ...ownerPermission('invoices.manage'), asyncHandler((req, res) => {
  res.status(201).json({ ok: true, data: generateOwnerBillingDrafts(req.generatorAuth, req.params.periodId) });
}));
generatorsRouter.patch('/owner/billing/drafts/:draftId/status', ...ownerPermission('invoices.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerBillingDraftStatus(req.generatorAuth, req.params.draftId, req.body || {}) });
}));

generatorsRouter.get('/collector/foundation', ...collectorOnly, (req, res) => {
  res.json({
    ok: true,
    data: {
      role: 'collector',
      tenant_id: req.generatorAuth.tenantPublicId,
      stage: 'Stage05',
      modules: ['assigned-generators', 'assigned-routes', 'assigned-subscribers', 'meter-readings', 'collections', 'own-history', 'sync-status'],
      permissions: req.generatorAuth.permissions,
      assigned_domain_enabled: true,
      meter_reading_offline_enabled: req.generatorAuth.permissions.includes('readings.create'),
      billing_drafts_visible: false,
      collection_enabled: false,
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
generatorsRouter.get('/collector/readings/context', ...collectorPermissions('assignments.read', 'subscribers.assigned.read', 'readings.create'), asyncHandler((req, res) => {
  res.json({ ok: true, data: getCollectorReadingContext(req.generatorAuth) });
}));

generatorsRouter.post('/sync/operations', asyncHandler((req, res) => {
  const data = recordSyncOperation(req.generatorAuth, req.body || {});
  const statusCode = data.duplicate || ['conflict', 'rejected'].includes(data.status) ? 200 : 201;
  res.status(statusCode).json({ ok: true, data });
}));
generatorsRouter.get('/sync/status', asyncHandler((req, res) => {
  res.json({ ok: true, data: getGeneratorSyncStatus(req.generatorAuth) });
}));

module.exports = { generatorsRouter };
