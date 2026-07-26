-- Nukhba Generators Mobile - Stage03 additive schema.
-- Isolated from existing manager/employee tables and safe to run repeatedly.
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

-- Stage03: real generators, routes, and subscribers. No billing or collection fields.
CREATE TABLE IF NOT EXISTS generator_units (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  code TEXT NOT NULL COLLATE NOCASE,
  name TEXT NOT NULL,
  area TEXT,
  address TEXT,
  capacity_kva REAL CHECK (capacity_kva IS NULL OR capacity_kva >= 0),
  phase_type TEXT NOT NULL DEFAULT 'unknown' CHECK (phase_type IN ('single', 'three', 'unknown')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance')),
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_units_tenant_code UNIQUE (tenant_id, code),
  CONSTRAINT fk_generator_units_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_generator_units_tenant_status ON generator_units(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_generator_units_tenant_name ON generator_units(tenant_id, name);

CREATE TABLE IF NOT EXISTS generator_routes (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  generator_unit_id INTEGER,
  code TEXT NOT NULL COLLATE NOCASE,
  name TEXT NOT NULL,
  area TEXT,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_routes_tenant_code UNIQUE (tenant_id, code),
  CONSTRAINT fk_generator_routes_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_routes_unit FOREIGN KEY (generator_unit_id)
    REFERENCES generator_units(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_generator_routes_tenant_status ON generator_routes(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_generator_routes_unit ON generator_routes(tenant_id, generator_unit_id);

CREATE TABLE IF NOT EXISTS generator_subscribers (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  generator_unit_id INTEGER NOT NULL,
  route_id INTEGER,
  account_number TEXT NOT NULL COLLATE NOCASE,
  full_name TEXT NOT NULL,
  phone TEXT,
  area TEXT,
  address TEXT,
  meter_number TEXT,
  contracted_amperes INTEGER NOT NULL DEFAULT 0 CHECK (contracted_amperes >= 0),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'disconnected')),
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_subscribers_tenant_account UNIQUE (tenant_id, account_number),
  CONSTRAINT fk_generator_subscribers_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_subscribers_unit FOREIGN KEY (generator_unit_id)
    REFERENCES generator_units(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_subscribers_route FOREIGN KEY (route_id)
    REFERENCES generator_routes(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_generator_subscribers_tenant_status ON generator_subscribers(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_generator_subscribers_unit ON generator_subscribers(tenant_id, generator_unit_id);
CREATE INDEX IF NOT EXISTS idx_generator_subscribers_route ON generator_subscribers(tenant_id, route_id);
CREATE INDEX IF NOT EXISTS idx_generator_subscribers_name ON generator_subscribers(tenant_id, full_name);
CREATE UNIQUE INDEX IF NOT EXISTS uq_generator_subscribers_meter
  ON generator_subscribers(tenant_id, meter_number)
  WHERE meter_number IS NOT NULL AND trim(meter_number) <> '';

-- Owner-managed collector assignments now reference verified Stage03 domain public IDs.
CREATE TABLE IF NOT EXISTS generator_collector_assignments (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  collector_account_id INTEGER NOT NULL,
  assignment_type TEXT NOT NULL CHECK (assignment_type IN ('generator', 'subscriber', 'route')),
  target_public_id TEXT NOT NULL,
  target_label TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  assigned_by_account_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_collector_assignment UNIQUE (
    tenant_id, collector_account_id, assignment_type, target_public_id
  ),
  CONSTRAINT fk_generator_assignment_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_assignment_collector FOREIGN KEY (collector_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_assignment_owner FOREIGN KEY (assigned_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_generator_assignments_collector
  ON generator_collector_assignments(tenant_id, collector_account_id, status);
CREATE INDEX IF NOT EXISTS idx_generator_assignments_target
  ON generator_collector_assignments(tenant_id, assignment_type, target_public_id);

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

CREATE TRIGGER IF NOT EXISTS trg_generator_units_updated_at
AFTER UPDATE ON generator_units
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE generator_units SET updated_at = datetime('now') WHERE id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_generator_routes_updated_at
AFTER UPDATE ON generator_routes
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE generator_routes SET updated_at = datetime('now') WHERE id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_generator_subscribers_updated_at
AFTER UPDATE ON generator_subscribers
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE generator_subscribers SET updated_at = datetime('now') WHERE id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_generator_assignments_updated_at
AFTER UPDATE ON generator_collector_assignments
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE generator_collector_assignments SET updated_at = datetime('now') WHERE id = OLD.id;
END;
