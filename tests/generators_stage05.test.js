const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'nukhba-generators-stage05-'));
process.env.DB_FILE = path.join(tempDir, 'stage05.sqlite3');
process.env.AUTH_TOKEN_SECRET = 'stage05-test-secret-change-me';

const { closeDatabase, getDatabase } = require('../src/db');
const { provisionTenantOwnerForStage01, findAccountContext } = require('../src/modules/generators/generators.db');
const { loginGeneratorAccount } = require('../src/modules/generators/generators.auth.service');
const { verifyGeneratorAccessToken } = require('../src/modules/generators/generators.token');
const { createOwnerCollector, replaceOwnerCollectorAssignments } = require('../src/modules/generators/generators.collectors.service');
const { createOwnerGenerator, createOwnerRoute, createOwnerSubscriber } = require('../src/modules/generators/generators.domain.service');
const { createOwnerReadingPeriod, lockOwnerReadingPeriod } = require('../src/modules/generators/generators.readings.service');
const { recordSyncOperation } = require('../src/modules/generators/generators.sync.service');
const {
  listOwnerBillingPeriods,
  getOwnerBillingWorkspace,
  upsertOwnerBillingTariff,
  generateOwnerBillingDrafts,
  updateOwnerBillingDraftStatus
} = require('../src/modules/generators/generators.billing.service');

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
      current_value: currentValue,
      note: 'Stage05 reading'
    }
  });
}

let auth;
let otherAuth;
let generator;
let period;

test('Stage05 calculates immutable review-only billing drafts from locked confirmed readings', () => {
  const owner = provisionTenantOwnerForStage01({
    tenantName: 'مؤسسة Stage05', username: 'stage05-owner', password: 'owner-secret-05', collectorLimit: 2
  });
  auth = ownerAuth(owner);
  generator = createOwnerGenerator(auth, { code: 'G05', name: 'مولدة Stage05' });
  const route = createOwnerRoute(auth, { code: 'R05', name: 'مسار Stage05', generator_id: generator.id });
  const first = createOwnerSubscriber(auth, {
    account_number: 'S05-1', full_name: 'مشترك عشرة أمبير', generator_id: generator.id,
    route_id: route.id, meter_number: 'M05-1', contracted_amperes: 10
  });
  const second = createOwnerSubscriber(auth, {
    account_number: 'S05-2', full_name: 'مشترك خمسة أمبير', generator_id: generator.id,
    route_id: route.id, meter_number: 'M05-2', contracted_amperes: 5
  });
  const collector = createOwnerCollector(auth, {
    full_name: 'جابي Stage05', username: 'stage05-collector', password: 'collector-secret-05'
  }).collector;
  replaceOwnerCollectorAssignments(auth, collector.id, {
    assignments: [{ type: 'generator', target_id: generator.id }]
  });
  const fieldAuth = collectorAuth('stage05-collector', 'collector-secret-05');

  period = createOwnerReadingPeriod(auth, { period_key: '2026-09' });
  pushReading(fieldAuth, period.id, first.id, 100);
  pushReading(fieldAuth, period.id, second.id, 50);

  assert.throws(
    () => upsertOwnerBillingTariff(auth, period.id, generator.id, { price_per_amp_iqd: 12000, fixed_fee_iqd: 3000 }),
    (error) => error.code === 'BILLING_PERIOD_NOT_LOCKED'
  );
  lockOwnerReadingPeriod(auth, period.id, { confirm: true });

  assert.throws(
    () => generateOwnerBillingDrafts(auth, period.id),
    (error) => error.code === 'BILLING_TARIFF_MISSING'
  );

  const tariff = upsertOwnerBillingTariff(auth, period.id, generator.id, {
    price_per_amp_iqd: 12000,
    fixed_fee_iqd: 3000
  });
  assert.equal(tariff.financial_effect_applied, false);

  const generated = generateOwnerBillingDrafts(auth, period.id);
  assert.equal(generated.created_count, 2);
  assert.equal(generated.workspace.summary.total_amount_iqd, 186000);
  const tenAmp = generated.workspace.drafts.find((item) => item.account_number === 'S05-1');
  const fiveAmp = generated.workspace.drafts.find((item) => item.account_number === 'S05-2');
  assert.equal(tenAmp.amount_iqd, 123000);
  assert.equal(fiveAmp.amount_iqd, 63000);
  assert.equal(tenAmp.financial_effect_applied, false);

  const repeated = generateOwnerBillingDrafts(auth, period.id);
  assert.equal(repeated.created_count, 0);
  assert.equal(repeated.existing_count, 2);

  assert.throws(
    () => upsertOwnerBillingTariff(auth, period.id, generator.id, { price_per_amp_iqd: 13000, fixed_fee_iqd: 0 }),
    (error) => error.code === 'BILLING_TARIFF_LOCKED_BY_DRAFTS'
  );

  const reviewed = updateOwnerBillingDraftStatus(auth, tenAmp.id, { status: 'reviewed' });
  assert.equal(reviewed.status, 'reviewed');
  const workspace = getOwnerBillingWorkspace(auth, period.id);
  assert.equal(workspace.summary.reviewed_count, 1);
  assert.equal(workspace.collection_enabled, false);
  assert.equal(workspace.debt_enabled, false);
});

test('Stage05 keeps tenant isolation while collection stays disabled through Stage06', () => {
  const otherOwner = provisionTenantOwnerForStage01({
    tenantName: 'مؤسسة Stage05 ب', username: 'stage05-owner-b', password: 'owner-secret-05b', collectorLimit: 1
  });
  otherAuth = ownerAuth(otherOwner);
  assert.throws(
    () => getOwnerBillingWorkspace(otherAuth, period.id),
    (error) => error.code === 'BILLING_PERIOD_NOT_FOUND'
  );
  assert.equal(listOwnerBillingPeriods(auth).periods.length, 1);

  assert.throws(
    () => recordSyncOperation(auth, {
      operation_uuid: crypto.randomUUID(),
      operation_type: 'collection.create',
      client_created_at: new Date().toISOString(),
      payload: { amount: 123000 }
    }),
    (error) => error.code === 'STAGE06_OPERATION_NOT_ENABLED'
  );

  const db = getDatabase();
  const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('generator_billing_tariffs','generator_monthly_billing_drafts') ORDER BY name").all();
  assert.equal(tables.length, 2);
  const audits = db.prepare("SELECT COUNT(*) AS count FROM generator_audit_logs WHERE action LIKE 'generator.billing.%'").get();
  assert.ok(Number(audits.count) >= 3);
});

test.after(() => {
  closeDatabase();
  fs.rmSync(tempDir, { recursive: true, force: true });
});
