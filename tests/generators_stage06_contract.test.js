const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
function read(relativePath) { return fs.readFileSync(path.join(root, relativePath), 'utf8'); }

test('Stage06 invoice and debt contract is immutable, tenant-scoped, and collection-locked', () => {
  const schema = read('src/modules/generators/generators.invoices.schema.sql');
  const service = read('src/modules/generators/generators.invoices.service.js');
  const routes = read('src/modules/generators/generators.stage06.routes.js');
  const index = read('src/modules/generators/index.js');
  const sync = read('src/modules/generators/generators.sync.service.js');

  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_invoices/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_debt_ledger_entries/);
  assert.match(schema, /invoice_debit/);
  assert.match(schema, /GENERATOR_INVOICE_IMMUTABLE/);
  assert.match(schema, /GENERATOR_DEBT_LEDGER_IMMUTABLE/);
  assert.match(schema, /BILLING_DRAFT_ALREADY_APPROVED/);
  assert.doesNotMatch(schema, /receipt_number|cash_drawer|collection_method/i);

  assert.match(service, /auth\.tenantId/);
  assert.match(service, /INVOICE_DRAFT_NOT_REVIEWED/);
  assert.match(service, /BEGIN IMMEDIATE/);
  assert.match(service, /debt_opened/);
  assert.match(service, /cash_effect_applied: false/);
  assert.doesNotMatch(service, /body\??\.(tenant_id|tenantId)/);

  assert.match(routes, /\/owner\/billing\/drafts\/:draftId\/approve/);
  assert.match(routes, /\/owner\/invoices/);
  assert.match(routes, /\/owner\/debt-ledger/);
  assert.match(index, /stage06Router/);
  assert.doesNotMatch(routes, /\/owner\/collections|\/collector\/collections/);
  assert.match(sync, /STAGE06_OPERATION_NOT_ENABLED/);
  assert.doesNotMatch(sync, /collection\.create['"]\s*\]/);
});

test('Stage06 mobile exposes owner invoice approval and debt ledger without collector collection', () => {
  const appConfig = read('mobile/generators_mobile/lib/core/config/app_config.dart');
  const api = read('mobile/generators_mobile/lib/features/invoices/data/invoice_api_client.dart');
  const repository = read('mobile/generators_mobile/lib/features/invoices/data/invoice_repository.dart');
  const models = read('mobile/generators_mobile/lib/features/invoices/domain/invoice_models.dart');
  const page = read('mobile/generators_mobile/lib/features/invoices/presentation/owner_invoices_page.dart');
  const widgets = read('mobile/generators_mobile/lib/features/invoices/presentation/owner_invoices_widgets.dart');
  const owner = read('mobile/generators_mobile/lib/features/owner/presentation/owner_home_page.dart');

  assert.match(appConfig, /https:\/\/modeer-app\.onrender\.com/);
  assert.match(api, /\/owner\/billing\/drafts\/\$draftId\/approve/);
  assert.match(api, /\/owner\/invoices/);
  assert.match(api, /\/owner\/debt-ledger/);
  assert.match(repository, /stage06\.invoices/);
  assert.match(repository, /stage06\.debt-ledger/);
  assert.match(models, /ApprovedInvoice/);
  assert.match(page, /الفواتير والذمم/);
  assert.match(widgets, /لا قبض، لا وصولات، ولا تأثير على الصندوق/);
  assert.match(owner, /الفواتير المعتمدة والذمم/);

  const mobile = [api, repository, models, page, widgets, owner].join('\n');
  assert.doesNotMatch(mobile, /geolocator|latitude|longitude|GPS/i);
  assert.doesNotMatch(mobile, /whatsapp|notification|printer|print\(/i);
  assert.doesNotMatch(mobile, /collection\.create|receipt_number|cash drawer/i);
});
