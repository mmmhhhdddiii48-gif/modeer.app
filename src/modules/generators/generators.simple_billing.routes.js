const express = require('express');
const { asyncHandler } = require('../../utils/asyncHandler');
const {
  requireGeneratorAuth,
  requireGeneratorRole,
  requireGeneratorPermission
} = require('./generators.auth.middleware');
const { ensureGeneratorsSchema } = require('./generators.db');
const {
  listOwnerMonthlyPeriods,
  getOwnerMonthlyWorkspace,
  saveOwnerMonthlyPrice,
  createOwnerMonthlyInvoices
} = require('./generators.simple_billing.service');

const simpleBillingRouter = express.Router();
const ownerInvoices = [
  requireGeneratorAuth,
  requireGeneratorRole('owner'),
  requireGeneratorPermission('invoices.manage')
];

simpleBillingRouter.get('/health', (_req, res) => {
  ensureGeneratorsSchema();
  res.json({ ok: true, data: { module: 'generators', version: 'simple-clear', status: 'ready' } });
});

simpleBillingRouter.get('/owner/foundation', ...ownerInvoices, (req, res) => {
  res.json({
    ok: true,
    data: {
      role: 'owner',
      tenant_id: req.generatorAuth.tenantPublicId,
      version: 'simple-clear',
      flow: ['قراءات العداد', 'سعر الأمبير', 'فواتير الشهر'],
      monthly_invoices_enabled: true,
      invoice_is_debt: true,
      draft_workflow_enabled: false,
      review_workflow_enabled: false,
      approval_workflow_enabled: false,
      separate_debt_ledger_enabled: false,
      collection_enabled: false
    }
  });
});

simpleBillingRouter.get('/owner/monthly-billing/periods', ...ownerInvoices, asyncHandler((req, res) => {
  res.json({ ok: true, data: listOwnerMonthlyPeriods(req.generatorAuth) });
}));

simpleBillingRouter.get('/owner/monthly-billing/periods/:periodId', ...ownerInvoices, asyncHandler((req, res) => {
  res.json({
    ok: true,
    data: getOwnerMonthlyWorkspace(req.generatorAuth, req.params.periodId, req.query || {})
  });
}));

simpleBillingRouter.put(
  '/owner/monthly-billing/periods/:periodId/generators/:generatorId/price',
  ...ownerInvoices,
  asyncHandler((req, res) => {
    res.json({
      ok: true,
      data: saveOwnerMonthlyPrice(
        req.generatorAuth,
        req.params.periodId,
        req.params.generatorId,
        req.body || {}
      )
    });
  })
);

simpleBillingRouter.post(
  '/owner/monthly-billing/periods/:periodId/create-invoices',
  ...ownerInvoices,
  asyncHandler((req, res) => {
    const data = createOwnerMonthlyInvoices(
      req.generatorAuth,
      req.params.periodId,
      req.body || {}
    );
    res.status(data.created_count > 0 ? 201 : 200).json({ ok: true, data });
  })
);

module.exports = { simpleBillingRouter };
