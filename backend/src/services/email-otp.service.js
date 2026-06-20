const crypto = require('crypto');
const nodemailer = require('nodemailer');
const { env } = require('../config/env');
const { query } = require('../config/db');
const { ApiError } = require('../utils/api-error');

const OTP_TTL_MINUTES = 10;
const OTP_MAX_SENDS = 5;
const OTP_MAX_FAILURES = 5;
const OTP_COOLDOWN_MINUTES = 60;

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function hashCode(email, purpose, code) {
  return crypto
    .createHash('sha256')
    .update(`${normalizeEmail(email)}:${purpose}:${String(code).trim()}`)
    .digest('hex');
}

function generateCode() {
  return String(crypto.randomInt(100000, 1000000));
}

function transporter() {
  if (!env.smtp.host || !env.smtp.user || !env.smtp.pass || !env.smtp.from) {
    throw new ApiError(500, 'Email OTP is not configured');
  }
  return nodemailer.createTransport({
    host: env.smtp.host,
    port: env.smtp.port,
    secure: env.smtp.secure,
    auth: {
      user: env.smtp.user,
      pass: env.smtp.pass
    }
  });
}

async function sendOtp(email, purpose, subject = 'e-PolyPariksha HP verification code') {
  const normalizedEmail = normalizeEmail(email);
  if (!normalizedEmail) throw new ApiError(422, 'Email is required');

  const state = await query(
    `INSERT INTO otp_security (email, purpose) VALUES ($1, $2)
     ON CONFLICT (email, purpose) DO UPDATE SET email = EXCLUDED.email
     RETURNING *`,
    [normalizedEmail, purpose]
  );
  const security = state[0];
  if (security.locked_until && new Date(security.locked_until) > new Date()) {
    throw new ApiError(429, 'Too many OTP attempts. Try again in one hour.');
  }
  const sentRecently = await query(
    `SELECT COUNT(*)::INT AS count FROM email_otps
     WHERE email = $1 AND purpose = $2 AND created_at > CURRENT_TIMESTAMP - INTERVAL '1 hour'`,
    [normalizedEmail, purpose]
  );
  if (sentRecently[0].count >= OTP_MAX_SENDS) {
    await query(
      `UPDATE otp_security SET locked_until = CURRENT_TIMESTAMP + INTERVAL '1 hour'
       WHERE email = $1 AND purpose = $2`,
      [normalizedEmail, purpose]
    );
    throw new ApiError(429, `You can request an OTP only ${OTP_MAX_SENDS} times per hour. Try again in one hour.`);
  }

  const code = generateCode();
  await query(
    `INSERT INTO email_otps (email, purpose, code_hash, expires_at)
     VALUES ($1, $2, $3, CURRENT_TIMESTAMP + ($4 || ' minutes')::INTERVAL)`,
    [normalizedEmail, purpose, hashCode(normalizedEmail, purpose, code), OTP_TTL_MINUTES]
  );

  await transporter().sendMail({
    from: env.smtp.from,
    to: normalizedEmail,
    subject,
    text: `Your e-PolyPariksha HP verification code is ${code}. It expires in ${OTP_TTL_MINUTES} minutes. Do not share this code.`
  });
}

async function verifyOtp(email, purpose, code) {
  const normalizedEmail = normalizeEmail(email);
  const cleanCode = String(code || '').trim();
  if (!normalizedEmail || !cleanCode) {
    throw new ApiError(422, 'Email OTP is required');
  }
  const securityRows = await query(
    'SELECT * FROM otp_security WHERE email = $1 AND purpose = $2 LIMIT 1',
    [normalizedEmail, purpose]
  );
  const security = securityRows[0];
  if (security?.locked_until && new Date(security.locked_until) > new Date()) {
    throw new ApiError(429, 'Too many OTP attempts. Try again in one hour.');
  }
  const rows = await query(
    `SELECT id, code_hash
     FROM email_otps
     WHERE email = $1
       AND purpose = $2
       AND consumed_at IS NULL
       AND expires_at > CURRENT_TIMESTAMP
     ORDER BY created_at DESC
     LIMIT 1`,
    [normalizedEmail, purpose]
  );
  const otp = rows[0];
  if (!otp || otp.code_hash !== hashCode(normalizedEmail, purpose, cleanCode)) {
    const failures = await query(
      `INSERT INTO otp_security (email, purpose, failed_attempts, failed_window_started_at)
       VALUES ($1, $2, 1, CURRENT_TIMESTAMP)
       ON CONFLICT (email, purpose) DO UPDATE SET
         failed_attempts = CASE WHEN otp_security.failed_window_started_at < CURRENT_TIMESTAMP - INTERVAL '1 hour'
           THEN 1 ELSE otp_security.failed_attempts + 1 END,
         failed_window_started_at = CASE WHEN otp_security.failed_window_started_at < CURRENT_TIMESTAMP - INTERVAL '1 hour'
           THEN CURRENT_TIMESTAMP ELSE otp_security.failed_window_started_at END
       RETURNING failed_attempts`,
      [normalizedEmail, purpose]
    );
    if (failures[0].failed_attempts >= OTP_MAX_FAILURES) {
      await query(
        `UPDATE otp_security SET locked_until = CURRENT_TIMESTAMP + INTERVAL '1 hour', failed_attempts = 0
         WHERE email = $1 AND purpose = $2`,
        [normalizedEmail, purpose]
      );
      throw new ApiError(429, 'Too many incorrect OTP attempts. Try again in one hour.');
    }
    throw new ApiError(422, 'Invalid or expired email OTP');
  }
  await query('UPDATE email_otps SET consumed_at = CURRENT_TIMESTAMP WHERE id = $1', [otp.id]);
  await query('DELETE FROM otp_security WHERE email = $1 AND purpose = $2', [normalizedEmail, purpose]);
}

module.exports = { sendOtp, verifyOtp };
