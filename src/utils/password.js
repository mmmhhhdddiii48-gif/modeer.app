const crypto = require('node:crypto');

const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const KEY_LENGTH = 64;

function hashPassword(password) {
  assertPasswordInput(password);
  const salt = crypto.randomBytes(16).toString('base64url');
  const key = crypto.scryptSync(String(password), salt, KEY_LENGTH, {
    N: SCRYPT_N,
    r: SCRYPT_R,
    p: SCRYPT_P,
    maxmem: 64 * 1024 * 1024
  });
  return `scrypt$${SCRYPT_N}$${SCRYPT_R}$${SCRYPT_P}$${salt}$${key.toString('hex')}`;
}

function verifyPassword(password, passwordHash) {
  if (typeof password !== 'string' || typeof passwordHash !== 'string' || !passwordHash) return false;

  if (passwordHash.startsWith('scrypt$')) {
    return verifyScrypt(password, passwordHash);
  }

  // Compatibility for simple legacy hashes during migration only:
  // sha256$<salt>$<hex> or a raw 64-char sha256 hex.
  if (passwordHash.startsWith('sha256$')) {
    return verifySaltedSha256(password, passwordHash);
  }

  if (/^[a-f0-9]{64}$/i.test(passwordHash)) {
    const digest = crypto.createHash('sha256').update(password).digest('hex');
    return safeEqualHex(digest, passwordHash);
  }

  return false;
}

function verifyScrypt(password, stored) {
  const parts = stored.split('$');
  if (parts.length !== 6) return false;
  const [, nRaw, rRaw, pRaw, salt, expected] = parts;
  const N = Number(nRaw);
  const r = Number(rRaw);
  const p = Number(pRaw);

  if (!Number.isSafeInteger(N) || !Number.isSafeInteger(r) || !Number.isSafeInteger(p)) return false;
  if (!salt || !/^[a-f0-9]+$/i.test(expected)) return false;

  const key = crypto.scryptSync(password, salt, Buffer.from(expected, 'hex').length, {
    N,
    r,
    p,
    maxmem: 64 * 1024 * 1024
  });

  return safeEqualHex(key.toString('hex'), expected);
}

function verifySaltedSha256(password, stored) {
  const parts = stored.split('$');
  if (parts.length !== 3) return false;
  const [, salt, expected] = parts;
  if (!salt || !/^[a-f0-9]{64}$/i.test(expected)) return false;
  const digest = crypto.createHash('sha256').update(`${salt}:${password}`).digest('hex');
  return safeEqualHex(digest, expected);
}

function safeEqualHex(a, b) {
  try {
    const left = Buffer.from(String(a), 'hex');
    const right = Buffer.from(String(b), 'hex');
    if (left.length !== right.length) return false;
    return crypto.timingSafeEqual(left, right);
  } catch (_) {
    return false;
  }
}

function assertPasswordInput(password) {
  if (typeof password !== 'string' || password.length < 1) {
    throw new Error('Password must be a non-empty string');
  }
}

module.exports = {
  hashPassword,
  verifyPassword
};
