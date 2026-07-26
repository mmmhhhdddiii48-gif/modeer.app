const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

test('Stage07 collector payment source enforces assignment and remains online-only', () => {
  const routes = read('src/modules/generators/generators.simple_billing.routes.js');
  const service = read('src/modules/generators/generators.collector_payments.service.js');
  const collectorPage = read(
    'mobile/generators_mobile/lib/features/simple_billing/presentation/collector_payments_page.dart'
  );
  const collectorHome = read(
    'mobile/generators_mobile/lib/features/collector/presentation/collector_home_page.dart'
  );
  const login = read(
    'mobile/generators_mobile/lib/features/auth/presentation/login_page.dart'
  );
  const api = read(
    'mobile/generators_mobile/lib/features/simple_billing/data/simple_billing_api_client.dart'
  );

  assert.match(routes, /\/collector\/collections\/invoices/);
  assert.match(routes, /collections\.own\.read/);
  assert.match(routes, /collections\.create/);
  assert.match(routes, /receipts\.create/);
  assert.match(service, /COLLECTOR_INVOICE_NOT_ASSIGNED/);
  assert.match(service, /generator_collector_assignments/);
  assert.match(service, /assignment_type = 'subscriber'/);
  assert.match(service, /assignment_type = 'route'/);
  assert.match(service, /assignment_type = 'generator'/);
  assert.match(service, /PAYMENT_OPERATION_CONFLICT/);
  assert.match(service, /receiver_role/);
  assert.doesNotMatch(service, /body\??\.(tenant_id|tenantId)/);

  assert.match(api, /\/collector\/collections\/invoices/);
  assert.match(collectorPage, /تحصيل الفواتير/);
  assert.match(collectorPage, /تحصيل الفواتير يحتاج اتصالًا/);
  assert.match(collectorHome, /simpleBillingRepository/);
  assert.match(collectorHome, /تحصيل الفواتير/);
  assert.match(login, /simpleBillingRepository: widget\.simpleBillingRepository/);

  const mobile = [collectorPage, collectorHome, login, api].join('\n');
  assert.doesNotMatch(mobile, /geolocator|latitude|longitude|GPS/i);
  assert.doesNotMatch(mobile, /whatsapp|notification|printer|print\(/i);
  assert.doesNotMatch(collectorPage, /sync_queue|local_invoice_payment|offline payment/i);
});
