-- Nukhba Generators Mobile - Simple monthly invoices.
-- Direct flow: locked readings -> price per amp -> unpaid invoices.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS generator_monthly_prices (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  period_id INTEGER NOT NULL,
  generator_unit_id INTEGER NOT NULL,
  price_per_amp_iqd INTEGER NOT NULL CHECK (price_per_amp_iqd >= 0),
  fixed_fee_iqd INTEGER NOT NULL DEFAULT 0 CHECK (fixed_fee_iqd >= 0),
  configured_by_account_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_monthly_price UNIQUE (tenant_id, period_id, generator_unit_id),
  CONSTRAINT fk_generator_monthly_price_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_monthly_price_period FOREIGN KEY (period_id)
    REFERENCES generator_reading_periods(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_monthly_price_generator FOREIGN KEY (generator_unit_id)
    REFERENCES generator_units(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_monthly_price_actor FOREIGN KEY (configured_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS generator_monthly_invoices (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  period_id INTEGER NOT NULL,
  subscriber_id INTEGER NOT NULL,
  meter_reading_id INTEGER NOT NULL,
  generator_unit_id INTEGER NOT NULL,
  invoice_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'unpaid' CHECK (status = 'unpaid'),
  subscriber_name_snapshot TEXT NOT NULL,
  account_number_snapshot TEXT NOT NULL,
  meter_number_snapshot TEXT,
  generator_name_snapshot TEXT NOT NULL,
  contracted_amperes_snapshot INTEGER NOT NULL CHECK (contracted_amperes_snapshot >= 0),
  price_per_amp_iqd_snapshot INTEGER NOT NULL CHECK (price_per_amp_iqd_snapshot >= 0),
  fixed_fee_iqd_snapshot INTEGER NOT NULL CHECK (fixed_fee_iqd_snapshot >= 0),
  previous_value_snapshot REAL NOT NULL CHECK (previous_value_snapshot >= 0),
  current_value_snapshot REAL NOT NULL CHECK (current_value_snapshot >= previous_value_snapshot),
  consumption_snapshot REAL NOT NULL CHECK (consumption_snapshot >= 0),
  amount_iqd INTEGER NOT NULL CHECK (amount_iqd >= 0),
  created_by_account_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_monthly_invoice_subscriber UNIQUE (tenant_id, period_id, subscriber_id),
  CONSTRAINT uq_generator_monthly_invoice_reading UNIQUE (tenant_id, meter_reading_id),
  CONSTRAINT uq_generator_monthly_invoice_number UNIQUE (tenant_id, invoice_number),
  CONSTRAINT fk_generator_monthly_invoice_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_monthly_invoice_period FOREIGN KEY (period_id)
    REFERENCES generator_reading_periods(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_monthly_invoice_subscriber FOREIGN KEY (subscriber_id)
    REFERENCES generator_subscribers(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_monthly_invoice_reading FOREIGN KEY (meter_reading_id)
    REFERENCES generator_meter_readings(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_monthly_invoice_generator FOREIGN KEY (generator_unit_id)
    REFERENCES generator_units(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_monthly_invoice_actor FOREIGN KEY (created_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_generator_monthly_prices_period
  ON generator_monthly_prices(tenant_id, period_id, generator_unit_id);
CREATE INDEX IF NOT EXISTS idx_generator_monthly_invoices_period
  ON generator_monthly_invoices(tenant_id, period_id, status);
CREATE INDEX IF NOT EXISTS idx_generator_monthly_invoices_subscriber
  ON generator_monthly_invoices(tenant_id, subscriber_id);

CREATE TRIGGER IF NOT EXISTS trg_generator_monthly_prices_updated_at
AFTER UPDATE ON generator_monthly_prices
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE generator_monthly_prices SET updated_at = datetime('now') WHERE id = OLD.id;
END;
