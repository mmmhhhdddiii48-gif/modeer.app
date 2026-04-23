-- Nukhba API - Phase 2 database schema
-- المطلوب في هذه المرحلة: جدولان فقط users و agents.
-- الملف idempotent ويمكن تشغيله أكثر من مرة بدون حذف أو تكرار البيانات.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  username TEXT NOT NULL COLLATE NOCASE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'agent' CHECK (role IN ('admin', 'agent')),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  can_login INTEGER NOT NULL DEFAULT 1 CHECK (can_login IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_users_username UNIQUE (username)
);

CREATE TABLE IF NOT EXISTS agents (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  employee_id TEXT NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT uq_agents_user_id UNIQUE (user_id),
  CONSTRAINT uq_agents_employee_id UNIQUE (employee_id),
  CONSTRAINT fk_agents_user_id FOREIGN KEY (user_id)
    REFERENCES users(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_agents_user_id ON agents(user_id);
CREATE INDEX IF NOT EXISTS idx_agents_employee_id ON agents(employee_id);

CREATE TRIGGER IF NOT EXISTS trg_users_updated_at
AFTER UPDATE ON users
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE users SET updated_at = datetime('now') WHERE id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_agents_updated_at
AFTER UPDATE ON agents
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE agents SET updated_at = datetime('now') WHERE id = OLD.id;
END;


-- Phase 8: central profile, notifications, messages, daily entries.
CREATE TABLE IF NOT EXISTS system_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  agent_id INTEGER,
  title TEXT NOT NULL,
  message TEXT,
  type TEXT NOT NULL DEFAULT 'general',
  priority TEXT NOT NULL DEFAULT 'normal',
  is_read INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  read_at TEXT,
  CONSTRAINT fk_notifications_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_notifications_agent_id FOREIGN KEY (agent_id) REFERENCES agents(id) ON UPDATE CASCADE ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_agent_id ON notifications(agent_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  agent_id INTEGER,
  sender_role TEXT NOT NULL CHECK (sender_role IN ('manager', 'agent')),
  sender_name TEXT,
  text TEXT,
  attachments_json TEXT NOT NULL DEFAULT '[]',
  is_read_by_manager INTEGER NOT NULL DEFAULT 0 CHECK (is_read_by_manager IN (0, 1)),
  is_read_by_agent INTEGER NOT NULL DEFAULT 0 CHECK (is_read_by_agent IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT fk_messages_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_messages_agent_id FOREIGN KEY (agent_id) REFERENCES agents(id) ON UPDATE CASCADE ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_messages_user_id ON messages(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_agent_id ON messages(agent_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

CREATE TABLE IF NOT EXISTS daily_entries (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  agent_id INTEGER NOT NULL,
  employee_id TEXT NOT NULL,
  entry_type TEXT NOT NULL CHECK (entry_type IN ('incoming', 'outgoing')),
  amount REAL NOT NULL DEFAULT 0,
  details TEXT,
  entry_date TEXT NOT NULL,
  attachments_json TEXT NOT NULL DEFAULT '[]',
  status TEXT NOT NULL DEFAULT 'open',
  created_by TEXT NOT NULL DEFAULT 'agent',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT fk_daily_entries_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_daily_entries_agent_id FOREIGN KEY (agent_id) REFERENCES agents(id) ON UPDATE CASCADE ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS idx_daily_entries_user_id ON daily_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_entries_agent_id ON daily_entries(agent_id);
CREATE INDEX IF NOT EXISTS idx_daily_entries_date ON daily_entries(entry_date);

CREATE TRIGGER IF NOT EXISTS trg_daily_entries_updated_at
AFTER UPDATE ON daily_entries
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE daily_entries SET updated_at = datetime('now') WHERE id = OLD.id;
END;

INSERT OR IGNORE INTO system_settings (key, value)
VALUES ('manager_profile', '{"name":"المدير","brand":"تطبيق النخبة","company":"تطبيق النخبة","phone":"","email":"","role":"مدير"}');
