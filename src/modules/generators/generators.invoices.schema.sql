-- Nukhba Generators Mobile - Stage06 approved invoices and debt-ledger schema.
-- Invoice approval opens a receivable ledger debit, but collection and receipts remain disabled.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS generator_invoices (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  invoice_number TEXT NOT NULL,
  period_id INTEGER NOT NULL,
  subscriber_id INTEGER NOT NULL,
  billing_draft_id INTEGER NOT NULL,
  meter_reading_id INTEGER NOT NULL,
  generator_unit_id INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'approved' CHECK (status = 'approved'),
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
  approved_by_account_id INTEGER NOT NULL,
  approved_at TEXT NOT NULL DEFAULT (datetime('now')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_invoice_number UNIQUE (tenant_id, invoice_number),
  CONSTRAINT uq_generator_invoice_draft UNIQUE (tenant_id, billing_draft_id),
  CONSTRAINT uq_generator_invoice_period_subscriber UNIQUE (tenant_id, period_id, subscriber_id),
  CONSTRAINT fk_generator_invoice_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_invoice_period FOREIGN KEY (period_id)
    REFERENCES generator_reading_periods(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_invoice_subscriber FOREIGN KEY (subscriber_id)
    REFERENCES generator_subscribers(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_invoice_draft FOREIGN KEY (billing_draft_id)
    REFERENCES generator_monthly_billing_drafts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_invoice_reading FOREIGN KEY (meter_reading_id)
    REFERENCES generator_meter_readings(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_invoice_generator FOREIGN KEY (generator_unit_id)
    REFERENCES generator_units(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_invoice_approver FOREIGN KEY (approved_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_generator_invoices_period
  ON generator_invoices(tenant_id, period_id, approved_at);
CREATE INDEX IF NOT EXISTS idx_generator_invoices_subscriber
  ON generator_invoices(tenant_id, subscriber_id, approved_at);

CREATE TABLE IF NOT EXISTS generator_debt_ledger_entries (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  subscriber_id INTEGER NOT NULL,
  invoice_id INTEGER,
  entry_type TEXT NOT NULL CHECK (entry_type IN ('invoice_debit', 'payment_credit', 'adjustment_debit', 'adjustment_credit')),
  debit_iqd INTEGER NOT NULL DEFAULT 0 CHECK (debit_iqd >= 0),
  credit_iqd INTEGER NOT NULL DEFAULT 0 CHECK (credit_iqd >= 0),
  balance_after_iqd INTEGER NOT NULL CHECK (balance_after_iqd >= 0),
  note TEXT,
  created_by_account_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  CHECK (NOT (debit_iqd > 0 AND credit_iqd > 0)),
  CONSTRAINT fk_generator_debt_ledger_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_debt_ledger_subscriber FOREIGN KEY (subscriber_id)
    REFERENCES generator_subscribers(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_debt_ledger_invoice FOREIGN KEY (invoice_id)
    REFERENCES generator_invoices(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_debt_ledger_actor FOREIGN KEY (created_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_generator_debt_invoice_debit
  ON generator_debt_ledger_entries(tenant_id, invoice_id)
  WHERE entry_type = 'invoice_debit';
CREATE INDEX IF NOT EXISTS idx_generator_debt_ledger_subscriber
  ON generator_debt_ledger_entries(tenant_id, subscriber_id, created_at, id);
CREATE INDEX IF NOT EXISTS idx_generator_debt_ledger_invoice
  ON generator_debt_ledger_entries(tenant_id, invoice_id, created_at, id);

CREATE TRIGGER IF NOT EXISTS trg_generator_invoices_immutable_update
BEFORE UPDATE ON generator_invoices
BEGIN
  SELECT RAISE(ABORT, 'GENERATOR_INVOICE_IMMUTABLE');
END;

CREATE TRIGGER IF NOT EXISTS trg_generator_invoices_immutable_delete
BEFORE DELETE ON generator_invoices
BEGIN
  SELECT RAISE(ABORT, 'GENERATOR_INVOICE_IMMUTABLE');
END;

CREATE TRIGGER IF NOT EXISTS trg_generator_debt_ledger_immutable_update
BEFORE UPDATE ON generator_debt_ledger_entries
BEGIN
  SELECT RAISE(ABORT, 'GENERATOR_DEBT_LEDGER_IMMUTABLE');
END;

CREATE TRIGGER IF NOT EXISTS trg_generator_debt_ledger_immutable_delete
BEFORE DELETE ON generator_debt_ledger_entries
BEGIN
  SELECT RAISE(ABORT, 'GENERATOR_DEBT_LEDGER_IMMUTABLE');
END;

CREATE TRIGGER IF NOT EXISTS trg_generator_approved_billing_draft_status_lock
BEFORE UPDATE OF status ON generator_monthly_billing_drafts
FOR EACH ROW
WHEN EXISTS (
  SELECT 1 FROM generator_invoices i
  WHERE i.tenant_id = OLD.tenant_id AND i.billing_draft_id = OLD.id
)
BEGIN
  SELECT RAISE(ABORT, 'BILLING_DRAFT_ALREADY_APPROVED');
END;
