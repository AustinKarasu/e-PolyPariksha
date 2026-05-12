const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { query } = require('../config/db');
const { env } = require('../config/env');
const { ApiError } = require('../utils/api-error');

async function login(identifier, password, context = {}) {
  const rows = await query(
    `SELECT u.id, u.full_name, u.email, u.college_id, u.password_hash, u.role,
            u.branch_id, u.is_active, u.dob, u.semester, u.roll_no, u.board_roll_no,
            u.college_name, u.course_name, u.guardian_name, u.phone, u.address,
            u.admission_year, u.photo_url, u.two_factor_enabled, u.two_factor_secret,
            u.is_primary_admin,
            b.name AS branch_name, b.code AS branch_code
     FROM users u
     LEFT JOIN branches b ON b.id = u.branch_id
     WHERE u.email = $1 OR u.college_id = $1
     LIMIT 1`,
    [identifier]
  );

  const user = rows[0];
  if (!user || !user.is_active) {
    throw new ApiError(401, 'Invalid credentials');
  }

  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) {
    throw new ApiError(401, 'Invalid credentials');
  }

  if (user.two_factor_enabled) {
    if (!context.totpCode || !verifyTotp(context.totpCode, user.two_factor_secret)) {
      return { requiresTwoFactor: true, user: sanitizeUser(user) };
    }
  }

  const jti = crypto.randomUUID();
  const token = jwt.sign(
    { sub: user.id, role: user.role, branchId: user.branch_id, jti },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn }
  );
  const decoded = jwt.decode(token);

  await query(
    `INSERT INTO auth_sessions (user_id, token_jti, device_label, ip_address, user_agent, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [user.id, jti, context.deviceLabel || null, context.ipAddress || null, context.userAgent || null, new Date(decoded.exp * 1000).toISOString()]
  );

  return { token, user: sanitizeUser(user) };
}

async function getCurrentUser(userId) {
  const rows = await query(
    `SELECT u.id, u.full_name, u.email, u.college_id, u.role,
            u.branch_id, u.dob, u.semester, u.roll_no, u.board_roll_no,
            u.college_name, u.course_name, u.guardian_name, u.phone, u.address,
            u.admission_year, u.photo_url, u.two_factor_enabled, u.is_primary_admin,
            b.name AS branch_name, b.code AS branch_code
     FROM users u
     LEFT JOIN branches b ON b.id = u.branch_id
     WHERE u.id = $1 AND u.is_active = true
     LIMIT 1`,
    [userId]
  );

  if (!rows[0]) {
    throw new ApiError(401, 'User account is inactive or no longer exists');
  }
  return rows[0];
}

async function setupTwoFactor(userId) {
  const user = await getCurrentUser(userId);
  const secret = generateBase32Secret();
  await query('UPDATE users SET two_factor_secret = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [secret, userId]);
  const label = encodeURIComponent(`PolyH.T:${user.email || user.college_id || user.id}`);
  const otpauthUrl = `otpauth://totp/${label}?secret=${secret}&issuer=PolyH.T&algorithm=SHA1&digits=6&period=30`;
  return { secret, otpauthUrl };
}

async function enableTwoFactor(userId, code) {
  const rows = await query('SELECT two_factor_secret FROM users WHERE id = $1 LIMIT 1', [userId]);
  const secret = rows[0]?.two_factor_secret;
  if (!secret) throw new ApiError(422, 'Start 2FA setup before enabling it');
  if (!verifyTotp(code, secret)) throw new ApiError(422, 'Invalid authenticator code');
  await query('UPDATE users SET two_factor_enabled = TRUE, updated_at = CURRENT_TIMESTAMP WHERE id = $1', [userId]);
  return getCurrentUser(userId);
}

async function disableTwoFactor(userId, code) {
  const rows = await query('SELECT two_factor_secret, two_factor_enabled FROM users WHERE id = $1 LIMIT 1', [userId]);
  const user = rows[0];
  if (!user?.two_factor_enabled) return getCurrentUser(userId);
  if (!verifyTotp(code, user.two_factor_secret)) throw new ApiError(422, 'Invalid authenticator code');
  await query('UPDATE users SET two_factor_enabled = FALSE, two_factor_secret = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = $1', [userId]);
  return getCurrentUser(userId);
}

async function logout(user) {
  if (!user?.jti) return;
  await query(
    'UPDATE auth_sessions SET revoked_at = CURRENT_TIMESTAMP WHERE token_jti = $1',
    [user.jti]
  );
}

function sanitizeUser(user) {
  const copy = { ...user };
  delete copy.password_hash;
  delete copy.two_factor_secret;
  return copy;
}

module.exports = { login, getCurrentUser, setupTwoFactor, enableTwoFactor, disableTwoFactor, logout };

const base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function generateBase32Secret(length = 32) {
  const bytes = crypto.randomBytes(length);
  let secret = '';
  for (const byte of bytes) {
    secret += base32Alphabet[byte % base32Alphabet.length];
  }
  return secret;
}

function base32ToBuffer(secret) {
  const clean = secret.replace(/=+$/, '').replace(/\s+/g, '').toUpperCase();
  let bits = '';
  for (const char of clean) {
    const value = base32Alphabet.indexOf(char);
    if (value < 0) continue;
    bits += value.toString(2).padStart(5, '0');
  }
  const bytes = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) {
    bytes.push(parseInt(bits.slice(i, i + 8), 2));
  }
  return Buffer.from(bytes);
}

function totp(secret, step = Math.floor(Date.now() / 30000)) {
  const counter = Buffer.alloc(8);
  counter.writeUInt32BE(Math.floor(step / 0x100000000), 0);
  counter.writeUInt32BE(step & 0xffffffff, 4);
  const hmac = crypto.createHmac('sha1', base32ToBuffer(secret)).update(counter).digest();
  const offset = hmac[hmac.length - 1] & 0xf;
  const code = ((hmac[offset] & 0x7f) << 24)
    | ((hmac[offset + 1] & 0xff) << 16)
    | ((hmac[offset + 2] & 0xff) << 8)
    | (hmac[offset + 3] & 0xff);
  return String(code % 1000000).padStart(6, '0');
}

function verifyTotp(code, secret) {
  const clean = String(code || '').replace(/\s+/g, '');
  const nowStep = Math.floor(Date.now() / 30000);
  return [-1, 0, 1].some((offset) => totp(secret, nowStep + offset) === clean);
}
