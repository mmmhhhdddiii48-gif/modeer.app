const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'nukhba-generators-stage03-'));
process.env.DB_FILE = path.join(tempDir, 'stage03.sqlite3');
process.env.AUTH_TOKEN_SECRET = 'stage03-test-secret-change-me';

const { closeDatabase, getDatabase } = require('../src/db');
const { provisionTenantOwnerForStage01, findAccountContext } = require('../src/modules/generators/generators.db');
const { loginGeneratorAccount } = require('../src/modules/generators/generators.auth.service');
const { verifyGeneratorAccessToken } = require('../src/modules/generators/generators.token');
const { createOwnerCollector, replaceOwnerCollectorAssignments } = require('../src/modules/generators/generators.collectors.service');
const {
  createOwnerGenerator,
  updateOwnerGeneratorStatus,
  listOwnerGenerators,
  createOwnerRoute,
  updateOwnerRoute,
  updateOwnerRouteStatus,
  listOwnerRoutes,
  createOwnerSubscriber,
  updateOwnerSubscriber,
  updateOwnerSubscriberStatus,
  listOwnerSubscribers,
  listOwnerAssignmentCatalog,
  listCollectorAssignedDomain
} = require('../src/modules/generators/generators.domain.service');
const { recordSyncOperation } = require('../src/modules/generators/generators.sync.service');

