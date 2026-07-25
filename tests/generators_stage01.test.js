const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'nukhba-generators-stage01-'));
process.env.DB_FILE = path.join(tempDir, 'stage01.sqlite3');
process.env.AUTH_TOKEN_SECRET = 'stage01-test-secret-change-me';
process.env.GENERATOR_ACCESS_TOKEN_EXPIRES_IN = '15m';

const { closeDatabase } = require('../src/db');
const { provisionTenantOwnerForStage01 } = require('../src/modules/generators/generators.db');
const {
  loginGeneratorAccount,
  refreshGeneratorSession,
  getCurrentGeneratorContext
} = require('../src/modules/generators/generators.auth.service');
const { verifyGeneratorAccessToken } = require('../src/modules/generators/generators.token');
const { recordSyncOperation, getGeneratorSyncStatus } = require('../src/modules/generators/generators.sync.service');

test('Stage01 authentication, tenant isolation, and idempotency foundation remains intact', () => {
  const ownerA = provisionTenantOwnerForStage01({
    tenantName: 'مولدة أ', username: 'owner-a', password: 'secret-a', fullName: 'صاحب أ', collectorLimit: 3
  });
  const ownerB = provisionTenantOwnerForStage01({
    tenantName: 'مولدة ب', username: 'owner-b', password: 'secret-b', fullName: 'صاحب ب', collectorLimit: 2
  });

  const sessionA = loginGeneratorAccount({ login: 'owner-a', password: 'secret-a' });
  const sessionB = loginGeneratorAccount({ login: 'owner-b', password: 'secret-b' });
  const claimsA = verifyGeneratorAccessToken(sessionA.access_token);
  const claimsB = verifyGeneratorAccessToken(sessionB.access_token);

  assert.equal(claimsA.role, 'owner');
  assert.notEqual(claimsA.tid, claimsB.tid);
  assert.equal(getCurrentGeneratorContext(claimsA.sub).tenant.id, ownerA.tenant_public_id);
  assert.equal(getCurrentGeneratorContext(claimsB.sub).tenant.id, ownerB.tenant_public_id);

  const refreshedA = refreshGeneratorSession({ refresh_token: sessionA.refresh_token });
  assert.notEqual(refreshedA.refresh_token, sessionA.refresh_token, 'refresh token must rotate');
  assert.throws(
    () => refreshGeneratorSession({ refresh_token: sessionA.refresh_token }),
    (error) => error.code === 'INVALID_REFRESH_TOKEN'
  );

  const operationUuid = '4e1b9cc0-2d51-4a3c-9c8d-1518ed8a5a70';
  const authA = { accountId: Number(claimsA.sub), tenantId: Number(claimsA.tid), role: claimsA.role };
  const authB = { accountId: Number(claimsB.sub), tenantId: Number(claimsB.tid), role: claimsB.role };
  const operation = {
    operation_uuid: operationUuid,
    operation_type: 'sync.probe',
    client_created_at: new Date().toISOString(),
    payload: { device: 'test-device', sequence: 1 }
  };

  const first = recordSyncOperation(authA, operation);
  const duplicate = recordSyncOperation(authA, operation);
  assert.equal(first.duplicate, false);
  assert.equal(duplicate.duplicate, true);

  assert.throws(
    () => recordSyncOperation(authA, { ...operation, payload: { device: 'test-device', sequence: 2 } }),
    (error) => error.code === 'IDEMPOTENCY_CONFLICT'
  );

  assert.throws(
    () => recordSyncOperation(authA, {
      ...operation,
      operation_uuid: '8ed4b24d-1db8-45a7-b888-ddf465fb76ff',
      operation_type: 'collection.create',
      payload: { amount: 50000 }
    }),
    (error) => error.code === 'STAGE04_OPERATION_NOT_ENABLED'
  );

  const otherTenant = recordSyncOperation(authB, operation);
  assert.equal(otherTenant.duplicate, false, 'same UUID is isolated per tenant');
  assert.equal(getGeneratorSyncStatus(authA).received_count, 1);
  assert.equal(getGeneratorSyncStatus(authB).received_count, 1);
});

test.after(() => {
  closeDatabase();
  fs.rmSync(tempDir, { recursive: true, force: true });
});
