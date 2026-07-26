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
const {
  enrichOwnerMonthlyPeriods,
  enrichOwnerMonthlyWorkspace,
  recordOwnerInvoicePayment
} = require('./generators.simple_payments.service');

const simpleBillingRouter = express.Router();
const ownerInvoices = [
  requireGeneratorAuth,
  requireGeneratorRole('owner'),
  requireGeneratorPermission('invoices.manage')
];

simpleBillingRouter.get('/health', (_req, res) => {
  ensureGeneratorsSchema();
  res.json({ ok: true, data: { module: 'generators', version: 'simple-payments', status: 'ready' } });
});

simpleBillingRouter.get('/owner/foundation', ...ownerInvoices, (req, res) => {
  res.json({
    ok: true,
    data: {
      role: 'owner',
      tenant_id: req.generatorAuth.tenantPublicId,
      version: 'simple-payments',
      flow: ['قراءات العداد', 'سعر الأمبير', 'فواتير الشهر', 'تسجيل الدفعة'],
      monthly_invoices_enabled: true,
      invoice_is_debt: true,
      simple_payments_enabled: true,
      receipt_enabled: true,
      draft_workflow_enabled: false,
      review_workflow_enabled: false,
      approval_workflow_enabled: false,
      separate_debt_ledger_enabled: false,
      separate_cash_box_enabled: false
    }
  });
});

simpleBillingRouter.get('/owner/monthly-billing/periods', ...ownerInvoices, asyncHandler((req, res) => {
  const data = listOwnerMonthlyPeriods(req.generatorAuth);
  res.json({ ok: true, data: enrichOwnerMonthlyPeriods(req.generatorAuth, data) });
}));

simpleBillingRouter.get('/owner/monthly-billing/periods/:periodId', ...ownerInvoices, asyncHandler((req, res) => {
  const workspace = getOwnerMonthlyWorkspace(req.generatorAuth, req.params.periodId, req.query || {});
  res.json({
    ok: true,
    data: enrichOwnerMonthlyWorkspace(req.generatorAuth, workspace, req.params.periodId)
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

simpleBillingRouter.post(
  '/owner/monthly-billing/invoices/:invoiceId/payments',
  ...ownerInvoices,
  asyncHandler((req, res) => {
    const data = recordOwnerInvoicePayment(
      req.generatorAuth,
      req.params.invoiceId,
      req.body || {}
    );
    res.status(data.duplicate ? 200 : 201).json({ ok: true, data });
  })
);

module.exports = { simpleBillingRouter };
