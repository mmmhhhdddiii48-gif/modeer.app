const crypto = require('node:crypto');
const { config } = require('../config/env');
const { httpError } = require('./httpError');

function signAuthToken(user) {
  const now = Math.floor(Date.now() / 1000);
  const ttlSeconds = parseDurationSeconds(config.auth.tokenExpiresIn);
  const payload = {
    sub: String(user.id),
    username: user.username,
    role: user.role,
    iat: now,
    exp: now + ttlSeconds,
    iss: 'nukhba-api',
    aud: 'nukhba-agent-app'
  };
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signature = sign(encodedPayload);
  return `${encodedPayload}.${signature}`;
}

function verifyAuthToken(token) {
  if (typeof token !== 'string' || !token.includes('.')) {
    throw httpError(401, 'INVALID_TOKEN', 'Invalid or expired auth token.');
  }

  const [encodedPayload, signature] = token.split('.');
  if (!encodedPayload || !signature || !safeEqualText(signature, sign(encodedPayload))) {
    throw httpError(401, 'INVALID_TOKEN', 'Invalid or expired auth token.');
  }

  let payload;
  try {
    payload = JSON.parse(base64UrlDecode(encodedPayload));
  } catch (_) {
    throw httpError(401, 'INVALID_TOKEN', 'Invalid or expired auth token.');
  }

  const now = Math.floor(Date.now() / 1000);
  if (!payload.sub || payload.iss !== 'nukhba-api' || payload.aud !== 'nukhba-agent-app') {
    throw httpError(401, 'INVALID_TOKEN', 'Invalid or expired auth token.');
  }

  if (!Number.isFinite(Number(payload.exp)) || Number(payload.exp) <= now) {
    throw httpError(401, 'TOKEN_EXPIRED', 'Auth token has expired.');
  }

  return payload;
}

function readBearerToken(req) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw httpError(401, 'AUTH_REQUIRED', 'Authorization bearer token is required.');
  }
  return match[1].trim();
}

function sign(data) {
  return crypto
    .createHmac('sha256', config.auth.tokenSecret)
    .update(data)
    .digest('base64url');
}

function base64UrlEncode(value) {
  return Buffer.from(value, 'utf8').toString('base64url');
}

function base64UrlDecode(value) {
  return Buffer.from(value, 'base64url').toString('utf8');
}

function safeEqualText(a, b) {
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function parseDurationSeconds(value) {
  const raw = String(value || '8h').trim();
  const match = raw.match(/^(\d+)([smhd])?$/i);
  if (!match) return 8 * 60 * 60;
  const amount = Number(match[1]);
  const unit = (match[2] || 's').toLowerCase();
  const factor = { s: 1, m: 60, h: 3600, d: 86400 }[unit] || 1;
  return amount * factor;
}

module.exports = {
  signAuthToken,
  verifyAuthToken,
  readBearerToken
};
