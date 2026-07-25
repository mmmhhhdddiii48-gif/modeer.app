const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
function read(relativePath) { return fs.readFileSync(path.join(root, relativePath), 'utf8'); }

test('Stage05 billing source is tenant-scoped, deterministic, and collection-locked', () => {
  const schema = read('src/modules/generators/generators.billing.schema.sql');
  const service = read('src/modules/generators/generators.billing.service.js');
  const routes = read('src/modules/generators/generators.routes.js');
  const sync = read('src/modules/generators/generators.sync.service.js');

  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_billing_tariffs/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_monthly_billing_drafts/);
  assert.match(schema, /contracted_amperes_snapshot/);
  assert.match(schema, /price_per_amp_iqd_snapshot/);
  assert.match(schema, /amount_iqd/);
  assert.doesNotMatch(schema, /paid_amount|remaining_amount|debt_amount|cash_amount|receipt_number/i);

  assert.match(service, /auth\.tenantId/);
  assert.match(service, /BILLING_PERIOD_NOT_LOCKED/);
  assert.match(service, /BILLING_TARIFF_LOCKED_BY_DRAFTS/);
  assert.match(service, /INSERT OR IGNORE INTO generator_monthly_billing_drafts/);
  assert.match(service, /financial_effect_applied: false/);
  assert.doesNotMatch(service, /body\??\.(tenant_id|tenantId)/);

  assert.match(routes, /\/owner\/billing\/periods/);
  assert.match(routes, /\/owner\/billing\/drafts/);
  assert.match(routes, /ownerPermission\('invoices\.manage'\)/);
  assert.doesNotMatch(routes, /\/owner\/collections|\/collector\/collections/);
  assert.doesNotMatch(sync, /collection\.create['"]\s*\]/);
});

test('Stage05 mobile exposes owner billing drafts without collector finance or restricted extras', () => {
  const appConfig = read('mobile/generators_mobile/lib/core/config/app_config.dart');
  const api = read('mobile/generators_mobile/lib/features/billing/data/billing_api_client.dart');
  const repository = read('mobile/generators_mobile/lib/features/billing/data/billing_repository.dart');
  const models = read('mobile/generators_mobile/lib/features/billing/domain/billing_models.dart');
  const page = fs.readdirSync(path.join(root, 'mobile/generators_mobile/lib/features/billing/presentation'))
    .filter((name) => name.startsWith('owner_billing_') && name.endsWith('.dart'))
    .map((name) => read(`mobile/generators_mobile/lib/features/billing/presentation/${name}`))
    .join('\n');
  const owner = read('mobile/generators_mobile/lib/features/owner/presentation/owner_home_page.dart');

  assert.match(appConfig, /https:\/\/modeer-app\.onrender\.com/);
  assert.match(api, /\/owner\/billing\/periods/);
  assert.match(repository, /stage05\.billing/);
  assert.match(models, /BillingDraft/);
  assert.match(page, /التسعير ومسودات الفواتير/);
  assert.match(page, /لا توجد ذمم أو قبض أو وصولات/);
  assert.match(owner, /التسعير ومسودات الفواتير/);

  const mobile = [api, repository, models, page, owner].join('\n');
  assert.doesNotMatch(mobile, /geolocator|latitude|longitude|GPS/i);
  assert.doesNotMatch(mobile, /whatsapp|notification|printer|print\(/i);
  assert.doesNotMatch(mobile, /collection\.create|paid_amount|remaining_amount|cash drawer/i);
});
