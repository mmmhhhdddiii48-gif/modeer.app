const express = require('express');
const { asyncHandler } = require('../../utils/asyncHandler');
const { httpError } = require('../../utils/httpError');
const {
  requireGeneratorAuth,
  requireGeneratorRole,
  requireGeneratorPermission
} = require('./generators.auth.middleware');
const { ensureGeneratorsSchema } = require('./generators.db');
const { COLLECTOR_PERMISSION_ALLOWLIST } = require('./generators.collectors.service');
const { updateOwnerBillingDraftStatus } = require('./generators.billing.service');
const {
  approveOwnerBillingDraft,
  listOwnerInvoices,
  listOwnerDebtLedger
} = require('./generators.invoices.service');

const generatorsRouter = express.Router();
const ownerPermission = (permission) => [
  requireGeneratorAuth,
  requireGeneratorRole('owner'),
  requireGeneratorPermission(permission)
];
const collectorOnly = [requireGeneratorAuth, requireGeneratorRole('collector')];

generatorsRouter.get('/health', (_req, res) => {
  ensureGeneratorsSchema();
  res.json({ ok: true, data: { module: 'generators', stage: 'Stage06', status: 'ready' } });
});

generatorsRouter.get('/owner/foundation', ...ownerPermission('invoices.manage'), (req, res) => {
  res.json({
    ok: true,
    data: {
      role: 'owner',
      tenant_id: req.generatorAuth.tenantPublicId,
      stage: 'Stage06',
      modules: ['dashboard', 'generators', 'routes', 'subscribers', 'collectors', 'readings', 'billing-drafts', 'approved-invoices', 'debt-ledger', 'collections', 'expenses', 'maintenance', 'reports', 'sync-audit'],
      collector_provisioning_enabled: true,
      verified_assignment_targets_enabled: true,
      domain_contracts_enabled: true,
      meter_reading_offline_enabled: true,
      monthly_billing_drafts_enabled: true,
      invoice_approval_enabled: true,
      debt_ledger_enabled: true,
      collection_enabled: false,
      receipt_enabled: false,
      cash_effect_enabled: false,
      hard_delete_enabled: false,
      collector_permission_allowlist: COLLECTOR_PERMISSION_ALLOWLIST,
      financial_workflows_enabled: true
    }
  });
});

generatorsRouter.get('/collector/foundation', ...collectorOnly, (req, res) => {
  res.json({
    ok: true,
    data: {
      role: 'collector',
      tenant_id: req.generatorAuth.tenantPublicId,
      stage: 'Stage06',
      modules: ['assigned-generators', 'assigned-routes', 'assigned-subscribers', 'meter-readings', 'collections', 'own-history', 'sync-status'],
      permissions: req.generatorAuth.permissions,
      assigned_domain_enabled: true,
      meter_reading_offline_enabled: req.generatorAuth.permissions.includes('readings.create'),
      billing_drafts_visible: false,
      approved_invoices_visible: false,
      debt_ledger_visible: false,
      collection_enabled: false,
      financial_workflows_enabled: false
    }
  });
});

generatorsRouter.patch('/owner/billing/drafts/:draftId/status', ...ownerPermission('invoices.manage'), asyncHandler((req, res) => {
  const approved = listOwnerInvoices(req.generatorAuth).invoices
    .some((invoice) => invoice.billing_draft_id === req.params.draftId);
  if (approved) {
    throw httpError(409, 'BILLING_DRAFT_ALREADY_APPROVED', 'Approved invoice drafts cannot return to draft or reviewed status.');
  }
  res.json({ ok: true, data: updateOwnerBillingDraftStatus(req.generatorAuth, req.params.draftId, req.body || {}) });
}));

generatorsRouter.post('/owner/billing/drafts/:draftId/approve', ...ownerPermission('invoices.manage'), asyncHandler((req, res) => {
  const data = approveOwnerBillingDraft(req.generatorAuth, req.params.draftId, req.body || {});
  res.status(data.duplicate ? 200 : 201).json({ ok: true, data });
}));

generatorsRouter.get('/owner/invoices', ...ownerPermission('invoices.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerInvoices(req.generatorAuth, req.query || {}) });
}));

generatorsRouter.get('/owner/debt-ledger', ...ownerPermission('invoices.manage'), asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerDebtLedger(req.generatorAuth, req.query || {}) });
}));

module.exports = { generatorsRouter };
