const express = require('express');
const { asyncHandler } = require('../../utils/asyncHandler');
const {
  loginGeneratorAccount,
  refreshGeneratorSession,
  logoutGeneratorSession,
  getCurrentGeneratorContext
} = require('./generators.auth.service');
const { requireGeneratorAuth, requireGeneratorRole } = require('./generators.auth.middleware');
const { recordSyncOperation, getGeneratorSyncStatus } = require('./generators.sync.service');
const { ensureGeneratorsSchema } = require('./generators.db');

const generatorsRouter = express.Router();

generatorsRouter.get('/health', (_req, res) => {
  ensureGeneratorsSchema();
  res.json({ ok: true, data: { module: 'generators', stage: 'Stage01', status: 'ready' } });
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
      stage: 'Stage01',
      modules: ['dashboard', 'generators', 'subscribers', 'collectors', 'readings', 'invoices', 'collections', 'expenses', 'maintenance', 'reports', 'sync-audit'],
      financial_workflows_enabled: false
    }
  });
});

generatorsRouter.get('/collector/foundation', requireGeneratorRole('collector'), (req, res) => {
  res.json({
    ok: true,
    data: {
      role: 'collector',
      tenant_id: req.generatorAuth.tenantPublicId,
      stage: 'Stage01',
      modules: ['assigned-subscribers', 'readings', 'collections', 'own-history', 'sync-status'],
      financial_workflows_enabled: false
    }
  });
});

generatorsRouter.post('/sync/operations', asyncHandler((req, res) => {
  const data = recordSyncOperation(req.generatorAuth, req.body || {});
  res.status(data.duplicate ? 200 : 201).json({ ok: true, data });
}));

generatorsRouter.get('/sync/status', asyncHandler((req, res) => {
  res.json({ ok: true, data: getGeneratorSyncStatus(req.generatorAuth) });
}));

module.exports = { generatorsRouter };
