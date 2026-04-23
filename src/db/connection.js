const fs = require('node:fs');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');
const { config } = require('../config/env');
const logger = require('../utils/logger');
const { initializeDatabase } = require('./schema');

let db = null;

function ensureDatabaseDirectory(filePath) {
  const dir = path.dirname(filePath);
  fs.mkdirSync(dir, { recursive: true });
}

function connectDatabase() {
  if (db) return db;

  ensureDatabaseDirectory(config.database.file);
  db = new DatabaseSync(config.database.file);

  db.exec(`
    PRAGMA foreign_keys = ON;
    PRAGMA journal_mode = WAL;
    PRAGMA busy_timeout = 5000;
  `);

  initializeDatabase(db);

  logger.info('SQLite connected', { file: config.database.file });
  return db;
}

function getDatabase() {
  if (!db) return connectDatabase();
  return db;
}

function closeDatabase() {
  if (!db) return;
  db.close();
  db = null;
  logger.info('SQLite connection closed');
}

module.exports = {
  connectDatabase,
  getDatabase,
  closeDatabase
};
