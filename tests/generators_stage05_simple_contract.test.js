const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

test('simple invoice source has one direct flow and no hidden financial workflow', () => {
  const schema = read('src/modules/generators/generators.simple_billing.schema.sql');
  const service = read('src/modules/generators/generators.simple_billing.service.js');
  const routes = read('src/modules/generators/generators.simple_billing.routes.js');

  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_monthly_prices/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_monthly_invoices/);
  assert.doesNotMatch(schema, /draft|reviewed|approved|debt_ledger|payment|receipt/i);

  assert.match(service, /createOwnerMonthlyInvoices/);
  assert.match(service, /invoice_is_debt: true/);
  assert.match(service, /INSERT OR IGNORE INTO generator_monthly_invoices/);
  assert.doesNotMatch(service, /billing_draft|draft_status|approveOwner|debtLedger|payment_credit/i);

  assert.match(routes, /\/owner\/monthly-billing\/periods/);
  assert.match(routes, /\/create-invoices/);
  assert.match(routes, /draft_workflow_enabled: false/);
  assert.match(routes, /separate_debt_ledger_enabled: false/);
  assert.doesNotMatch(routes, /\/approve|\/debt-ledger|\/collections|\/receipts/);
});

test('mobile shows one clear monthly invoice screen', () => {
  const app = read('mobile/generators_mobile/lib/app/app.dart');
  const page = read('mobile/generators_mobile/lib/features/simple_billing/presentation/owner_simple_billing_page.dart');
  const models = read('mobile/generators_mobile/lib/features/simple_billing/domain/simple_billing_models.dart');
  const owner = read('mobile/generators_mobile/lib/features/owner/presentation/owner_home_page.dart');

  assert.match(app, /SimpleBillingRepository/);
  assert.match(page, /فواتير الشهر/);
  assert.match(page, /إنشاء فواتير الشهر/);
  assert.match(page, /الفاتورة غير المسددة هي الدين/);
  assert.match(models, /MonthlyInvoice/);
  assert.match(owner, /فواتير الشهر/);

  const mobile = [app, page, models, owner].join('\n');
  assert.doesNotMatch(mobile, /BillingDraft|reviewed|approve|DebtLedger|دفتر ذمم|مسودات/);
  assert.doesNotMatch(mobile, /geolocator|latitude|longitude|GPS/i);
  assert.doesNotMatch(mobile, /whatsapp|notification|printer|print\(/i);
});
