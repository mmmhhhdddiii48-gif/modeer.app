const fs = require('node:fs');
const path = require('node:path');
const logger = require('../utils/logger');

const SCHEMA_FILE = path.join(__dirname, 'schema.sql');
const REQUIRED_TABLES = ['users', 'agents', 'system_settings', 'notifications', 'messages', 'daily_entries', 'location_updates', 'day_closures'];

function readSchemaSql() {
  return fs.readFileSync(SCHEMA_FILE, 'utf8');
}

function initializeDatabase(db) {
  if (!db) {
    throw new Error('initializeDatabase requires an active SQLite database connection');
  }

  db.exec(readSchemaSql());

  const placeholders = REQUIRED_TABLES.map(() => '?').join(', ');
  const rows = db
    .prepare(`SELECT name FROM sqlite_master WHERE type = 'table' AND name IN (${placeholders}) ORDER BY name`)
    .all(...REQUIRED_TABLES);

  const found = new Set(rows.map((row) => row.name));
  const missing = REQUIRED_TABLES.filter((table) => !found.has(table));

  if (missing.length) {
    throw new Error(`Database schema initialization failed. Missing tables: ${missing.join(', ')}`);
  }

  logger.info('Database schema ready', { tables: REQUIRED_TABLES });
}

module.exports = {
  initializeDatabase,
  readSchemaSql,
  REQUIRED_TABLES
};
