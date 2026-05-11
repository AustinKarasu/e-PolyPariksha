const bcrypt = require('bcryptjs');
const { query } = require('../config/db');
const { ApiError } = require('../utils/api-error');

async function listAdmins() {
  return query(
    `SELECT id, full_name, email, is_active, created_at
     FROM users WHERE role = 'admin' ORDER BY created_at DESC`
  );
}

async function createAdmin({ fullName, email, password }) {
  const passwordHash = await bcrypt.hash(password, 12);
  try {
    const rows = await query(
      `INSERT INTO users (full_name, email, password_hash, role, is_active)
       VALUES ($1, $2, $3, 'admin', TRUE) RETURNING id`,
      [fullName, email, passwordHash]
    );
    return { id: rows[0].id, full_name: fullName, email, role: 'admin' };
  } catch (err) {
    if (err.code === '23505') {
      throw new ApiError(409, 'Admin email already exists');
    }
    throw err;
  }
}

async function setAdminActive(adminId, isActive, actingAdminId) {
  if (adminId === actingAdminId && !isActive) {
    throw new ApiError(422, 'You cannot deactivate your own admin account');
  }
  await query(
    `UPDATE users SET is_active = $1 WHERE id = $2 AND role = 'admin'`,
    [isActive, adminId]
  );
}

module.exports = { listAdmins, createAdmin, setAdminActive };
