const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'nukhba-generators-stage02-'));
process.env.DB_FILE = path.join(tempDir, 'stage02.sqlite3');
process.env.AUTH_TOKEN_SECRET = 'stage02-test-secret-change-me';
process.env.GENERATOR_ACCESS_TOKEN_EXPIRES_IN = '15m';

const { closeDatabase, getDatabase } = require('../src/db');
const { provisionTenantOwnerForStage01, findAccountContext } = require('../src/modules/generators/generators.db');
const { loginGeneratorAccount, refreshGeneratorSession } = require('../src/modules/generators/generators.auth.service');
const { verifyGeneratorAccessToken } = require('../src/modules/generators/generators.token');
const {
  createOwnerCollector,
  listOwnerCollectors,
  getOwnerCollector,
  updateOwnerCollectorStatus,
  updateOwnerCollectorPermissions,
  resetOwnerCollectorPassword,
  replaceOwnerCollectorAssignments,
  listCollectorOwnAssignments
} = require('../src/modules/generators/generators.collectors.service');

function ownerAuth(owner) {
  return {
    accountId: Number(owner.id),
    accountPublicId: owner.public_id,
    tenantId: Number(owner.tenant_id),
    tenantPublicId: owner.tenant_public_id,
    role: 'owner',
    permissions: ['collectors.manage']
  };
}

function collectorAuth(username, password) {
  const session = loginGeneratorAccount({ login: username, password });
  const claims = verifyGeneratorAccessToken(session.access_token);
  const context = findAccountContext(Number(claims.sub));
  return {
    session,
    auth: {
      accountId: Number(context.id),
      accountPublicId: context.public_id,
      tenantId: Number(context.tenant_id),
      tenantPublicId: context.tenant_public_id,
      role: 'collector',
      permissions: session.permissions
    }
  };
}

test('Stage02 owner creates collectors within subscription limit and tenant isolation is enforced', () => {
  const ownerA = provisionTenantOwnerForStage01({ tenantName: 'مولدة أ', username: 'owner-a', password: 'owner-secret-a', fullName: 'صاحب أ', collectorLimit: 1 });
  const ownerB = provisionTenantOwnerForStage01({ tenantName: 'مولدة ب', username: 'owner-b', password: 'owner-secret-b', fullName: 'صاحب ب', collectorLimit: 2 });
  const authA = ownerAuth(ownerA);
  const authB = ownerAuth(ownerB);

  const createdA = createOwnerCollector(authA, {
    full_name: 'جابي أ', username: 'collector-a', phone: '07800000001', password: 'collector-secret-a'
  });
  assert.equal(createdA.collector.status, 'active');
  assert.equal(createdA.usage.limit, 1);
  assert.equal(createdA.usage.remaining_slots, 0);

  assert.throws(
    () => createOwnerCollector(authA, { full_name: 'جابي زائد', username: 'collector-extra', password: 'collector-secret-extra' }),
    (error) => error.code === 'GENERATOR_COLLECTOR_LIMIT_REACHED'
  );

  const createdB = createOwnerCollector(authB, {
    full_name: 'جابي ب', username: 'collector-b', phone: '07800000002', password: 'collector-secret-b'
  });
  assert.throws(
    () => getOwnerCollector(authA, createdB.collector.id),
    (error) => error.code === 'GENERATOR_COLLECTOR_NOT_FOUND'
  );
  assert.equal(listOwnerCollectors(authA).collectors.length, 1);
  assert.equal(listOwnerCollectors(authB).collectors.length, 1);

  const db = getDatabase();
  const stored = db.prepare('SELECT password_hash FROM generator_accounts WHERE public_id = ?').get(createdA.collector.id);
  assert.notEqual(stored.password_hash, 'collector-secret-a');
  assert.ok(stored.password_hash.startsWith('scrypt$'));
});

