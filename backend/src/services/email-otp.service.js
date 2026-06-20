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
    connectionTimeout: Number(process.env.SMTP_CONNECTION_TIMEOUT_MS || 10000),
    greetingTimeout: Number(process.env.SMTP_GREETING_TIMEOUT_MS || 10000),
    socketTimeout: Number(process.env.SMTP_SOCKET_TIMEOUT_MS || 15000),
    auth: {
      user: env.smtp.user,
      pass: env.smtp.pass
    }
  });
}

async function sendOtp(email, purpose, subject = 'e-PolyPariksha HP verification code') {
  const normalizedEmail = normalizeEmail(email);
  if (!normalizedEmail) throw new ApiError(422, 'Email is required');

  await clearExpiredSecurityLock(normalizedEmail, purpose);

  const state = await query(
    `INSERT INTO otp_security (email, purpose) VALUES ($1, $2)
     ON CONFLICT (email, purpose) DO UPDATE SET email = EXCLUDED.email
     RETURNING *`,
    [normalizedEmail, purpose]
  );
  const security = state[0];
  if (security.locked_until && new Date(security.locked_until) > new Date()) {
    throw new ApiError(429, 'Too many incorrect OTP attempts. Try again in one hour.');
  }
  const sentRecently = await query(
    `SELECT COUNT(*)::INT AS count FROM email_otps
     WHERE email = $1 AND purpose = $2 AND created_at > CURRENT_TIMESTAMP - INTERVAL '1 hour'`,
    [normalizedEmail, purpose]
  );
  if (sentRecently[0].count >= OTP_MAX_SENDS) {
    throw new ApiError(429, `You can request an OTP only ${OTP_MAX_SENDS} times per hour. Wait before requesting another code.`);
  }

  const code = generateCode();

  await transporter().sendMail({
    from: env.smtp.from,
    to: normalizedEmail,
    subject,
    text: `Your e-PolyPariksha HP verification code is ${code}. It expires in ${OTP_TTL_MINUTES} minutes. Do not share this code.`,
    html: otpEmailHtml(code, subject)
  });

  await query(
    `INSERT INTO email_otps (email, purpose, code_hash, expires_at)
     VALUES ($1, $2, $3, CURRENT_TIMESTAMP + ($4 || ' minutes')::INTERVAL)`,
    [normalizedEmail, purpose, hashCode(normalizedEmail, purpose, code), OTP_TTL_MINUTES]
  );
}

function otpEmailHtml(code, subject) {
  const title = String(subject).replace(/^e-PolyPariksha HP\s*/i, '').trim() || 'Verification code';
  return `<!doctype html><html><body style="margin:0;background:#eef3f8;font-family:Arial,sans-serif;color:#1e293b">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td align="center" style="padding:28px 12px">
      <table role="presentation" width="560" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fff;border:1px solid #dce5f0;border-radius:12px;overflow:hidden">
        <tr><td style="padding:24px 28px;background:#103b72;color:#fff"><div style="font-size:21px;font-weight:700">e-PolyPariksha HP</div><div style="font-size:13px;margin-top:4px;color:#dbeafe">Account security</div></td></tr>
        <tr><td style="padding:30px 28px"><h1 style="margin:0 0 12px;font-size:22px;color:#0f172a">${title}</h1><p style="margin:0;color:#475569;font-size:15px;line-height:1.55">Use the secure verification code below to continue. It expires in ${OTP_TTL_MINUTES} minutes.</p>
          <div style="margin:24px 0;padding:17px;text-align:center;background:#f1f5f9;border:1px solid #dce5f0;border-radius:8px;font-size:30px;letter-spacing:8px;font-weight:700;color:#103b72">${code}</div>
          <p style="margin:0;color:#64748b;font-size:13px;line-height:1.55">For your security, never share this code with anyone. If you did not request it, you can safely ignore this email.</p></td></tr>
        <tr><td style="padding:16px 28px;border-top:1px solid #e2e8f0;color:#64748b;font-size:12px">e-PolyPariksha HP &middot; Government Polytechnic Kangra</td></tr>
      </table>
    </td></tr></table></body></html>`;
}

async function verifyOtp(email, purpose, code) {
  const normalizedEmail = normalizeEmail(email);
  const cleanCode = String(code || '').trim();
  if (!normalizedEmail || !cleanCode) {
    throw new ApiError(422, 'Email OTP is required');
  }
  await clearExpiredSecurityLock(normalizedEmail, purpose);
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
  if (!otp) {
    throw new ApiError(422, 'Invalid or expired email OTP');
  }
  if (otp.code_hash !== hashCode(normalizedEmail, purpose, cleanCode)) {
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

async function clearExpiredSecurityLock(email, purpose) {
  await query(
    `UPDATE otp_security
     SET locked_until = NULL,
         failed_attempts = CASE
           WHEN failed_window_started_at < CURRENT_TIMESTAMP - INTERVAL '1 hour' THEN 0
           ELSE failed_attempts
         END,
         failed_window_started_at = CASE
           WHEN failed_window_started_at < CURRENT_TIMESTAMP - INTERVAL '1 hour' THEN NULL
           ELSE failed_window_started_at
         END
     WHERE email = $1
       AND purpose = $2
       AND (
         locked_until <= CURRENT_TIMESTAMP
         OR failed_window_started_at < CURRENT_TIMESTAMP - INTERVAL '1 hour'
       )`,
    [email, purpose]
  );
}

module.exports = { sendOtp, verifyOtp };
