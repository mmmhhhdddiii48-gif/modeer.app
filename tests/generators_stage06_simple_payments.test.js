const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'nukhba-generators-simple-payments-'));
process.env.DB_FILE = path.join(tempDir, 'simple-payments.sqlite3');
process.env.AUTH_TOKEN_SECRET = 'simple-payments-test-secret';

const { closeDatabase, getDatabase } = require('../src/db');
const { provisionTenantOwnerForStage01, findAccountContext } = require('../src/modules/generators/generators.db');
const { loginGeneratorAccount } = require('../src/modules/generators/generators.auth.service');
const { verifyGeneratorAccessToken } = require('../src/modules/generators/generators.token');
const { createOwnerCollector, replaceOwnerCollectorAssignments } = require('../src/modules/generators/generators.collectors.service');
const { createOwnerGenerator, createOwnerRoute, createOwnerSubscriber } = require('../src/modules/generators/generators.domain.service');
const { createOwnerReadingPeriod, lockOwnerReadingPeriod } = require('../src/modules/generators/generators.readings.service');
const { recordSyncOperation } = require('../src/modules/generators/generators.sync.service');
const {
  getOwnerMonthlyWorkspace,
  saveOwnerMonthlyPrice,
  createOwnerMonthlyInvoices
} = require('../src/modules/generators/generators.simple_billing.service');
const {
  enrichOwnerMonthlyWorkspace,
  recordOwnerInvoicePayment
} = require('../src/modules/generators/generators.simple_payments.service');

function ownerAuth(owner) {
  return {
    accountId: Number(owner.id),
    accountPublicId: owner.public_id,
    tenantId: Number(owner.tenant_id),
    tenantPublicId: owner.tenant_public_id,
    role: 'owner',
    permissions: ['generators.manage', 'subscribers.manage', 'collectors.manage', 'readings.manage', 'invoices.manage']
  };
}

function collectorAuth(login, password) {
  const session = loginGeneratorAccount({ login, password });
  const claims = verifyGeneratorAccessToken(session.access_token);
  const context = findAccountContext(Number(claims.sub));
  return {
    accountId: Number(context.id),
    accountPublicId: context.public_id,
    tenantId: Number(context.tenant_id),
    tenantPublicId: context.tenant_public_id,
    role: 'collector',
    permissions: session.permissions
  };
}

test('simple payments update the same invoice and issue visible receipts', () => {
  const owner = provisionTenantOwnerForStage01({
    tenantName: 'مولدة التسديد الواضح',
    username: 'simple-pay-owner',
    password: 'simple-pay-owner-secret',
    collectorLimit: 1
  });
  const auth = ownerAuth(owner);
  const generator = createOwnerGenerator(auth, { code: 'G-P', name: 'مولدة الدفع' });
  const route = createOwnerRoute(auth, { code: 'R-P', name: 'مسار الدفع', generator_id: generator.id });
  const subscriber = createOwnerSubscriber(auth, {
    account_number: 'P-001',
    full_name: 'مشترك عشرة أمبير',
    generator_id: generator.id,
    route_id: route.id,
    meter_number: 'M-P-1',
    contracted_amperes: 10
  });
  const collector = createOwnerCollector(auth, {
    full_name: 'جابي الدفع',
    username: 'simple-pay-collector',
    password: 'simple-pay-collector-secret'
  }).collector;
  replaceOwnerCollectorAssignments(auth, collector.id, {
    assignments: [{ type: 'generator', target_id: generator.id }]
  });
  const fieldAuth = collectorAuth('simple-pay-collector', 'simple-pay-collector-secret');

  const period = createOwnerReadingPeriod(auth, { period_key: '2026-07' });
  recordSyncOperation(fieldAuth, {
    operation_uuid: crypto.randomUUID(),
    operation_type: 'reading.create',
    client_created_at: new Date().toISOString(),
    payload: {
      period_id: period.id,
      subscriber_id: subscriber.id,
      previous_value: 0,
      current_value: 100
    }
  });
  lockOwnerReadingPeriod(auth, period.id, { confirm: true });
  saveOwnerMonthlyPrice(auth, period.id, generator.id, {
    price_per_amp_iqd: 12000,
    fixed_fee_iqd: 3000
  });
  const created = createOwnerMonthlyInvoices(auth, period.id, { confirm: true });
  const invoiceId = created.workspace.invoices[0].id;

  const operationUuid = crypto.randomUUID();
  const first = recordOwnerInvoicePayment(auth, invoiceId, {
    confirm: true,
    operation_uuid: operationUuid,
    amount_iqd: 50000,
    payment_method: 'cash'
  });
  assert.equal(first.invoice.status, 'partial');
  assert.equal(first.invoice.paid_amount_iqd, 50000);
  assert.equal(first.invoice.remaining_amount_iqd, 73000);

  const duplicate = recordOwnerInvoicePayment(auth, invoiceId, {
    confirm: true,
    operation_uuid: operationUuid,
    amount_iqd: 50000,
    payment_method: 'cash'
  });
  assert.equal(duplicate.duplicate, true);

  assert.throws(
    () => recordOwnerInvoicePayment(auth, invoiceId, {
      confirm: true,
      operation_uuid: crypto.randomUUID(),
      amount_iqd: 74000,
      payment_method: 'cash'
    }),
    (error) => error.code === 'PAYMENT_EXCEEDS_REMAINING'
  );

  const finalPayment = recordOwnerInvoicePayment(auth, invoiceId, {
    confirm: true,
    operation_uuid: crypto.randomUUID(),
    amount_iqd: 73000,
    payment_method: 'transfer',
    note: 'تسديد نهائي'
  });
  assert.equal(finalPayment.invoice.status, 'paid');
  assert.equal(finalPayment.invoice.remaining_amount_iqd, 0);

  const workspace = enrichOwnerMonthlyWorkspace(
    auth,
    getOwnerMonthlyWorkspace(auth, period.id),
    period.id
  );
  assert.equal(workspace.summary.total_iqd, 123000);
  assert.equal(workspace.summary.paid_iqd, 123000);
  assert.equal(workspace.summary.remaining_iqd, 0);
  assert.equal(workspace.summary.paid_count, 1);
  assert.equal(workspace.invoices[0].payments.length, 2);

  const db = getDatabase();
  assert.equal(
    db.prepare('SELECT COUNT(*) AS count FROM generator_invoice_payments').get().count,
    2
  );
  assert.equal(
    db.prepare("SELECT COUNT(*) AS count FROM sqlite_master WHERE type='table' AND name LIKE '%debt_ledger%'").get().count,
    0
  );
});

test.after(() => {
  closeDatabase();
  fs.rmSync(tempDir, { recursive: true, force: true });
});
