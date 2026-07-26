-- Nukhba Generators Mobile - Stage04 meter-reading additive schema.
-- Safe to execute repeatedly after generators.schema.sql.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS generator_reading_periods (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  period_key TEXT NOT NULL,
  title TEXT NOT NULL,
  starts_at TEXT NOT NULL,
  ends_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'locked')),
  opened_by_account_id INTEGER NOT NULL,
  locked_by_account_id INTEGER,
  locked_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_reading_period_key UNIQUE (tenant_id, period_key),
  CONSTRAINT fk_generator_reading_period_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_reading_period_opened_by FOREIGN KEY (opened_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_reading_period_locked_by FOREIGN KEY (locked_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_generator_reading_one_open_period
  ON generator_reading_periods(tenant_id)
  WHERE status = 'open';
CREATE INDEX IF NOT EXISTS idx_generator_reading_period_tenant_status
  ON generator_reading_periods(tenant_id, status, period_key);

CREATE TABLE IF NOT EXISTS generator_meter_readings (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  period_id INTEGER NOT NULL,
  subscriber_id INTEGER NOT NULL,
  collector_account_id INTEGER NOT NULL,
  operation_uuid TEXT NOT NULL,
  previous_value REAL NOT NULL CHECK (previous_value >= 0),
  current_value REAL NOT NULL CHECK (current_value >= previous_value),
  consumption REAL NOT NULL CHECK (consumption >= 0),
  subscriber_name_snapshot TEXT NOT NULL,
  account_number_snapshot TEXT NOT NULL,
  meter_number_snapshot TEXT,
  note TEXT,
  client_created_at TEXT NOT NULL,
  server_received_at TEXT NOT NULL DEFAULT (datetime('now')),
  status TEXT NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_meter_reading_period_subscriber UNIQUE (tenant_id, period_id, subscriber_id),
  CONSTRAINT uq_generator_meter_reading_operation UNIQUE (tenant_id, operation_uuid),
  CONSTRAINT fk_generator_meter_reading_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_meter_reading_period FOREIGN KEY (period_id)
    REFERENCES generator_reading_periods(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_meter_reading_subscriber FOREIGN KEY (subscriber_id)
    REFERENCES generator_subscribers(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_meter_reading_collector FOREIGN KEY (collector_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_generator_meter_reading_period
  ON generator_meter_readings(tenant_id, period_id, server_received_at);
CREATE INDEX IF NOT EXISTS idx_generator_meter_reading_subscriber
  ON generator_meter_readings(tenant_id, subscriber_id, period_id);
CREATE INDEX IF NOT EXISTS idx_generator_meter_reading_collector
  ON generator_meter_readings(tenant_id, collector_account_id, server_received_at);

CREATE TRIGGER IF NOT EXISTS trg_generator_reading_periods_updated_at
AFTER UPDATE ON generator_reading_periods
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE generator_reading_periods SET updated_at = datetime('now') WHERE id = OLD.id;
END;
