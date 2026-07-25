-- Nukhba Generators Mobile - Stage01 additive schema.
-- This file is isolated from the existing manager/employee tables and is idempotent.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS generator_tenants (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'expired')),
  subscription_starts_at TEXT,
  subscription_expires_at TEXT,
  collector_limit INTEGER NOT NULL DEFAULT 1 CHECK (collector_limit >= 0),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS generator_accounts (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER,
  role TEXT NOT NULL CHECK (role IN ('platform_admin', 'owner', 'collector')),
  username TEXT NOT NULL COLLATE NOCASE UNIQUE,
  phone TEXT,
  full_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'disabled')),
  permissions_json TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT fk_generator_accounts_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_generator_accounts_tenant_role CHECK (
    (role = 'platform_admin' AND tenant_id IS NULL)
    OR (role IN ('owner', 'collector') AND tenant_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_generator_accounts_tenant ON generator_accounts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_generator_accounts_role ON generator_accounts(role);
CREATE UNIQUE INDEX IF NOT EXISTS uq_generator_accounts_phone
  ON generator_accounts(phone)
  WHERE phone IS NOT NULL AND trim(phone) <> '';

CREATE TABLE IF NOT EXISTS generator_refresh_tokens (
  id INTEGER PRIMARY KEY,
  account_id INTEGER NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  revoked_at TEXT,
  last_used_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT fk_generator_refresh_account FOREIGN KEY (account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_generator_refresh_account ON generator_refresh_tokens(account_id);
CREATE INDEX IF NOT EXISTS idx_generator_refresh_expiry ON generator_refresh_tokens(expires_at);

CREATE TABLE IF NOT EXISTS generator_sync_operations (
  id INTEGER PRIMARY KEY,
  tenant_id INTEGER NOT NULL,
  account_id INTEGER NOT NULL,
  operation_uuid TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  payload_hash TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  client_created_at TEXT NOT NULL,
  server_received_at TEXT NOT NULL DEFAULT (datetime('now')),
  status TEXT NOT NULL DEFAULT 'received' CHECK (status IN ('received', 'applied', 'rejected', 'conflict')),
  conflict_code TEXT,
  response_json TEXT NOT NULL DEFAULT '{}',
  CONSTRAINT uq_generator_sync_tenant_operation UNIQUE (tenant_id, operation_uuid),
  CONSTRAINT fk_generator_sync_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_sync_account FOREIGN KEY (account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_generator_sync_tenant_received ON generator_sync_operations(tenant_id, server_received_at);
CREATE INDEX IF NOT EXISTS idx_generator_sync_account ON generator_sync_operations(account_id);

CREATE TABLE IF NOT EXISTS generator_audit_logs (
  id INTEGER PRIMARY KEY,
  tenant_id INTEGER,
  actor_account_id INTEGER,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_uuid TEXT,
  before_json TEXT,
  after_json TEXT,
  client_created_at TEXT,
  server_created_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT fk_generator_audit_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_audit_actor FOREIGN KEY (actor_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_generator_audit_tenant_time ON generator_audit_logs(tenant_id, server_created_at);
CREATE INDEX IF NOT EXISTS idx_generator_audit_actor ON generator_audit_logs(actor_account_id);

CREATE TRIGGER IF NOT EXISTS trg_generator_tenants_updated_at
AFTER UPDATE ON generator_tenants
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE generator_tenants SET updated_at = datetime('now') WHERE id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_generator_accounts_updated_at
AFTER UPDATE ON generator_accounts
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE generator_accounts SET updated_at = datetime('now') WHERE id = OLD.id;
END;
