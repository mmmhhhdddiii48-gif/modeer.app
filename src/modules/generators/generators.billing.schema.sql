-- Nukhba Generators Mobile - Stage05 monthly billing draft schema.
-- Billing drafts are review-only and have no collection, debt, or payment side effects.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS generator_billing_tariffs (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  period_id INTEGER NOT NULL,
  generator_unit_id INTEGER NOT NULL,
  price_per_amp_iqd INTEGER NOT NULL CHECK (price_per_amp_iqd >= 0),
  fixed_fee_iqd INTEGER NOT NULL DEFAULT 0 CHECK (fixed_fee_iqd >= 0),
  calculation_method TEXT NOT NULL DEFAULT 'contracted_amperes' CHECK (calculation_method = 'contracted_amperes'),
  configured_by_account_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_billing_tariff UNIQUE (tenant_id, period_id, generator_unit_id),
  CONSTRAINT fk_generator_billing_tariff_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_billing_tariff_period FOREIGN KEY (period_id)
    REFERENCES generator_reading_periods(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_billing_tariff_generator FOREIGN KEY (generator_unit_id)
    REFERENCES generator_units(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_billing_tariff_actor FOREIGN KEY (configured_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_generator_billing_tariffs_period
  ON generator_billing_tariffs(tenant_id, period_id, generator_unit_id);

CREATE TABLE IF NOT EXISTS generator_monthly_billing_drafts (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  period_id INTEGER NOT NULL,
  subscriber_id INTEGER NOT NULL,
  meter_reading_id INTEGER NOT NULL,
  tariff_id INTEGER NOT NULL,
  generator_unit_id INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'reviewed')),
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
  calculation_method TEXT NOT NULL DEFAULT 'contracted_amperes' CHECK (calculation_method = 'contracted_amperes'),
  generated_by_account_id INTEGER NOT NULL,
  reviewed_by_account_id INTEGER,
  reviewed_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_billing_draft_subscriber UNIQUE (tenant_id, period_id, subscriber_id),
  CONSTRAINT uq_generator_billing_draft_reading UNIQUE (tenant_id, meter_reading_id),
  CONSTRAINT fk_generator_billing_draft_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_billing_draft_period FOREIGN KEY (period_id)
    REFERENCES generator_reading_periods(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_billing_draft_subscriber FOREIGN KEY (subscriber_id)
    REFERENCES generator_subscribers(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_billing_draft_reading FOREIGN KEY (meter_reading_id)
    REFERENCES generator_meter_readings(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_billing_draft_tariff FOREIGN KEY (tariff_id)
    REFERENCES generator_billing_tariffs(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_billing_draft_generator FOREIGN KEY (generator_unit_id)
    REFERENCES generator_units(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_billing_draft_generator_actor FOREIGN KEY (generated_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_billing_draft_reviewer FOREIGN KEY (reviewed_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_generator_billing_drafts_period
  ON generator_monthly_billing_drafts(tenant_id, period_id, status);
CREATE INDEX IF NOT EXISTS idx_generator_billing_drafts_subscriber
  ON generator_monthly_billing_drafts(tenant_id, subscriber_id);

CREATE TRIGGER IF NOT EXISTS trg_generator_billing_tariffs_updated_at
AFTER UPDATE ON generator_billing_tariffs
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE generator_billing_tariffs SET updated_at = datetime('now') WHERE id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_generator_billing_drafts_updated_at
AFTER UPDATE ON generator_monthly_billing_drafts
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE generator_monthly_billing_drafts SET updated_at = datetime('now') WHERE id = OLD.id;
END;