function ownerAuth(owner) {
  return {
    accountId: Number(owner.id),
    accountPublicId: owner.public_id,
    tenantId: Number(owner.tenant_id),
    tenantPublicId: owner.tenant_public_id,
    role: 'owner',
    permissions: ['generators.manage', 'subscribers.manage', 'collectors.manage']
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

test('Stage03 creates tenant-isolated generators, routes, and subscribers with relationship validation', () => {
  const ownerA = provisionTenantOwnerForStage01({ tenantName: 'مؤسسة أ', username: 'stage03-owner-a', password: 'owner-secret-a', collectorLimit: 2 });
  const ownerB = provisionTenantOwnerForStage01({ tenantName: 'مؤسسة ب', username: 'stage03-owner-b', password: 'owner-secret-b', collectorLimit: 2 });
  const authA = ownerAuth(ownerA);
  const authB = ownerAuth(ownerB);

  const generatorA = createOwnerGenerator(authA, {
    code: 'GEN-01', name: 'مولدة حي الأمير', area: 'حي الأمير', capacity_kva: 500, phase_type: 'three'
  });
  const generatorB = createOwnerGenerator(authB, {
    code: 'GEN-01', name: 'مولدة مؤسسة ب', capacity_kva: 350
  });
  assert.notEqual(generatorA.id, generatorB.id);
  assert.equal(listOwnerGenerators(authA).generators.length, 1);
  assert.equal(listOwnerGenerators(authB).generators.length, 1);

  assert.throws(
    () => createOwnerGenerator(authA, { code: 'GEN-01', name: 'مكرر' }),
    (error) => error.code === 'GENERATOR_CODE_EXISTS'
  );

  const routeA = createOwnerRoute(authA, {
    code: 'R-01', name: 'مسار الشارع الأول', generator_id: generatorA.id, area: 'حي الأمير'
  });
  const routeWithoutGenerator = createOwnerRoute(authA, { code: 'R-02', name: 'مسار غير مربوط' });
  assert.equal(routeA.generator.id, generatorA.id);
  assert.equal(listOwnerRoutes(authA).routes.length, 2);

  const subscriberA = createOwnerSubscriber(authA, {
    account_number: 'A-0001', full_name: 'علي حسن', phone: '07800000111',
    generator_id: generatorA.id, route_id: routeA.id, meter_number: 'MTR-001', contracted_amperes: 10
  });
  assert.equal(subscriberA.generator.id, generatorA.id);
  assert.equal(subscriberA.route.id, routeA.id);
  assert.equal(listOwnerSubscribers(authA).subscribers.length, 1);
  assert.equal(listOwnerSubscribers(authB).subscribers.length, 0);

  assert.throws(
    () => createOwnerSubscriber(authA, {
      account_number: 'A-0002', full_name: 'مشترك خاطئ', generator_id: generatorA.id,
      route_id: createOwnerRoute(authA, { code: 'R-03', name: 'مسار مولدة ثانية', generator_id: createOwnerGenerator(authA, { code: 'GEN-02', name: 'مولدة ثانية' }).id }).id
    }),
    (error) => error.code === 'GENERATOR_ROUTE_MISMATCH'
  );

  assert.throws(
    () => updateOwnerRoute(authA, routeA.id, { generator_id: createOwnerGenerator(authA, { code: 'GEN-03', name: 'مولدة ثالثة' }).id }),
    (error) => error.code === 'GENERATOR_ROUTE_IN_USE'
  );

  const movedSubscriber = updateOwnerSubscriber(authA, subscriberA.id, { route_id: routeWithoutGenerator.id });
  assert.equal(movedSubscriber.route.id, routeWithoutGenerator.id);
  assert.equal(movedSubscriber.generator.id, generatorA.id);

  const db = getDatabase();
  const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('generator_units','generator_routes','generator_subscribers') ORDER BY name").all();
  assert.equal(tables.length, 3);
});

test('Stage03 assignment targets are verified by the server and collector visibility follows route/subscriber scope', () => {
  const db = getDatabase();
  const owner = db.prepare("SELECT a.*, t.public_id AS tenant_public_id FROM generator_accounts a JOIN generator_tenants t ON t.id = a.tenant_id WHERE a.username = 'stage03-owner-a'").get();
  const auth = ownerAuth(owner);
  const generator = listOwnerGenerators(auth, { q: 'حي الأمير' }).generators[0];
  const routes = listOwnerRoutes(auth).routes;
  const route = routes.find((item) => item.code === 'R-01');
  const routeWithoutGenerator = routes.find((item) => item.code === 'R-02');
  const subscriber = listOwnerSubscribers(auth).subscribers[0];
  const collector = createOwnerCollector(auth, {
    full_name: 'جابي Stage03', username: 'stage03-collector', password: 'collector-secret-03'
  }).collector;

  assert.throws(
    () => replaceOwnerCollectorAssignments(auth, collector.id, {
      assignments: [{ type: 'route', target_id: 'forged-route-id', label: 'مزور' }]
    }),
    (error) => error.code === 'GENERATOR_ROUTE_NOT_FOUND'
  );

  const replaced = replaceOwnerCollectorAssignments(auth, collector.id, {
    assignments: [
      { type: 'route', target_id: route.id, label: 'اسم مزور من التطبيق' },
      { type: 'subscriber', target_id: subscriber.id, metadata: { tenant_id: 999 } }
    ]
  });
  assert.equal(replaced.assignments.length, 2);
  assert.equal(replaced.assignments.find((item) => item.type === 'route').label, route.name);
  assert.notEqual(replaced.assignments.find((item) => item.type === 'route').label, 'اسم مزور من التطبيق');

  const collectorDomain = listCollectorAssignedDomain(collectorAuth('stage03-collector', 'collector-secret-03'));
  assert.ok(collectorDomain.generators.some((item) => item.id === generator.id));
  assert.ok(collectorDomain.routes.some((item) => item.id === route.id));
  assert.ok(collectorDomain.subscribers.some((item) => item.id === subscriber.id));
  assert.equal(collectorDomain.financial_workflows_enabled, false);

  replaceOwnerCollectorAssignments(auth, collector.id, {
    assignments: [{ type: 'generator', target_id: generator.id }]
  });
  const generatorScope = listCollectorAssignedDomain(collectorAuth('stage03-collector', 'collector-secret-03'));
  assert.ok(generatorScope.generators.some((item) => item.id === generator.id));
  assert.ok(generatorScope.routes.some((item) => item.id === route.id));
  assert.ok(generatorScope.subscribers.some((item) => item.id === subscriber.id));

  updateOwnerRouteStatus(auth, routeWithoutGenerator.id, { status: 'inactive' });
  assert.throws(
    () => replaceOwnerCollectorAssignments(auth, collector.id, {
      assignments: [{ type: 'route', target_id: routeWithoutGenerator.id }]
    }),
    (error) => error.code === 'GENERATOR_ASSIGNMENT_TARGET_INACTIVE'
  );

  updateOwnerSubscriberStatus(auth, subscriber.id, { status: 'suspended' });
  const catalog = listOwnerAssignmentCatalog(auth, { type: 'subscriber' });
  assert.ok(!catalog.subscribers.some((item) => item.id === subscriber.id));

  updateOwnerGeneratorStatus(auth, generator.id, { status: 'maintenance' });
  assert.throws(
    () => replaceOwnerCollectorAssignments(auth, collector.id, {
      assignments: [{ type: 'generator', target_id: generator.id }]
    }),
    (error) => error.code === 'GENERATOR_ASSIGNMENT_TARGET_INACTIVE'
  );

  assert.throws(
    () => recordSyncOperation(auth, {
      operation_uuid: 'fd2fdb66-4742-48b6-b85f-0713a7f04fea',
      operation_type: 'reading.create',
      client_created_at: new Date().toISOString(),
      payload: { subscriber_id: subscriber.id, reading: 120 }
    }),
    (error) => error.code === 'STAGE03_OPERATION_NOT_ENABLED'
  );

  const audit = db.prepare("SELECT COUNT(*) AS count FROM generator_audit_logs WHERE action LIKE 'generator.domain.%'").get();
  assert.ok(Number(audit.count) >= 10);
});

test.after(() => {
  closeDatabase();
  fs.rmSync(tempDir, { recursive: true, force: true });
});
