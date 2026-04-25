const { connectDatabase, closeDatabase } = require('../src/db');
const { REQUIRED_TABLES } = require('../src/db/schema');

try {
  const db = connectDatabase();
  const row = db.prepare('SELECT 1 AS ok').get();
  if (!row || row.ok !== 1) {
    throw new Error('SQLite check failed');
  }

  const placeholders = REQUIRED_TABLES.map(() => '?').join(', ');
  const tables = db
    .prepare(`SELECT name FROM sqlite_master WHERE type = 'table' AND name IN (${placeholders}) ORDER BY name`)
    .all(...REQUIRED_TABLES)
    .map((item) => item.name);

  const missing = REQUIRED_TABLES.filter((table) => !tables.includes(table));
  if (missing.length) {
    throw new Error(`Missing required tables: ${missing.join(', ')}`);
  }

  console.log(`DB_CHECK_OK tables=${REQUIRED_TABLES.join(',')}`);
  closeDatabase();
} catch (error) {
  console.error('DB_CHECK_FAIL', error.message);
  process.exitCode = 1;
}
