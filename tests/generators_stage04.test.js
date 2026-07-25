const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'nukhba-generators-stage04-'));
process.env.DB_FILE = path.join(tempDir, 'stage04.sqlite3');
process.env.AUTH_TOKEN_SECRET = 'stage04-test-secret-change-me';

const { closeDatabase, getDatabase } = require('../src/db');
const { provisionTenantOwnerForStage01, findAccountContext } = require('../src/modules/generators/generators.db');
const { loginGeneratorAccount } = require('../src/modules/generators/generators.auth.service');
const { verifyGeneratorAccessToken } = require('../src/modules/generators/generators.token');
const { createOwnerCollector, replaceOwnerCollectorAssignments } = require('../src/modules/generators/generators.collectors.service');
const {
  createOwnerGenerator,
  createOwnerRoute,
  createOwnerSubscriber
} = require('../src/modules/generators/generators.domain.service');
const {
  createOwnerReadingPeriod,
  lockOwnerReadingPeriod,
  getCollectorReadingContext,
  listOwnerMeterReadings,
  listOwnerReadingPeriods
} = require('../src/modules/generators/generators.readings.service');
const { recordSyncOperation, getGeneratorSyncStatus } = require('../src/modules/generators/generators.sync.service');

function ownerAuth(owner) {
  return {
    accountId: Number(owner.id),
    accountPublicId: owner.public_id,
    tenantId: Number(owner.tenant_id),
    tenantPublicId: owner.tenant_public_id,
    role: 'owner',
    permissions: ['generators.manage', 'subscribers.manage', 'collectors.manage', 'readings.manage']
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

function readingOperation({ periodId, subscriberId, previousValue, currentValue, uuid = crypto.randomUUID() }) {
  return {
    operation_uuid: uuid,
    operation_type: 'reading.create',
    client_created_at: new Date().toISOString(),
    payload: {
      period_id: periodId,
      subscriber_id: subscriberId,
      previous_value: previousValue,
      current_value: currentValue,
      note: 'قراءة Offline'
    }
  };
}

let auth;
let collector;
let subscriber1;
let subscriber2;

test('Stage04 creates one open period and applies assigned offline readings idempotently', () => {
  const owner = provisionTenantOwnerForStage01({
    tenantName: 'مؤسسة Stage04', username: 'stage04-owner', password: 'owner-secret-04', collectorLimit: 2
  });
  auth = ownerAuth(owner);
  const generator = createOwnerGenerator(auth, { code: 'G04', name: 'مولدة Stage04' });
  const route = createOwnerRoute(auth, { code: 'R04', name: 'مسار Stage04', generator_id: generator.id });
  subscriber1 = createOwnerSubscriber(auth, {
    account_number: 'S04-1', full_name: 'مشترك أول', generator_id: generator.id,
    route_id: route.id, meter_number: 'M04-1'
  });
  subscriber2 = createOwnerSubscriber(auth, {
    account_number: 'S04-2', full_name: 'مشترك ثان', generator_id: generator.id,
    route_id: route.id, meter_number: 'M04-2'
  });
  collector = createOwnerCollector(auth, {
    full_name: 'جابي Stage04', username: 'stage04-collector', password: 'collector-secret-04'
  }).collector;
  replaceOwnerCollectorAssignments(auth, collector.id, {
    assignments: [{ type: 'generator', target_id: generator.id }]
  });
  const collectorContext = collectorAuth('stage04-collector', 'collector-secret-04');

  const period = createOwnerReadingPeriod(auth, { period_key: '2026-07' });
  assert.equal(period.status, 'open');
  assert.throws(
    () => createOwnerReadingPeriod(auth, { period_key: '2026-08' }),
    (error) => error.code === 'METER_READING_OPEN_PERIOD_EXISTS'
  );

  const context = getCollectorReadingContext(collectorContext);
  assert.equal(context.period.id, period.id);
  assert.equal(context.subscribers.length, 2);
  assert.equal(context.subscribers[0].previous_value, 0);

  const uuid = crypto.randomUUID();
  const operation = readingOperation({
    uuid, periodId: period.id, subscriberId: subscriber1.id, previousValue: 0, currentValue: 150
  });
  const applied = recordSyncOperation(collectorContext, operation);
  assert.equal(applied.status, 'applied');
  assert.equal(applied.response.reading.consumption, 150);

  const duplicate = recordSyncOperation(collectorContext, operation);
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.status, 'applied');

  assert.throws(
    () => recordSyncOperation(collectorContext, {
      ...operation,
      payload: { ...operation.payload, current_value: 151 }
    }),
    (error) => error.code === 'IDEMPOTENCY_CONFLICT'
  );

  const sameSubscriber = recordSyncOperation(collectorContext, readingOperation({
    periodId: period.id, subscriberId: subscriber1.id, previousValue: 0, currentValue: 150
  }));
  assert.equal(sameSubscriber.status, 'conflict');
  assert.equal(sameSubscriber.conflict_code, 'METER_READING_ALREADY_EXISTS');

  const ownerReadings = listOwnerMeterReadings(auth, { period_id: period.id });
  assert.equal(ownerReadings.readings.length, 1);
  assert.equal(ownerReadings.summary.total_consumption, 150);

  lockOwnerReadingPeriod(auth, period.id, { confirm: true });
  const rejected = recordSyncOperation(collectorContext, readingOperation({
    periodId: period.id, subscriberId: subscriber2.id, previousValue: 0, currentValue: 20
  }));
  assert.equal(rejected.status, 'rejected');
  assert.equal(rejected.conflict_code, 'METER_READING_PERIOD_NOT_OPEN');
});

test('Stage04 next period detects stale previous readings and remains financially locked', () => {
  const collectorContext = collectorAuth('stage04-collector', 'collector-secret-04');
  const period = createOwnerReadingPeriod(auth, { period_key: '2026-08' });
  const context = getCollectorReadingContext(collectorContext);
  const first = context.subscribers.find((item) => item.id === subscriber1.id);
  assert.equal(first.previous_value, 150);

  const stale = recordSyncOperation(collectorContext, readingOperation({
    periodId: period.id, subscriberId: subscriber1.id, previousValue: 0, currentValue: 170
  }));
  assert.equal(stale.status, 'conflict');
  assert.equal(stale.conflict_code, 'METER_READING_PREVIOUS_CHANGED');
  assert.equal(stale.response.error.details.server_previous_value, 150);

  const corrected = recordSyncOperation(collectorContext, readingOperation({
    periodId: period.id, subscriberId: subscriber1.id, previousValue: 150, currentValue: 170
  }));
  assert.equal(corrected.status, 'applied');
  assert.equal(corrected.response.reading.consumption, 20);

  assert.throws(
    () => recordSyncOperation(collectorContext, {
      operation_uuid: crypto.randomUUID(),
      operation_type: 'collection.create',
      client_created_at: new Date().toISOString(),
      payload: { amount: 50000 }
    }),
    (error) => error.code === 'STAGE04_OPERATION_NOT_ENABLED'
  );

  const status = getGeneratorSyncStatus(collectorContext);
  assert.ok(status.applied_count >= 2);
  assert.ok(status.conflict_count >= 2);
  assert.ok(status.rejected_count >= 1);
  assert.equal(listOwnerReadingPeriods(auth).periods.length, 2);

  const db = getDatabase();
  const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('generator_reading_periods','generator_meter_readings') ORDER BY name").all();
  assert.equal(tables.length, 2);
  const audit = db.prepare("SELECT COUNT(*) AS count FROM generator_audit_logs WHERE action LIKE 'generator.reading.%'").get();
  assert.ok(Number(audit.count) >= 4);
});

test.after(() => {
  closeDatabase();
  fs.rmSync(tempDir, { recursive: true, force: true });
});
