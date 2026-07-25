const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'nukhba-generators-stage06-'));
process.env.DB_FILE = path.join(tempDir, 'stage06.sqlite3');
process.env.AUTH_TOKEN_SECRET = 'stage06-test-secret-change-me';

const { closeDatabase, getDatabase } = require('../src/db');
const { provisionTenantOwnerForStage01, findAccountContext } = require('../src/modules/generators/generators.db');
const { loginGeneratorAccount } = require('../src/modules/generators/generators.auth.service');
const { verifyGeneratorAccessToken } = require('../src/modules/generators/generators.token');
const { createOwnerCollector, replaceOwnerCollectorAssignments } = require('../src/modules/generators/generators.collectors.service');
const { createOwnerGenerator, createOwnerSubscriber } = require('../src/modules/generators/generators.domain.service');
const { createOwnerReadingPeriod, lockOwnerReadingPeriod } = require('../src/modules/generators/generators.readings.service');
const { recordSyncOperation } = require('../src/modules/generators/generators.sync.service');
const {
  upsertOwnerBillingTariff,
  generateOwnerBillingDrafts,
  getOwnerBillingWorkspace,
  updateOwnerBillingDraftStatus
} = require('../src/modules/generators/generators.billing.service');
const {
  approveOwnerBillingDraft,
  listOwnerInvoices,
  listOwnerDebtLedger
} = require('../src/modules/generators/generators.invoices.service');

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

function readingOperation(periodId, subscriberId, currentValue) {
  return {
    operation_uuid: crypto.randomUUID(),
    operation_type: 'reading.create',
    client_created_at: new Date().toISOString(),
    payload: { period_id: periodId, subscriber_id: subscriberId, previous_value: 0, current_value: currentValue }
  };
}

let authA;
let authB;
let draftId;

test('Stage06 approves a reviewed draft once and opens an immutable debt debit', () => {
  const ownerA = provisionTenantOwnerForStage01({
    tenantName: 'مؤسسة Stage06 A', username: 'stage06-owner-a', password: 'owner-secret-a', collectorLimit: 1
  });
  const ownerB = provisionTenantOwnerForStage01({
    tenantName: 'مؤسسة Stage06 B', username: 'stage06-owner-b', password: 'owner-secret-b', collectorLimit: 1
  });
  authA = ownerAuth(ownerA);
  authB = ownerAuth(ownerB);

  const generator = createOwnerGenerator(authA, { code: 'G06', name: 'مولدة Stage06' });
  const subscriber = createOwnerSubscriber(authA, {
    account_number: 'S06-1', full_name: 'مشترك Stage06', generator_id: generator.id,
    meter_number: 'M06-1', contracted_amperes: 10
  });
  const collector = createOwnerCollector(authA, {
    full_name: 'جابي Stage06', username: 'stage06-collector', password: 'collector-secret-06'
  }).collector;
  replaceOwnerCollectorAssignments(authA, collector.id, {
    assignments: [{ type: 'generator', target_id: generator.id }]
  });
  const collectorContext = collectorAuth('stage06-collector', 'collector-secret-06');

  const period = createOwnerReadingPeriod(authA, { period_key: '2026-07' });
  const reading = recordSyncOperation(collectorContext, readingOperation(period.id, subscriber.id, 100));
  assert.equal(reading.status, 'applied');
  lockOwnerReadingPeriod(authA, period.id, { confirm: true });
  upsertOwnerBillingTariff(authA, period.id, generator.id, {
    price_per_amp_iqd: 12000,
    fixed_fee_iqd: 3000
  });
  generateOwnerBillingDrafts(authA, period.id);
  const workspace = getOwnerBillingWorkspace(authA, period.id);
  draftId = workspace.drafts[0].id;
  assert.equal(workspace.drafts[0].amount_iqd, 123000);

  assert.throws(
    () => approveOwnerBillingDraft(authA, draftId, { confirm: true }),
    (error) => error.code === 'INVOICE_DRAFT_NOT_REVIEWED'
  );
  updateOwnerBillingDraftStatus(authA, draftId, { status: 'reviewed' });
  const approved = approveOwnerBillingDraft(authA, draftId, { confirm: true });
  assert.equal(approved.duplicate, false);
  assert.equal(approved.invoice.amount_iqd, 123000);
  assert.equal(approved.invoice.remaining_amount_iqd, 123000);
  assert.equal(approved.invoice.paid_amount_iqd, 0);
  assert.equal(approved.invoice.debt_status, 'open');
  assert.equal(approved.debt_entry.debit_iqd, 123000);
  assert.equal(approved.debt_entry.balance_after_iqd, 123000);
  assert.equal(approved.collection_enabled, false);
  assert.equal(approved.receipt_enabled, false);
  assert.equal(approved.cash_effect_applied, false);

  const duplicate = approveOwnerBillingDraft(authA, draftId, { confirm: true });
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.invoice.id, approved.invoice.id);

  const invoices = listOwnerInvoices(authA, { period_id: period.id });
  assert.equal(invoices.summary.invoice_count, 1);
  assert.equal(invoices.summary.remaining_amount_iqd, 123000);
  const ledger = listOwnerDebtLedger(authA);
  assert.equal(ledger.entries.length, 1);
  assert.equal(ledger.summary.total_receivables_iqd, 123000);

  assert.throws(
    () => updateOwnerBillingDraftStatus(authA, draftId, { status: 'draft' }),
    /BILLING_DRAFT_ALREADY_APPROVED/
  );
  const db = getDatabase();
  assert.throws(() => db.prepare('DELETE FROM generator_invoices').run(), /GENERATOR_INVOICE_IMMUTABLE/);
  assert.throws(() => db.prepare('UPDATE generator_debt_ledger_entries SET note = note').run(), /GENERATOR_DEBT_LEDGER_IMMUTABLE/);
});

test('Stage06 isolates tenants and keeps collection operations disabled', () => {
  assert.equal(listOwnerInvoices(authB).summary.invoice_count, 0);
  assert.equal(listOwnerDebtLedger(authB).summary.total_receivables_iqd, 0);
  assert.throws(
    () => approveOwnerBillingDraft(authB, draftId, { confirm: true }),
    (error) => error.code === 'BILLING_DRAFT_NOT_FOUND'
  );
  assert.throws(
    () => recordSyncOperation(authA, {
      operation_uuid: crypto.randomUUID(),
      operation_type: 'collection.create',
      client_created_at: new Date().toISOString(),
      payload: { amount_iqd: 50000 }
    }),
    (error) => error.code === 'STAGE06_OPERATION_NOT_ENABLED'
  );
  const db = getDatabase();
  const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('generator_invoices','generator_debt_ledger_entries') ORDER BY name").all();
  assert.equal(tables.length, 2);
  const audit = db.prepare("SELECT COUNT(*) AS count FROM generator_audit_logs WHERE action = 'generator.invoice.approved'").get();
  assert.equal(Number(audit.count), 1);
});

test.after(() => {
  closeDatabase();
  fs.rmSync(tempDir, { recursive: true, force: true });
});
