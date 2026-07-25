const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

test('Stage04 server contract enables idempotent meter readings and keeps billing locked', () => {
  const db = read('src/modules/generators/generators.db.js');
  const schema = read('src/modules/generators/generators.readings.schema.sql');
  const readings = read('src/modules/generators/generators.readings.service.js');
  const sync = read('src/modules/generators/generators.sync.service.js');
  const routes = read('src/modules/generators/generators.routes.js');

  assert.match(db, /generators\.readings\.schema\.sql/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_reading_periods/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_meter_readings/);
  assert.match(schema, /UNIQUE \(tenant_id, period_id, subscriber_id\)/);
  assert.match(schema, /UNIQUE \(tenant_id, operation_uuid\)/);
  assert.match(schema, /status IN \('open', 'locked'\)/);
  assert.doesNotMatch(schema, /invoice|price_per_amp|collection_amount|profit/i);

  assert.match(routes, /\/owner\/reading-periods/);
  assert.match(routes, /\/owner\/meter-readings/);
  assert.match(routes, /\/collector\/readings\/context/);
  assert.match(routes, /ownerPermission\('readings\.manage'\)/);
  assert.match(routes, /collectorPermissions\([^)]*'readings\.create'/s);
  assert.match(routes, /financial_workflows_enabled: false/);

  assert.match(sync, /reading\.create/);
  assert.match(sync, /STAGE04_OPERATION_NOT_ENABLED/);
  assert.match(sync, /'conflict'/);
  assert.match(sync, /'rejected'/);
  assert.doesNotMatch(sync, /collection\.create['"]\s*\]/);
  assert.doesNotMatch(sync, /invoice\.create/);

  assert.match(readings, /METER_READING_PREVIOUS_CHANGED/);
  assert.match(readings, /METER_READING_ALREADY_EXISTS/);
  assert.match(readings, /METER_READING_PERIOD_NOT_OPEN/);
  assert.match(readings, /METER_READING_SUBSCRIBER_NOT_ASSIGNED/);
  assert.match(readings, /clientCreatedAt/);
  assert.match(readings, /server_received_at/);
  assert.match(readings, /auth\.tenantId/);
  assert.doesNotMatch(readings, /body\??\.(tenant_id|tenantId)/);
});

test('Stage04 Flutter contract stores readings locally, exposes sync states, and avoids restricted extras', () => {
  const config = read('mobile/generators_mobile/lib/core/config/app_config.dart');
  const localDb = read('mobile/generators_mobile/lib/core/database/local_database.dart');
  const sync = read('mobile/generators_mobile/lib/core/sync/sync_engine.dart');
  const repository = read('mobile/generators_mobile/lib/features/readings/data/reading_repository.dart');
  const api = read('mobile/generators_mobile/lib/features/readings/data/readings_api_client.dart');
  const collectorPage = read('mobile/generators_mobile/lib/features/readings/presentation/collector_readings_page.dart');
  const ownerPage = read('mobile/generators_mobile/lib/features/readings/presentation/owner_reading_periods_page.dart');
  const app = read('mobile/generators_mobile/lib/app/app.dart');

  assert.match(config, /https:\/\/modeer-app\.onrender\.com/);
  assert.match(localDb, /version: 2/);
  assert.match(localDb, /CREATE TABLE IF NOT EXISTS local_meter_readings/);
  assert.match(localDb, /UNIQUE\(tenant_id, period_id, subscriber_id\)/);
  assert.match(repository, /Uuid\(\)\.v4\(\)/);
  assert.match(repository, /operation_type': 'reading\.create'/);
  assert.match(repository, /sync_queue/);
  assert.match(repository, /local_meter_readings/);
  assert.match(sync, /IDEMPOTENCY_CONFLICT/);
  assert.match(sync, /status': 'conflict'/);
  assert.match(sync, /status': 'rejected'/);
  assert.match(api, /\/collector\/readings\/context/);
  assert.match(api, /\/owner\/reading-periods/);
  assert.match(api, /\/owner\/meter-readings/);
  assert.match(collectorPage, /بانتظار المزامنة|قيد الإرسال|تمت المزامنة|يوجد تعارض|فشلت/);
  assert.match(ownerPage, /قفل الدورة/);
  assert.match(app, /ReadingRepository/);

  const mobile = [localDb, sync, repository, api, collectorPage, ownerPage, app].join('\n');
  assert.doesNotMatch(mobile, /geolocator|latitude|longitude|GPS/i);
  assert.doesNotMatch(mobile, /whatsapp|notification|printer|print\(/i);
  assert.doesNotMatch(mobile, /price_per_amp|invoice\.create|collection\.create|profit/i);
});
