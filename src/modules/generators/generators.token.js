const crypto = require('node:crypto');
const { config } = require('../../config/env');
const { httpError } = require('../../utils/httpError');

const ISSUER = 'nukhba-api';
const AUDIENCE = 'nukhba-generators-mobile';

function signGeneratorAccessToken(context) {
  const now = Math.floor(Date.now() / 1000);
  const ttlSeconds = parseDurationSeconds(process.env.GENERATOR_ACCESS_TOKEN_EXPIRES_IN || '15m');
  const payload = {
    sub: String(context.id),
    tid: context.tenant_id == null ? null : String(context.tenant_id),
    role: context.role,
    type: 'generator_access',
    iat: now,
    exp: now + ttlSeconds,
    iss: ISSUER,
    aud: AUDIENCE
  };
  const encodedPayload = Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  return {
    token: `${encodedPayload}.${sign(encodedPayload)}`,
    expiresIn: ttlSeconds
  };
}

function verifyGeneratorAccessToken(token) {
  if (typeof token !== 'string' || !token.includes('.')) {
    throw httpError(401, 'INVALID_GENERATOR_TOKEN', 'Invalid or expired generator access token.');
  }
  const [encodedPayload, signature] = token.split('.');
  if (!encodedPayload || !signature || !safeEqualText(signature, sign(encodedPayload))) {
    throw httpError(401, 'INVALID_GENERATOR_TOKEN', 'Invalid or expired generator access token.');
  }

  let payload;
  try {
    payload = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8'));
  } catch (_) {
    throw httpError(401, 'INVALID_GENERATOR_TOKEN', 'Invalid or expired generator access token.');
  }

  const now = Math.floor(Date.now() / 1000);
  if (payload.iss !== ISSUER || payload.aud !== AUDIENCE || payload.type !== 'generator_access' || !payload.sub) {
    throw httpError(401, 'INVALID_GENERATOR_TOKEN', 'Invalid or expired generator access token.');
  }
  if (!Number.isFinite(Number(payload.exp)) || Number(payload.exp) <= now) {
    throw httpError(401, 'GENERATOR_TOKEN_EXPIRED', 'Generator access token has expired.');
  }
  return payload;
}

function createRawRefreshToken() {
  return crypto.randomBytes(48).toString('base64url');
}

function hashRefreshToken(token) {
  return crypto.createHash('sha256').update(String(token || '')).digest('hex');
}

function refreshTokenExpiryIso() {
  const days = Number(process.env.GENERATOR_REFRESH_TOKEN_DAYS || 30);
  const safeDays = Number.isFinite(days) && days > 0 ? days : 30;
  return new Date(Date.now() + safeDays * 24 * 60 * 60 * 1000).toISOString();
}

function readBearerToken(req) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) throw httpError(401, 'GENERATOR_AUTH_REQUIRED', 'Generator bearer token is required.');
  return match[1].trim();
}

function sign(data) {
  return crypto
    .createHmac('sha256', `${config.auth.tokenSecret}:generators-mobile`)
    .update(data)
    .digest('base64url');
}

function safeEqualText(a, b) {
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function parseDurationSeconds(value) {
  const match = String(value || '').trim().match(/^(\d+)([smhd])?$/i);
  if (!match) return 15 * 60;
  const amount = Number(match[1]);
  const unit = (match[2] || 's').toLowerCase();
  return amount * ({ s: 1, m: 60, h: 3600, d: 86400 }[unit] || 1);
}

module.exports = {
  signGeneratorAccessToken,
  verifyGeneratorAccessToken,
  createRawRefreshToken,
  hashRefreshToken,
  refreshTokenExpiryIso,
  readBearerToken
};
