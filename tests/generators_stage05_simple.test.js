const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'nukhba-generators-simple-monthly-'));
process.env.DB_FILE = path.join(tempDir, 'simple-monthly.sqlite3');
process.env.AUTH_TOKEN_SECRET = 'simple-monthly-test-secret';

const { closeDatabase, getDatabase } = require('../src/db');
const { provisionTenantOwnerForStage01, findAccountContext } = require('../src/modules/generators/generators.db');
const { loginGeneratorAccount } = require('../src/modules/generators/generators.auth.service');
const { verifyGeneratorAccessToken } = require('../src/modules/generators/generators.token');
const { createOwnerCollector, replaceOwnerCollectorAssignments } = require('../src/modules/generators/generators.collectors.service');
const { createOwnerGenerator, createOwnerRoute, createOwnerSubscriber } = require('../src/modules/generators/generators.domain.service');
const { createOwnerReadingPeriod, lockOwnerReadingPeriod } = require('../src/modules/generators/generators.readings.service');
const { recordSyncOperation } = require('../src/modules/generators/generators.sync.service');
const {
  listOwnerMonthlyPeriods,
  getOwnerMonthlyWorkspace,
  saveOwnerMonthlyPrice,
  createOwnerMonthlyInvoices
} = require('../src/modules/generators/generators.simple_billing.service');

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

test('simple monthly flow creates direct unpaid invoices without drafts or debt ledger', () => {
  const owner = provisionTenantOwnerForStage01({
    tenantName: 'مولدة النسخة الواضحة',
    username: 'simple-owner',
    password: 'simple-owner-secret',
    collectorLimit: 1
  });
  const auth = ownerAuth(owner);
  const generator = createOwnerGenerator(auth, { code: 'G-S', name: 'مولدة واضحة' });
  const route = createOwnerRoute(auth, { code: 'R-S', name: 'مسار واضح', generator_id: generator.id });
  const subscriber = createOwnerSubscriber(auth, {
    account_number: 'S-001',
    full_name: 'مشترك عشرة أمبير',
    generator_id: generator.id,
    route_id: route.id,
    meter_number: 'M-S-1',
    contracted_amperes: 10
  });
  const collector = createOwnerCollector(auth, {
    full_name: 'جابي واضح',
    username: 'simple-collector',
    password: 'simple-collector-secret'
  }).collector;
  replaceOwnerCollectorAssignments(auth, collector.id, {
    assignments: [{ type: 'generator', target_id: generator.id }]
  });
  const fieldAuth = collectorAuth('simple-collector', 'simple-collector-secret');

  const period = createOwnerReadingPeriod(auth, { period_key: '2026-07' });
  const reading = recordSyncOperation(fieldAuth, {
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
  assert.equal(reading.status, 'applied');
  lockOwnerReadingPeriod(auth, period.id, { confirm: true });

  let workspace = getOwnerMonthlyWorkspace(auth, period.id);
  assert.equal(workspace.summary.missing_price_count, 1);
  assert.equal(workspace.invoices.length, 0);

  saveOwnerMonthlyPrice(auth, period.id, generator.id, {
    price_per_amp_iqd: 12000,
    fixed_fee_iqd: 3000
  });

  const created = createOwnerMonthlyInvoices(auth, period.id, { confirm: true });
  assert.equal(created.created_count, 1);
  assert.equal(created.workspace.invoices[0].amount_iqd, 123000);
  assert.equal(created.workspace.invoices[0].debt_iqd, 123000);
  assert.equal(created.workspace.invoices[0].status, 'unpaid');

  const repeated = createOwnerMonthlyInvoices(auth, period.id, { confirm: true });
  assert.equal(repeated.created_count, 0);
  assert.equal(repeated.existing_count, 1);

  assert.throws(
    () => saveOwnerMonthlyPrice(auth, period.id, generator.id, {
      price_per_amp_iqd: 13000,
      fixed_fee_iqd: 0
    }),
    (error) => error.code === 'MONTHLY_PRICE_LOCKED'
  );

  assert.equal(listOwnerMonthlyPeriods(auth).periods[0].invoice_count, 1);
  const db = getDatabase();
  const tables = db.prepare(
    "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('generator_monthly_prices','generator_monthly_invoices') ORDER BY name"
  ).all();
  assert.equal(tables.length, 2);
  assert.equal(
    db.prepare("SELECT COUNT(*) AS count FROM sqlite_master WHERE type='table' AND name LIKE '%draft%'").get().count,
    0
  );
});

test.after(() => {
  closeDatabase();
  fs.rmSync(tempDir, { recursive: true, force: true });
});
