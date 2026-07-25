const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

test('Stage03 domain contract stays tenant-scoped and additive through Stage06', () => {
  const schema = read('src/modules/generators/generators.schema.sql');
  const routes = read('src/modules/generators/generators.routes.js');
  const domain = fs.readdirSync(path.join(root, 'src/modules/generators'))
    .filter((name) => name.startsWith('generators.domain.') && name.endsWith('.js'))
    .map((name) => read(`src/modules/generators/${name}`))
    .join('\n');
  const collectors = fs.readdirSync(path.join(root, 'src/modules/generators'))
    .filter((name) => name.startsWith('generators.collectors.') && name.endsWith('.js'))
    .map((name) => read(`src/modules/generators/${name}`))
    .join('\n');
  const sync = read('src/modules/generators/generators.sync.service.js');

  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_units/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_routes/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS generator_subscribers/);
  assert.match(schema, /FOREIGN KEY \(generator_unit_id\)/);
  assert.match(schema, /FOREIGN KEY \(route_id\)/);
  assert.doesNotMatch(schema, /invoice|collection_amount|price_per_amp|profit/i);

  assert.match(routes, /\/owner\/generators/);
  assert.match(routes, /\/owner\/routes/);
  assert.match(routes, /\/owner\/subscribers/);
  assert.match(routes, /\/owner\/assignment-catalog/);
  assert.match(routes, /\/collector\/domain/);
  assert.doesNotMatch(routes, /\.delete\(|router\.delete|generatorsRouter\.delete/);
  assert.doesNotMatch(routes, /\/register|self-register/i);

  assert.match(domain, /auth\.tenantId/);
  assert.doesNotMatch(domain, /body\??\.(tenant_id|tenantId)/);
  assert.match(domain, /GENERATOR_ROUTE_MISMATCH/);
  assert.match(domain, /GENERATOR_ROUTE_IN_USE/);
  assert.match(domain, /GENERATOR_ASSIGNMENT_TARGET_INACTIVE/);
  assert.match(domain, /financial_workflows_enabled: false/);
  assert.match(collectors, /resolveAssignmentTarget/);
  assert.doesNotMatch(collectors, /item\?\.label/);

  assert.match(sync, /STAGE06_OPERATION_NOT_ENABLED/);
  assert.match(sync, /reading\.create/);
  assert.doesNotMatch(sync, /collection\.create['"]\s*\]/);
});

test('Stage03 mobile domain remains one Flutter app with offline cache and no restricted extras', () => {
  const appConfig = read('mobile/generators_mobile/lib/core/config/app_config.dart');
  const api = read('mobile/generators_mobile/lib/core/network/api_client.dart');
  const domainRepository = read('mobile/generators_mobile/lib/features/domain/data/domain_repository.dart');
  const domainModels = read('mobile/generators_mobile/lib/features/domain/domain/generator_domain.dart');
  const ownerPage = read('mobile/generators_mobile/lib/features/domain/presentation/domain_management_page.dart');
  const collectorPage = read('mobile/generators_mobile/lib/features/collector/presentation/collector_home_page.dart');
  const assignmentsPage = read('mobile/generators_mobile/lib/features/owner/presentation/collector_assignments_page.dart');

  assert.match(appConfig, /https:\/\/modeer-app\.onrender\.com/);
  assert.match(api, /\/owner\/generators/);
  assert.match(api, /\/owner\/routes/);
  assert.match(api, /\/owner\/subscribers/);
  assert.match(api, /\/collector\/domain/);
  assert.match(domainRepository, /LocalDatabase/);
  assert.match(domainRepository, /stage03\.domain/);
  assert.match(domainModels, /GeneratorUnit/);
  assert.match(domainModels, /GeneratorRoute/);
  assert.match(domainModels, /GeneratorSubscriber/);
  assert.match(ownerPage, /إدارة المولدات والمسارات والمشتركين/);
  assert.match(assignmentsPage, /assignmentCatalog/);
  assert.match(collectorPage, /المشتركين المكلف بهم/);

  const mobile = [api, domainRepository, ownerPage, collectorPage, assignmentsPage].join('\n');
  assert.doesNotMatch(mobile, /geolocator|latitude|longitude|GPS/i);
  assert.doesNotMatch(mobile, /whatsapp|notification|printer|print\(/i);
  assert.doesNotMatch(mobile, /invoice|profit|expense|collection amount/i);
});
