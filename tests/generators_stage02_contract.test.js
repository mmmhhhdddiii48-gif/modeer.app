const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

test('Stage02 source contract preserves server and mobile boundaries through Stage06', () => {
  const routes = read('src/modules/generators/generators.routes.js');
  const collectors = fs.readdirSync(path.join(root, 'src/modules/generators'))
    .filter((name) => name.startsWith('generators.collectors.') && name.endsWith('.js'))
    .map((name) => read(`src/modules/generators/${name}`))
    .join('\n');
  const sync = read('src/modules/generators/generators.sync.service.js');
  const appConfig = read('mobile/generators_mobile/lib/core/config/app_config.dart');
  const repository = read('mobile/generators_mobile/lib/features/owner/data/collector_repository.dart');
  const ownerPage = read('mobile/generators_mobile/lib/features/owner/presentation/owner_home_page.dart');
  const collectorPage = read('mobile/generators_mobile/lib/features/collector/presentation/collector_home_page.dart');

  assert.match(appConfig, /https:\/\/modeer-app\.onrender\.com/);
  assert.match(appConfig, /generatorsBasePath = '\/generators'/);
  assert.doesNotMatch(routes, /\/register|self-register/i);
  assert.match(routes, /\/owner\/collectors/);
  assert.match(routes, /\/collector\/assignments/);
  assert.match(routes, /requireGeneratorAuth/);
  assert.match(routes, /ownerPermission\('collectors\.manage'\)/);

  assert.doesNotMatch(collectors, /body\??\.(tenant_id|tenantId)/);
  assert.match(collectors, /auth\.tenantId/);
  assert.match(collectors, /GENERATOR_COLLECTOR_LIMIT_REACHED/);
  assert.match(collectors, /revokeAllRefreshTokensForAccount/);
  assert.match(collectors, /generator\.collector\./);

  assert.match(sync, /STAGE06_OPERATION_NOT_ENABLED/);
  assert.doesNotMatch(sync, /collection\.create['"]\s*\]/);

  assert.match(repository, /LocalDatabase/);
  assert.match(repository, /stage02\.collectors/);
  assert.match(repository, /stage02\.assignments/);
  assert.match(ownerPage, /إدارة الجباة/);
  assert.match(collectorPage, /المهام والتخصيصات/);

  const stage02Mobile = [repository, ownerPage, collectorPage].join('\n');
  assert.doesNotMatch(stage02Mobile, /geolocator|latitude|longitude|GPS/i);
  assert.doesNotMatch(stage02Mobile, /whatsapp|notification|printer|print\(/i);
});
