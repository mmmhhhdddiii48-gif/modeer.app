const path = require('node:path');

try {
  const dotenv = require('dotenv');
  dotenv.config();
} catch (_) {
  // dotenv is optional before npm install. Environment variables still work normally.
}

function parseCorsOrigins(value) {
  if (!value) return [];
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

const ROOT_DIR = path.resolve(__dirname, '..', '..');
const DB_FILE = process.env.DB_FILE || './data/nukhba.sqlite';

const config = {
  env: process.env.NODE_ENV || 'development',
  server: {
    // Render يمرر PORT من البيئة، ويجب الربط على 0.0.0.0 في الإنتاج.
    host: process.env.HOST || ((process.env.NODE_ENV || '').toLowerCase() === 'production' ? '0.0.0.0' : '127.0.0.1'),
    port: Number(process.env.PORT || 4000)
  },
  database: {
    file: path.isAbsolute(DB_FILE) ? DB_FILE : path.resolve(ROOT_DIR, DB_FILE)
  },
  cors: {
    origins: parseCorsOrigins(process.env.CORS_ORIGIN || '')
  },
  auth: {
    tokenSecret: process.env.AUTH_TOKEN_SECRET || 'dev-only-change-this-secret',
    tokenExpiresIn: process.env.AUTH_TOKEN_EXPIRES_IN || '8h'
  }
};

module.exports = { config, ROOT_DIR };
