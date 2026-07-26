const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'nukhba-generators-collector-payments-'));
process.env.DB_FILE = path.join(tempDir, 'collector-payments.sqlite3');
process.env.AUTH_TOKEN_SECRET = 'collector-payments-test-secret';

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
  enrichOwnerMonthlyWorkspaceWithReceivers,
  listCollectorAssignedInvoices,
  recordCollectorInvoicePayment
} = require('../src/modules/generators/generators.collector_payments.service');

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

function pushReading(auth, periodId, subscriberId, currentValue) {
  return recordSyncOperation(auth, {
    operation_uuid: crypto.randomUUID(),
    operation_type: 'reading.create',
    client_created_at: new Date().toISOString(),
    payload: {
      period_id: periodId,
      subscriber_id: subscriberId,
      previous_value: 0,
      current_value: currentValue
    }
  });
}

test('collector sees and pays only assigned invoices while owner sees receiver identity', () => {
  const owner = provisionTenantOwnerForStage01({
    tenantName: 'مولدة تحصيل الجباة',
    username: 'collector-pay-owner',
    password: 'collector-pay-owner-secret',
    collectorLimit: 2
  });
  const auth = ownerAuth(owner);

  const generatorA = createOwnerGenerator(auth, { code: 'G-A', name: 'مولدة أ' });
  const routeA = createOwnerRoute(auth, { code: 'R-A', name: 'مسار أ', generator_id: generatorA.id });
  const subscriberA = createOwnerSubscriber(auth, {
    account_number: 'A-001',
    full_name: 'مشترك أ',
    generator_id: generatorA.id,
    route_id: routeA.id,
    meter_number: 'M-A',
    contracted_amperes: 10
  });

  const generatorB = createOwnerGenerator(auth, { code: 'G-B', name: 'مولدة ب' });
  const routeB = createOwnerRoute(auth, { code: 'R-B', name: 'مسار ب', generator_id: generatorB.id });
  const subscriberB = createOwnerSubscriber(auth, {
    account_number: 'B-001',
    full_name: 'مشترك ب',
    generator_id: generatorB.id,
    route_id: routeB.id,
    meter_number: 'M-B',
    contracted_amperes: 5
  });

  const collectorA = createOwnerCollector(auth, {
    full_name: 'جابي أ',
    username: 'collector-pay-a',
    password: 'collector-pay-a-secret'
  }).collector;
  const collectorB = createOwnerCollector(auth, {
    full_name: 'جابي ب',
    username: 'collector-pay-b',
    password: 'collector-pay-b-secret'
  }).collector;

  replaceOwnerCollectorAssignments(auth, collectorA.id, {
    assignments: [{ type: 'route', target_id: routeA.id }]
  });
  replaceOwnerCollectorAssignments(auth, collectorB.id, {
    assignments: [{ type: 'subscriber', target_id: subscriberB.id }]
  });

  const fieldA = collectorAuth('collector-pay-a', 'collector-pay-a-secret');
  const fieldB = collectorAuth('collector-pay-b', 'collector-pay-b-secret');
  const period = createOwnerReadingPeriod(auth, { period_key: '2026-08' });
  assert.equal(pushReading(fieldA, period.id, subscriberA.id, 100).status, 'applied');
  assert.equal(pushReading(fieldB, period.id, subscriberB.id, 50).status, 'applied');
  lockOwnerReadingPeriod(auth, period.id, { confirm: true });

  saveOwnerMonthlyPrice(auth, period.id, generatorA.id, {
    price_per_amp_iqd: 12000,
    fixed_fee_iqd: 3000
  });
  saveOwnerMonthlyPrice(auth, period.id, generatorB.id, {
    price_per_amp_iqd: 10000,
    fixed_fee_iqd: 0
  });
  const created = createOwnerMonthlyInvoices(auth, period.id, { confirm: true });
  const invoiceA = created.workspace.invoices.find((invoice) => invoice.account_number === 'A-001');
  const invoiceB = created.workspace.invoices.find((invoice) => invoice.account_number === 'B-001');

  const workspaceA = listCollectorAssignedInvoices(fieldA);
  assert.equal(workspaceA.invoices.length, 1);
  assert.equal(workspaceA.invoices[0].account_number, 'A-001');
  assert.equal(workspaceA.assignment_enforced, true);
  assert.equal(workspaceA.offline_collection_enabled, false);

  const workspaceB = listCollectorAssignedInvoices(fieldB);
  assert.equal(workspaceB.invoices.length, 1);
  assert.equal(workspaceB.invoices[0].account_number, 'B-001');

  assert.throws(
    () => recordCollectorInvoicePayment(fieldA, invoiceB.id, {
      confirm: true,
      operation_uuid: crypto.randomUUID(),
      amount_iqd: 10000,
      payment_method: 'cash'
    }),
    (error) => error.code === 'COLLECTOR_INVOICE_NOT_ASSIGNED'
  );

  const operationUuid = crypto.randomUUID();
  const first = recordCollectorInvoicePayment(fieldA, invoiceA.id, {
    confirm: true,
    operation_uuid: operationUuid,
    amount_iqd: 50000,
    payment_method: 'cash',
    note: 'دفعة ميدانية'
  });
  assert.equal(first.invoice.status, 'partial');
  assert.equal(first.invoice.remaining_amount_iqd, 73000);
  assert.equal(first.payment.received_by.role, 'collector');
  assert.equal(first.payment.received_by.name, 'جابي أ');

  const duplicate = recordCollectorInvoicePayment(fieldA, invoiceA.id, {
    confirm: true,
    operation_uuid: operationUuid,
    amount_iqd: 50000,
    payment_method: 'cash'
  });
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.payment.receipt_number, first.payment.receipt_number);

  assert.throws(
    () => recordCollectorInvoicePayment(fieldB, invoiceB.id, {
      confirm: true,
      operation_uuid: operationUuid,
      amount_iqd: 10000,
      payment_method: 'cash'
    }),
    (error) => error.code === 'PAYMENT_OPERATION_CONFLICT'
  );

  const refreshedA = listCollectorAssignedInvoices(fieldA, { q: 'A-001' });
  assert.equal(refreshedA.invoices[0].paid_amount_iqd, 50000);
  assert.equal(refreshedA.invoices[0].remaining_amount_iqd, 73000);
  assert.equal(refreshedA.invoices[0].payments.length, 1);

  const ownerWorkspace = enrichOwnerMonthlyWorkspaceWithReceivers(
    auth,
    getOwnerMonthlyWorkspace(auth, period.id),
    period.id
  );
  const ownerInvoiceA = ownerWorkspace.invoices.find((invoice) => invoice.id === invoiceA.id);
  assert.equal(ownerInvoiceA.payments[0].received_by.name, 'جابي أ');
  assert.equal(ownerWorkspace.summary.remaining_iqd, 123000);

  const db = getDatabase();
  assert.equal(
    db.prepare('SELECT COUNT(*) AS count FROM generator_invoice_payments').get().count,
    1
  );
});

test.after(() => {
  closeDatabase();
  fs.rmSync(tempDir, { recursive: true, force: true });
});
