const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { query } = require('../config/db');
const { env } = require('../config/env');
const { ApiError } = require('../utils/api-error');
const storageService = require('./storage.service');
const emailOtpService = require('./email-otp.service');
const notificationService = require('./notification.service');

const OTP_PURPOSES = {
  adminLogin: 'admin_login',
  adminRegister: 'admin_register',
  emailChange: 'email_change',
  passwordChange: 'password_change',
  passwordReset: 'password_reset'
};

async function login(identifier, password, context = {}) {
  await assertLoginAllowed(identifier, context.ipAddress);

  const rows = await query(
    `SELECT u.id, u.full_name, u.email, u.college_id, u.password_hash, u.role,
            u.branch_id, u.is_active, u.dob, u.semester, u.roll_no, u.board_roll_no,
            u.college_name, u.course_name, u.guardian_name, u.phone, u.address,
            u.admission_year, u.photo_url, u.two_factor_enabled, u.two_factor_secret,
            u.is_primary_admin,
            b.name AS branch_name, b.code AS branch_code
     FROM users u
     LEFT JOIN branches b ON b.id = u.branch_id
     WHERE (u.role = 'admin' AND u.email = $1)
        OR (u.role = 'admin' AND u.college_id = $1)
        OR (u.role = 'student' AND u.board_roll_no = $1)
     LIMIT 1`,
    [identifier]
  );

  const user = rows[0];
  if (!user || !user.is_active) {
    await recordLoginFailure(identifier, context.ipAddress);
    throw new ApiError(401, 'Invalid credentials');
  }

  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) {
    await recordLoginFailure(identifier, context.ipAddress);
    throw new ApiError(401, 'Invalid credentials');
  }

  if (user.role === 'admin') {
    if (!context.emailOtpCode) {
      await emailOtpService.sendOtp(user.email, OTP_PURPOSES.adminLogin, 'e-PolyPariksha HP admin sign-in code');
      return { requiresEmailOtp: true, message: 'Email OTP sent to your admin email.' };
    }
    await emailOtpService.verifyOtp(user.email, OTP_PURPOSES.adminLogin, context.emailOtpCode);
  } else if (user.two_factor_enabled) {
    if (!context.totpCode) {
      return { requiresTwoFactor: true, message: 'Authenticator code required' };
    }
    if (!user.two_factor_secret || !verifyTotp(context.totpCode, user.two_factor_secret)) {
      await recordLoginFailure(identifier, context.ipAddress);
      return { requiresTwoFactor: true, message: 'Invalid authenticator code' };
    }
  }

  const jti = crypto.randomUUID();
  const token = jwt.sign(
    { sub: user.id, role: user.role, branchId: user.branch_id, semester: user.semester, jti },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn }
  );
  const decoded = jwt.decode(token);

  await query(
    `INSERT INTO auth_sessions (user_id, token_jti, device_label, ip_address, user_agent, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [user.id, jti, context.deviceLabel || null, context.ipAddress || null, context.userAgent || null, new Date(decoded.exp * 1000).toISOString()]
  );
  await clearLoginFailures(identifier, context.ipAddress);

  return { token, user: sanitizeUser(user) };
}

async function registerAdmin(payload) {
  const firstName = String(payload.firstName || '').trim();
  const middleName = String(payload.middleName || '').trim();
  const lastName = String(payload.lastName || '').trim();
  const mobile = String(payload.mobile || '').trim();
  const email = String(payload.email || '').trim();
  const college = String(payload.college || '').trim();
  const state = String(payload.state || '').trim();
  const fullName = [firstName, middleName, lastName].filter(Boolean).join(' ');
  if (!firstName || !lastName) throw new ApiError(422, 'First name and last name are required');
  if (!/^[0-9]{7,20}$/.test(mobile)) throw new ApiError(422, 'Valid mobile number is required');
  if (!email || !college || !state || !payload.password) {
    throw new ApiError(422, 'All fields except middle name are required');
  }
  await emailOtpService.verifyOtp(email, OTP_PURPOSES.adminRegister, payload.emailOtpCode);

  const passwordHash = await bcrypt.hash(payload.password, 12);
  const existing = await query('SELECT id FROM users WHERE lower(email) = lower($1) LIMIT 1', [email]);
  if (existing[0]) throw new ApiError(409, 'An admin account with this email already exists');

  try {
    const rows = await query(
      `INSERT INTO admin_applications (
         first_name, middle_name, last_name, full_name, mobile, email,
         college_name, state_name, password_hash, status
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending')
       ON CONFLICT (email) DO UPDATE SET
         first_name = EXCLUDED.first_name,
         middle_name = EXCLUDED.middle_name,
         last_name = EXCLUDED.last_name,
         full_name = EXCLUDED.full_name,
         mobile = EXCLUDED.mobile,
         college_name = EXCLUDED.college_name,
         state_name = EXCLUDED.state_name,
         password_hash = EXCLUDED.password_hash,
         status = 'pending',
         reviewed_by = NULL,
         reviewed_at = NULL,
         created_admin_id = NULL
       RETURNING id, full_name, email, mobile, college_name, state_name, status, created_at`,
      [
        firstName,
        middleName || null,
        lastName,
        fullName,
        mobile,
        email,
        college,
        state,
        passwordHash
      ]
    );
    return rows[0];
  } catch (err) {
    if (err.code === '23505') throw new ApiError(409, 'An application with this email already exists');
    throw err;
  }
}

async function requestAdminRegistrationOtp(email) {
  await emailOtpService.sendOtp(email, OTP_PURPOSES.adminRegister, 'e-PolyPariksha HP admin registration code');
  return { status: 'sent' };
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

async function updateCurrentUser(userId, patch) {
  const current = await query('SELECT email FROM users WHERE id = $1 AND is_active = true LIMIT 1', [userId]);
  if (!current[0]) throw new ApiError(401, 'User account is inactive or no longer exists');
  const requestedEmail = patch.email === undefined ? undefined : normalizeEmail(patch.email);
  if (requestedEmail && requestedEmail !== normalizeEmail(current[0].email)) {
    if (!patch.emailOtpCode) throw new ApiError(428, 'Verify the new email address before saving it');
    await emailOtpService.verifyOtp(requestedEmail, OTP_PURPOSES.emailChange, patch.emailOtpCode);
    patch.email = requestedEmail;
  }
  const allowed = ['full_name', 'email', 'phone', 'address', 'guardian_name'];
  const sets = [];
  const params = [];
  let idx = 1;
  for (const key of allowed) {
    const camelKey = key.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
    if (patch[camelKey] !== undefined) {
      sets.push(`${key} = $${idx++}`);
      params.push(patch[camelKey] || null);
    }
  }
  if (sets.length === 0) throw new ApiError(422, 'No valid fields to update');
  params.push(userId);
  try {
    await query(`UPDATE users SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $${idx}`, params);
  } catch (err) {
    if (err.code === '23505') throw new ApiError(409, 'Email already exists');
    throw err;
  }
  return getCurrentUser(userId);
}

async function requestEmailChangeOtp(userId, email) {
  const requestedEmail = normalizeEmail(email);
  if (!requestedEmail) throw new ApiError(422, 'A new email address is required');
  const rows = await query('SELECT email FROM users WHERE id = $1 AND is_active = true LIMIT 1', [userId]);
  if (!rows[0]) throw new ApiError(401, 'User account is inactive or no longer exists');
  if (requestedEmail === normalizeEmail(rows[0].email)) throw new ApiError(422, 'Enter a different email address');
  await emailOtpService.sendOtp(requestedEmail, OTP_PURPOSES.emailChange, 'e-PolyPariksha HP email change verification code');
  return { status: 'sent' };
}

async function updateCurrentUserPhoto(userId, file) {
  if (!file) throw new ApiError(422, 'Profile photo is required');
  const photoUrl = await storageService.saveProfilePhoto(file);
  await query('UPDATE users SET photo_url = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [photoUrl, userId]);
  return getCurrentUser(userId);
}

async function requestPasswordChangeOtp(userId) {
  const rows = await query('SELECT email FROM users WHERE id = $1 AND is_active = true LIMIT 1', [userId]);
  if (!rows[0]?.email) throw new ApiError(422, 'An email address is required to change your password');
  await emailOtpService.sendOtp(rows[0].email, OTP_PURPOSES.passwordChange, 'e-PolyPariksha HP password change verification code');
  return { status: 'sent' };
}

async function requestPasswordReset(email, role) {
  const normalizedEmail = normalizeEmail(email);
  const requestedRole = normalizeResetRole(role);
  const rows = await query(
    `SELECT id, email FROM users
     WHERE lower(email) = lower($1) AND role = $2 AND is_active = true
     LIMIT 1`,
    [normalizedEmail, requestedRole]
  );
  // Return the same acknowledgement for an unknown address so this public
  // endpoint cannot be used to discover accounts.
  if (rows[0]?.email) {
    await emailOtpService.sendOtp(rows[0].email, OTP_PURPOSES.passwordReset, 'Reset your e-PolyPariksha HP password');
  }
  return { status: 'sent', message: 'If that email belongs to an active account, a verification code has been sent.' };
}

async function verifyPasswordReset(email, role, otpCode) {
  const normalizedEmail = normalizeEmail(email);
  const requestedRole = normalizeResetRole(role);
  const rows = await query(
    `SELECT id, email, role FROM users
     WHERE lower(email) = lower($1) AND role = $2 AND is_active = true
     LIMIT 1`,
    [normalizedEmail, requestedRole]
  );
  const user = rows[0];
  if (!user) throw new ApiError(422, 'Invalid or expired verification code');
  await emailOtpService.verifyOtp(user.email, OTP_PURPOSES.passwordReset, otpCode);
  const nonce = crypto.randomUUID();
  await query(
    `INSERT INTO password_reset_tokens (token_nonce, user_id, expires_at)
     VALUES ($1, $2, CURRENT_TIMESTAMP + INTERVAL '10 minutes')`,
    [nonce, user.id]
  );
  const resetToken = jwt.sign(
    { sub: user.id, role: user.role, purpose: 'password_reset', nonce },
    env.jwtSecret,
    { expiresIn: '10m' }
  );
  return { resetToken };
}

async function completePasswordReset(resetToken, newPassword) {
  let payload;
  try {
    payload = jwt.verify(resetToken, env.jwtSecret);
  } catch (_) {
    throw new ApiError(422, 'Your reset session has expired. Request a new OTP.');
  }
  if (payload.purpose !== 'password_reset' || !payload.sub || !payload.nonce) {
    throw new ApiError(422, 'Invalid password reset session');
  }
  const rows = await query(
    'SELECT id, email, full_name FROM users WHERE id = $1 AND role = $2 AND is_active = true LIMIT 1',
    [payload.sub, payload.role]
  );
  const user = rows[0];
  if (!user) throw new ApiError(401, 'User account is inactive or no longer exists');
  const consumed = await query(
    `DELETE FROM password_reset_tokens
     WHERE token_nonce = $1 AND user_id = $2 AND expires_at > CURRENT_TIMESTAMP
     RETURNING token_nonce`,
    [payload.nonce, user.id]
  );
  if (!consumed[0]) throw new ApiError(422, 'This password reset session has expired or was already used.');
  const passwordHash = await bcrypt.hash(newPassword, 12);
  await query('UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [passwordHash, user.id]);
  await query('UPDATE auth_sessions SET revoked_at = CURRENT_TIMESTAMP WHERE user_id = $1 AND revoked_at IS NULL', [user.id]);
  await notificationService.notifySecurityEvent(user, 'password_changed', 'Password reset completed');
}

async function changeCurrentUserPassword(userId, { currentPassword, newPassword, totpCode, emailOtpCode }) {
  const rows = await query(
    `SELECT id, email, full_name, password_hash, two_factor_enabled, two_factor_secret
     FROM users WHERE id = $1 AND is_active = true LIMIT 1`,
    [userId]
  );
  const user = rows[0];
  if (!user) throw new ApiError(401, 'User account is inactive or no longer exists');
  if (!emailOtpCode) throw new ApiError(428, 'Verify the email OTP before changing your password');
  await emailOtpService.verifyOtp(user.email, OTP_PURPOSES.passwordChange, emailOtpCode);
  if (user.two_factor_enabled && !verifyTotp(totpCode, user.two_factor_secret)) {
    throw new ApiError(422, 'Invalid authenticator code');
  }
  const matches = await bcrypt.compare(currentPassword, user.password_hash);
  if (!matches) {
    throw new ApiError(401, 'Current password is incorrect');
  }
  const passwordHash = await bcrypt.hash(newPassword, 12);
  await query(
    'UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
    [passwordHash, userId]
  );
  await notificationService.notifySecurityEvent(user, 'password_changed');
}

async function setupTwoFactor(userId) {
  const user = await getCurrentUser(userId);
  const secret = generateBase32Secret();
  await query('UPDATE users SET two_factor_secret = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [secret, userId]);
  const label = encodeURIComponent(`e-PolyPariksha HP:${user.email || user.college_id || user.id}`);
  const otpauthUrl = `otpauth://totp/${label}?secret=${secret}&issuer=e-PolyPariksha HP&algorithm=SHA1&digits=6&period=30`;
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

async function requireVerifiedTwoFactor(userId, code) {
  const rows = await query(
    'SELECT two_factor_enabled, two_factor_secret FROM users WHERE id = $1 AND role = $2 AND is_active = true LIMIT 1',
    [userId, 'admin']
  );
  const user = rows[0];
  if (!user) throw new ApiError(401, 'Admin account is inactive or no longer exists');
  if (!user.two_factor_enabled || !user.two_factor_secret) {
    throw new ApiError(403, 'Enable 2FA before using this action');
  }
  if (!verifyTotp(code, user.two_factor_secret)) {
    throw new ApiError(422, 'Invalid authenticator code');
  }
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

function normalizeResetRole(role) {
  if (role !== 'admin' && role !== 'student') throw new ApiError(422, 'A valid account type is required');
  return role;
}

function loginFailureKey(identifier) {
  return crypto.createHash('sha256').update(String(identifier || '').trim().toLowerCase()).digest('hex');
}

async function assertLoginAllowed(identifier, ipAddress = '') {
  await query(
    `DELETE FROM login_failures
     WHERE identifier_hash = $1 AND ip_address = $2 AND locked_until <= CURRENT_TIMESTAMP`,
    [loginFailureKey(identifier), ipAddress || 'unknown']
  );
  const rows = await query(
    `SELECT locked_until
     FROM login_failures
     WHERE identifier_hash = $1 AND ip_address = $2
       AND locked_until IS NOT NULL AND locked_until > CURRENT_TIMESTAMP
     LIMIT 1`,
    [loginFailureKey(identifier), ipAddress || 'unknown']
  );
  if (rows[0]) {
    throw new ApiError(429, 'Too many failed login attempts. Try again after 5 minutes.');
  }
}

async function recordLoginFailure(identifier, ipAddress = '') {
  await query(
    `INSERT INTO login_failures (identifier_hash, ip_address, failed_count, locked_until)
     VALUES ($1, $2, 1, NULL)
     ON CONFLICT (identifier_hash, ip_address)
     DO UPDATE SET
       failed_count = CASE
         WHEN login_failures.last_failed_at < CURRENT_TIMESTAMP - INTERVAL '5 minutes' THEN 1
         ELSE login_failures.failed_count + 1
       END,
       first_failed_at = CASE
         WHEN login_failures.last_failed_at < CURRENT_TIMESTAMP - INTERVAL '5 minutes' THEN CURRENT_TIMESTAMP
         ELSE login_failures.first_failed_at
       END,
       last_failed_at = CURRENT_TIMESTAMP,
       locked_until = CASE
         WHEN login_failures.last_failed_at >= CURRENT_TIMESTAMP - INTERVAL '5 minutes'
              AND login_failures.failed_count + 1 >= 8
           THEN CURRENT_TIMESTAMP + INTERVAL '5 minutes'
         ELSE login_failures.locked_until
       END`,
    [loginFailureKey(identifier), ipAddress || 'unknown']
  );
}

async function clearLoginFailures(identifier, ipAddress = '') {
  await query(
    'DELETE FROM login_failures WHERE identifier_hash = $1 AND ip_address = $2',
    [loginFailureKey(identifier), ipAddress || 'unknown']
  );
}

module.exports = {
  login,
  requestAdminRegistrationOtp,
  requestEmailChangeOtp,
  requestPasswordChangeOtp,
  requestPasswordReset,
  verifyPasswordReset,
  completePasswordReset,
  registerAdmin,
  getCurrentUser,
  updateCurrentUser,
  updateCurrentUserPhoto,
  changeCurrentUserPassword,
  setupTwoFactor,
  enableTwoFactor,
  disableTwoFactor,
  requireVerifiedTwoFactor,
  logout
};

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
