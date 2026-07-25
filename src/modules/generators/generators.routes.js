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

const generatorsRouter = express.Router();

generatorsRouter.get('/health', (_req, res) => {
  ensureGeneratorsSchema();
  res.json({ ok: true, data: { module: 'generators', stage: 'Stage02', status: 'ready' } });
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

generatorsRouter.get('/owner/foundation', requireGeneratorRole('owner'), (req, res) => {
  res.json({
    ok: true,
    data: {
      role: 'owner',
      tenant_id: req.generatorAuth.tenantPublicId,
      stage: 'Stage02',
      modules: ['dashboard', 'generators', 'subscribers', 'collectors', 'readings', 'invoices', 'collections', 'expenses', 'maintenance', 'reports', 'sync-audit'],
      collector_provisioning_enabled: true,
      collector_assignment_foundation_enabled: true,
      collector_permission_allowlist: COLLECTOR_PERMISSION_ALLOWLIST,
      financial_workflows_enabled: false
    }
  });
});

generatorsRouter.get('/owner/collectors', requireGeneratorRole('owner'), requireGeneratorPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerCollectors(req.generatorAuth) });
}));

generatorsRouter.post('/owner/collectors', requireGeneratorRole('owner'), requireGeneratorPermission('collectors.manage'), asyncHandler((req, res) => {
  res.status(201).json({ ok: true, data: createOwnerCollector(req.generatorAuth, req.body || {}) });
}));

generatorsRouter.get('/owner/collectors/:collectorId', requireGeneratorRole('owner'), requireGeneratorPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: getOwnerCollector(req.generatorAuth, req.params.collectorId) });
}));

generatorsRouter.patch('/owner/collectors/:collectorId', requireGeneratorRole('owner'), requireGeneratorPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerCollector(req.generatorAuth, req.params.collectorId, req.body || {}) });
}));

generatorsRouter.patch('/owner/collectors/:collectorId/status', requireGeneratorRole('owner'), requireGeneratorPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerCollectorStatus(req.generatorAuth, req.params.collectorId, req.body || {}) });
}));

generatorsRouter.put('/owner/collectors/:collectorId/permissions', requireGeneratorRole('owner'), requireGeneratorPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: updateOwnerCollectorPermissions(req.generatorAuth, req.params.collectorId, req.body || {}) });
}));

generatorsRouter.post('/owner/collectors/:collectorId/reset-password', requireGeneratorRole('owner'), requireGeneratorPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: resetOwnerCollectorPassword(req.generatorAuth, req.params.collectorId, req.body || {}) });
}));

generatorsRouter.get('/owner/collectors/:collectorId/assignments', requireGeneratorRole('owner'), requireGeneratorPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerCollectorAssignments(req.generatorAuth, req.params.collectorId) });
}));

generatorsRouter.put('/owner/collectors/:collectorId/assignments', requireGeneratorRole('owner'), requireGeneratorPermission('collectors.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: replaceOwnerCollectorAssignments(req.generatorAuth, req.params.collectorId, req.body || {}) });
}));

generatorsRouter.get('/collector/foundation', requireGeneratorRole('collector'), (req, res) => {
  res.json({
    ok: true,
    data: {
      role: 'collector',
      tenant_id: req.generatorAuth.tenantPublicId,
      stage: 'Stage02',
      modules: ['assigned-subscribers', 'readings', 'collections', 'own-history', 'sync-status'],
      permissions: req.generatorAuth.permissions,
      financial_workflows_enabled: false
    }
  });
});

generatorsRouter.get('/collector/assignments', requireGeneratorRole('collector'), requireGeneratorPermission('assignments.read'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listCollectorOwnAssignments(req.generatorAuth) });
}));

generatorsRouter.post('/sync/operations', asyncHandler((req, res) => {
  const data = recordSyncOperation(req.generatorAuth, req.body || {});
  res.status(data.duplicate ? 200 : 201).json({ ok: true, data });
}));

generatorsRouter.get('/sync/status', asyncHandler((req, res) => {
  res.json({ ok: true, data: getGeneratorSyncStatus(req.generatorAuth) });
}));

module.exports = { generatorsRouter };
