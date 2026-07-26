-- Nukhba Generators Mobile - Stage06 simple payments.
-- One invoice, one visible payment history, no separate debt ledger.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS generator_invoice_payments (
  id INTEGER PRIMARY KEY,
  public_id TEXT NOT NULL UNIQUE,
  tenant_id INTEGER NOT NULL,
  invoice_id INTEGER NOT NULL,
  operation_uuid TEXT NOT NULL,
  receipt_number TEXT NOT NULL,
  amount_iqd INTEGER NOT NULL CHECK (amount_iqd > 0),
  payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'transfer')),
  note TEXT,
  received_by_account_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_generator_invoice_payment_operation UNIQUE (tenant_id, operation_uuid),
  CONSTRAINT uq_generator_invoice_payment_receipt UNIQUE (tenant_id, receipt_number),
  CONSTRAINT fk_generator_invoice_payment_tenant FOREIGN KEY (tenant_id)
    REFERENCES generator_tenants(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_invoice_payment_invoice FOREIGN KEY (invoice_id)
    REFERENCES generator_monthly_invoices(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_generator_invoice_payment_actor FOREIGN KEY (received_by_account_id)
    REFERENCES generator_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_generator_invoice_payments_invoice
  ON generator_invoice_payments(tenant_id, invoice_id, created_at);
CREATE INDEX IF NOT EXISTS idx_generator_invoice_payments_received
  ON generator_invoice_payments(tenant_id, created_at);
