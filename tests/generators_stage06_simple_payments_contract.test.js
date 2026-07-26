const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

test('Stage06 simple payments stay inside the invoice screen without a debt ledger', () => {
  const schema = read('src/modules/generators/generators.simple_payments.schema.sql');
  const service = read('src/modules/generators/generators.simple_payments.service.js');
  const routes = read('src/modules/generators/generators.simple_billing.routes.js');
  const models = read('mobile/generators_mobile/lib/features/simple_billing/domain/simple_billing_models.dart');
  const api = read('mobile/generators_mobile/lib/features/simple_billing/data/simple_billing_api_client.dart');
  const page = read('mobile/generators_mobile/lib/features/simple_billing/presentation/owner_simple_billing_page.dart');

  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_invoice_payments/);
  assert.match(schema, /operation_uuid/);
  assert.match(schema, /receipt_number/);
  assert.doesNotMatch(schema, /debt_ledger|cash_box|shift_close/i);

  assert.match(service, /PAYMENT_EXCEEDS_REMAINING/);
  assert.match(service, /INVOICE_ALREADY_PAID/);
  assert.match(service, /generator\.invoice\.payment_recorded/);
  assert.match(service, /separate_debt_ledger_enabled: false/);
  assert.doesNotMatch(service, /deleteOwner|refund|reversePayment/);

  assert.match(routes, /\/owner\/monthly-billing\/invoices\/:invoiceId\/payments/);
  assert.match(routes, /simple_payments_enabled: true/);
  assert.match(routes, /separate_cash_box_enabled: false/);

  assert.match(models, /paidAmountIqd/);
  assert.match(models, /remainingAmountIqd/);
  assert.match(models, /InvoicePayment/);
  assert.match(api, /recordPayment/);
  assert.match(page, /تسجيل دفعة/);
  assert.match(page, /الإجمالي/);
  assert.match(page, /المدفوع/);
  assert.match(page, /المتبقي/);
  assert.doesNotMatch(page, /دفتر الذمم|اعتماد الفاتورة|مراجعة المسودة/);
});
