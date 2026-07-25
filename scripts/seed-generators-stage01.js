const { provisionTenantOwnerForStage01 } = require('../src/modules/generators/generators.db');
const { closeDatabase } = require('../src/db');

function required(name) {
  const value = String(process.env[name] || '').trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

try {
  const account = provisionTenantOwnerForStage01({
    tenantName: required('GENERATOR_TENANT_NAME'),
    username: required('GENERATOR_OWNER_USERNAME'),
    password: required('GENERATOR_OWNER_PASSWORD'),
    fullName: process.env.GENERATOR_OWNER_FULL_NAME || process.env.GENERATOR_TENANT_NAME,
    phone: process.env.GENERATOR_OWNER_PHONE || null,
    subscriptionStartsAt: process.env.GENERATOR_SUBSCRIPTION_STARTS_AT || null,
    subscriptionExpiresAt: process.env.GENERATOR_SUBSCRIPTION_EXPIRES_AT || null,
    collectorLimit: Number(process.env.GENERATOR_COLLECTOR_LIMIT || 1)
  });
  console.log(JSON.stringify({
    ok: true,
    tenant_public_id: account.tenant_public_id,
    account_public_id: account.public_id,
    username: account.username,
    role: account.role
  }, null, 2));
} finally {
  closeDatabase();
}
