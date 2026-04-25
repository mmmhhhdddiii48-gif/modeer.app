const { connectDatabase, closeDatabase } = require('../src/db');
const { REQUIRED_TABLES } = require('../src/db/schema');

try {
  connectDatabase();
  console.log(`DB_INIT_OK tables=${REQUIRED_TABLES.join(',')}`);
  closeDatabase();
} catch (error) {
  console.error('DB_INIT_FAIL', error.message);
  process.exitCode = 1;
}