test('Stage02 permissions, assignment isolation, disable/reactivation, and password reset', () => {
  const db = getDatabase();
  const ownerA = db.prepare("SELECT a.*, t.public_id AS tenant_public_id FROM generator_accounts a JOIN generator_tenants t ON t.id = a.tenant_id WHERE a.username = 'owner-a'").get();
  const ownerB = db.prepare("SELECT a.*, t.public_id AS tenant_public_id FROM generator_accounts a JOIN generator_tenants t ON t.id = a.tenant_id WHERE a.username = 'owner-b'").get();
  const authA = ownerAuth(ownerA);
  const authB = ownerAuth(ownerB);
  const collectorA = listOwnerCollectors(authA).collectors[0];
  const collectorB = listOwnerCollectors(authB).collectors[0];

  const loginA = collectorAuth('collector-a', 'collector-secret-a');
  assert.ok(loginA.session.permissions.includes('assignments.read'));

  const reduced = updateOwnerCollectorPermissions(authA, collectorA.id, { permissions: ['assignments.read', 'sync.own.read'] });
  assert.deepEqual(reduced.permissions, ['assignments.read', 'sync.own.read']);
  assert.throws(
    () => refreshGeneratorSession({ refresh_token: loginA.session.refresh_token }),
    (error) => error.code === 'INVALID_REFRESH_TOKEN'
  );
  assert.throws(
    () => updateOwnerCollectorPermissions(authA, collectorA.id, { permissions: ['reports.read'] }),
    (error) => error.code === 'INVALID_COLLECTOR_PERMISSION'
  );

  replaceOwnerCollectorAssignments(authA, collectorA.id, {
    assignments: [
      { type: 'route', target_id: 'route-zone-a', label: 'مسار حي الأمير' },
      { type: 'subscriber', target_id: 'subscriber-001', label: 'المشترك الأول', metadata: { note: 'Stage02 reference only' } }
    ]
  });
  replaceOwnerCollectorAssignments(authB, collectorB.id, {
    assignments: [{ type: 'route', target_id: 'route-zone-b', label: 'مسار ب' }]
  });

  const refreshedLoginA = collectorAuth('collector-a', 'collector-secret-a');
  const ownAssignments = listCollectorOwnAssignments(refreshedLoginA.auth);
  assert.equal(ownAssignments.assignments.length, 2);
  assert.ok(ownAssignments.assignments.every((item) => item.target_id !== 'route-zone-b'));

  const disabled = updateOwnerCollectorStatus(authA, collectorA.id, { status: 'disabled' });
  assert.equal(disabled.collector.status, 'disabled');
  assert.equal(disabled.usage.remaining_slots, 1);
  assert.throws(
    () => loginGeneratorAccount({ login: 'collector-a', password: 'collector-secret-a' }),
    (error) => error.code === 'GENERATOR_ACCOUNT_INACTIVE'
  );

  const replacement = createOwnerCollector(authA, {
    full_name: 'جابي بديل', username: 'collector-a2', password: 'collector-secret-a2'
  });
  assert.equal(replacement.usage.remaining_slots, 0);
  assert.throws(
    () => updateOwnerCollectorStatus(authA, collectorA.id, { status: 'active' }),
    (error) => error.code === 'GENERATOR_COLLECTOR_LIMIT_REACHED'
  );

  const oldSession = loginGeneratorAccount({ login: 'collector-a2', password: 'collector-secret-a2' });
  resetOwnerCollectorPassword(authA, replacement.collector.id, { new_password: 'collector-new-secret-a2' });
  assert.throws(
    () => refreshGeneratorSession({ refresh_token: oldSession.refresh_token }),
    (error) => error.code === 'INVALID_REFRESH_TOKEN'
  );
  assert.throws(
    () => loginGeneratorAccount({ login: 'collector-a2', password: 'collector-secret-a2' }),
    (error) => error.code === 'INVALID_CREDENTIALS'
  );
  assert.equal(loginGeneratorAccount({ login: 'collector-a2', password: 'collector-new-secret-a2' }).account.role, 'collector');

  const auditCount = db.prepare("SELECT COUNT(*) AS count FROM generator_audit_logs WHERE action LIKE 'generator.collector.%'").get();
  assert.ok(Number(auditCount.count) >= 8);
});

test.after(() => {
  closeDatabase();
  fs.rmSync(tempDir, { recursive: true, force: true });
});
