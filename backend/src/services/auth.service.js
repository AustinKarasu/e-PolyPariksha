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
            u.admission_year, u.photo_url,
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

  delete user.password_hash;
  return { token, user };
}

async function getCurrentUser(userId) {
  const rows = await query(
    `SELECT u.id, u.full_name, u.email, u.college_id, u.role,
            u.branch_id, u.dob, u.semester, u.roll_no, u.board_roll_no,
            u.college_name, u.course_name, u.guardian_name, u.phone, u.address,
            u.admission_year, u.photo_url,
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

async function logout(user) {
  if (!user?.jti) return;
  await query(
    'UPDATE auth_sessions SET revoked_at = CURRENT_TIMESTAMP WHERE token_jti = $1',
    [user.jti]
  );
}

module.exports = { login, getCurrentUser, logout };
