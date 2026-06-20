const bcrypt = require('bcryptjs');
const { query, transaction } = require('../config/db');
const { ApiError } = require('../utils/api-error');
const authService = require('./auth.service');
const emailOtpService = require('./email-otp.service');
const notificationService = require('./notification.service');

const PRIMARY_ADMIN_EMAIL = 'aayankarasu@gmail.com';

async function listAdmins(actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  await reconcileAdminDirectory();
  return query(
    `SELECT id, full_name, email, is_active, two_factor_enabled, is_primary_admin, created_at
     FROM users WHERE role = 'admin' ORDER BY is_primary_admin DESC, created_at DESC`
  );
}

async function listApplications(actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  await reconcileAdminDirectory();
  return query(
    `SELECT id, full_name, first_name, middle_name, last_name, mobile, email,
            college_name, state_name, status, reviewed_by, reviewed_at,
            created_admin_id, created_at
     FROM admin_applications
     ORDER BY
       CASE status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 ELSE 2 END,
       created_at DESC`
  );
}

async function requirePrimaryAdmin(adminId) {
  const rows = await query(
    'SELECT is_primary_admin FROM users WHERE id = $1 AND role = $2 AND is_active = true LIMIT 1',
    [adminId, 'admin']
  );
  if (!rows[0]) throw new ApiError(401, 'Admin account is inactive or no longer exists');
  if (!rows[0].is_primary_admin) throw new ApiError(403, 'Only the primary admin can use this action');
}

async function requestCreateAdminOtp(actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  const rows = await query('SELECT email FROM users WHERE id = $1 LIMIT 1', [actingAdminId]);
  if (!rows[0]?.email) throw new ApiError(422, 'Your admin account needs an email address');
  await emailOtpService.sendOtp(rows[0].email, 'create_admin', 'e-PolyPariksha HP add admin verification code');
  return { status: 'sent' };
}

async function notifyAppUpdate(version, actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  return notificationService.notifyAppUpdate(version, actingAdminId);
}

async function createAdmin({ fullName, email, password, otpCode }, actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  const acting = await query('SELECT email FROM users WHERE id = $1 LIMIT 1', [actingAdminId]);
  if (!otpCode) throw new ApiError(428, 'Verify your email OTP before adding an admin');
  await emailOtpService.verifyOtp(acting[0]?.email, 'create_admin', otpCode);
  const passwordHash = await bcrypt.hash(password, 12);
  try {
    const rows = await query(
      `INSERT INTO users (full_name, email, password_hash, role, is_active, is_primary_admin)
       VALUES ($1, $2, $3, 'admin', TRUE, FALSE) RETURNING id`,
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

async function approveApplication(applicationId, actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  const rows = await query('SELECT * FROM admin_applications WHERE id = $1 LIMIT 1', [applicationId]);
  const app = rows[0];
  if (!app) throw new ApiError(404, 'Admin application not found');
  if (app.status !== 'pending') throw new ApiError(422, 'Only pending applications can be approved');

  const created = await transaction(async (tx) => {
    const existing = await tx(
      `SELECT id
       FROM users
       WHERE lower(email) = lower($1) AND role = 'admin'
       LIMIT 1`,
      [app.email]
    );
    const users = existing[0]
      ? await tx(
          `UPDATE users
           SET full_name = $1,
               first_name = $2,
               middle_name = $3,
               last_name = $4,
               password_hash = $5,
               phone = $6,
               college_name = $7,
               state_name = $8,
               is_active = TRUE,
               updated_at = CURRENT_TIMESTAMP
           WHERE id = $9 AND role = 'admin'
           RETURNING id`,
          [
            app.full_name,
            app.first_name,
            app.middle_name,
            app.last_name,
            app.password_hash,
            app.mobile,
            app.college_name,
            app.state_name,
            existing[0].id
          ]
        )
      : await tx(
          `INSERT INTO users (
             full_name, first_name, middle_name, last_name, email, password_hash, role,
             phone, college_name, state_name, is_active, is_primary_admin
           )
           VALUES ($1, $2, $3, $4, $5, $6, 'admin', $7, $8, $9, TRUE, FALSE)
           RETURNING id`,
          [
            app.full_name,
            app.first_name,
            app.middle_name,
            app.last_name,
            app.email,
            app.password_hash,
            app.mobile,
            app.college_name,
            app.state_name
          ]
        );
      await tx(
        `UPDATE admin_applications
         SET status = 'approved', reviewed_by = $1, reviewed_at = CURRENT_TIMESTAMP, created_admin_id = $2
         WHERE id = $3`,
        [actingAdminId, users[0].id, applicationId]
      );
      return users;
  });
  await reconcileAdminDirectory();
  const adminRows = await query(
    `SELECT id, full_name, email, is_active, two_factor_enabled, is_primary_admin, created_at
     FROM users WHERE id = $1 LIMIT 1`,
    [created[0].id]
  );
  return adminRows[0];
}

async function rejectApplication(applicationId, actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  const rows = await query('SELECT id FROM admin_applications WHERE id = $1 LIMIT 1', [applicationId]);
  if (!rows[0]) throw new ApiError(404, 'Admin application not found');
  await query(
    `UPDATE admin_applications
     SET status = 'rejected', reviewed_by = $1, reviewed_at = CURRENT_TIMESTAMP
     WHERE id = $2`,
    [actingAdminId, applicationId]
  );
}

async function deleteApplication(applicationId, actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  await query('DELETE FROM admin_applications WHERE id = $1', [applicationId]);
}

async function updateAdmin(adminId, patch, actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  const existingRows = await query('SELECT id, is_primary_admin FROM users WHERE id = $1 AND role = $2 LIMIT 1', [adminId, 'admin']);
  const existing = existingRows[0];
  if (!existing) throw new ApiError(404, 'Admin account not found');
  const actingRows = await query('SELECT is_primary_admin FROM users WHERE id = $1 AND role = $2 AND is_active = true LIMIT 1', [actingAdminId, 'admin']);
  const actingAdmin = actingRows[0];
  if (!actingAdmin) throw new ApiError(401, 'Admin account is inactive or no longer exists');

  const sets = [];
  const params = [];
  let idx = 1;

  if (patch.fullName !== undefined) {
    sets.push(`full_name = $${idx++}`);
    params.push(patch.fullName);
  }
  if (patch.email !== undefined) {
    if (existing.is_primary_admin && !actingAdmin.is_primary_admin) {
      throw new ApiError(403, 'Only the primary admin can change the primary admin email');
    }
    const target = await query('SELECT email FROM users WHERE id = $1 LIMIT 1', [adminId]);
    const nextEmail = String(patch.email || '').trim().toLowerCase();
    if (nextEmail && nextEmail !== String(target[0]?.email || '').trim().toLowerCase()) {
      if (!patch.emailOtpCode) throw new ApiError(428, 'Verify the new email address before saving it');
      await emailOtpService.verifyOtp(nextEmail, 'email_change', patch.emailOtpCode);
    }
    sets.push(`email = $${idx++}`);
    params.push(nextEmail || null);
  }
  if (patch.password) {
    sets.push(`password_hash = $${idx++}`);
    params.push(await bcrypt.hash(patch.password, 12));
  }
  if (patch.isActive !== undefined) {
    if (adminId === actingAdminId && patch.isActive === false) {
      throw new ApiError(422, 'You cannot deactivate your own admin account');
    }
    if (existing.is_primary_admin && patch.isActive === false) {
      throw new ApiError(422, 'Primary admin cannot be deactivated until another admin is made primary');
    }
    sets.push(`is_active = $${idx++}`);
    params.push(patch.isActive);
  }

  if (sets.length === 0) throw new ApiError(422, 'No valid fields to update');
  params.push(adminId);
  try {
    await query(`UPDATE users SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $${idx} AND role = 'admin'`, params);
  } catch (err) {
    if (err.code === '23505') throw new ApiError(409, 'Admin email already exists');
    throw err;
  }

  const rows = await query(
    `SELECT id, full_name, email, is_active, two_factor_enabled, is_primary_admin, created_at
     FROM users WHERE id = $1 AND role = 'admin' LIMIT 1`,
    [adminId]
  );
  return rows[0];
}

async function setAdminActive(adminId, isActive, actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  if (adminId === actingAdminId && !isActive) {
    throw new ApiError(422, 'You cannot deactivate your own admin account');
  }
  const rows = await query('SELECT is_primary_admin FROM users WHERE id = $1 AND role = $2 LIMIT 1', [adminId, 'admin']);
  if (!rows[0]) throw new ApiError(404, 'Admin account not found');
  if (rows[0].is_primary_admin && !isActive) {
    throw new ApiError(422, 'Primary admin cannot be deactivated until another admin is made primary');
  }
  await query(
    `UPDATE users SET is_active = $1 WHERE id = $2 AND role = 'admin'`,
    [isActive, adminId]
  );
}

async function setPrimaryAdmin(adminId, actingAdminId, otpCode) {
  await requirePrimaryAdmin(actingAdminId);
  const actingRows = await query(
    'SELECT email FROM users WHERE id = $1 AND role = $2 AND is_active = true LIMIT 1',
    [actingAdminId, 'admin']
  );
  const actingEmail = actingRows[0]?.email;
  if (!actingEmail) throw new ApiError(422, 'Your admin account needs an email before changing primary admin');
  if (!otpCode) {
    await emailOtpService.sendOtp(actingEmail, 'primary_admin', 'e-PolyPariksha HP primary admin verification code');
    throw new ApiError(428, 'Email OTP sent. Enter the OTP to make this admin primary.');
  }
  await emailOtpService.verifyOtp(actingEmail, 'primary_admin', otpCode);
  const rows = await query('SELECT id, is_active FROM users WHERE id = $1 AND role = $2 LIMIT 1', [adminId, 'admin']);
  if (!rows[0]) throw new ApiError(404, 'Admin account not found');
  if (!rows[0].is_active) throw new ApiError(422, 'Only an active admin can be primary');
  await query('UPDATE users SET is_primary_admin = FALSE WHERE role = $1', ['admin']);
  await query('UPDATE users SET is_primary_admin = TRUE, updated_at = CURRENT_TIMESTAMP WHERE id = $1 AND role = $2', [adminId, 'admin']);
}

async function deleteAdmin(adminId, actingAdminId) {
  await requirePrimaryAdmin(actingAdminId);
  if (adminId === actingAdminId) throw new ApiError(422, 'You cannot delete your own admin account');
  const rows = await query('SELECT is_primary_admin FROM users WHERE id = $1 AND role = $2 LIMIT 1', [adminId, 'admin']);
  if (!rows[0]) throw new ApiError(404, 'Admin account not found');
  if (rows[0].is_primary_admin) throw new ApiError(422, 'Primary admin cannot be deleted until another admin is made primary');
  await query('UPDATE test_attempts SET allowed_by = NULL WHERE allowed_by = $1', [adminId]);
  await query('DELETE FROM auth_sessions WHERE user_id = $1', [adminId]);
  await query('DELETE FROM users WHERE id = $1 AND role = $2', [adminId, 'admin']);
}

async function clearData(actingAdminId, { totpCode, tests = false, history = false, students = false, sessions = false, logs = false, applications = false }) {
  await authService.requireVerifiedTwoFactor(actingAdminId, totpCode);
  await requirePrimaryAdmin(actingAdminId);
  if (!tests && !history && !students && !sessions && !logs && !applications) {
    throw new ApiError(422, 'Select at least one data type to clear');
  }

  await transaction(async (tx) => {
    if (applications) {
      await tx('DELETE FROM admin_applications', []);
    }
    if (logs) {
      await tx('DELETE FROM exam_events', []);
      await tx('DELETE FROM login_failures', []);
    }
    if (students) {
      await tx('DELETE FROM auth_sessions WHERE user_id IN (SELECT id FROM users WHERE role = $1)', ['student']);
      await tx('DELETE FROM exam_events WHERE student_id IN (SELECT id FROM users WHERE role = $1)', ['student']);
      await tx('DELETE FROM test_attempts WHERE student_id IN (SELECT id FROM users WHERE role = $1)', ['student']);
      await tx('DELETE FROM users WHERE role = $1', ['student']);
    }
    if (tests) {
      await tx('DELETE FROM exam_events', []);
      await tx('DELETE FROM test_attempts', []);
      await tx('DELETE FROM tests', []);
    } else if (history) {
      await tx('DELETE FROM exam_events', []);
      await tx('DELETE FROM test_attempts', []);
    }
    if (sessions) {
      await tx('UPDATE auth_sessions SET revoked_at = CURRENT_TIMESTAMP WHERE revoked_at IS NULL', []);
    }
  });
}

async function reconcileAdminDirectory() {
  await transaction(async (tx) => {
    await tx(
      `WITH approved_apps AS (
         SELECT *
         FROM admin_applications a
         WHERE a.status = 'approved'
       ),
       reactivated_admins AS (
         UPDATE users u
         SET is_active = TRUE,
             updated_at = CURRENT_TIMESTAMP
         FROM approved_apps a
         WHERE lower(u.email) = lower(a.email)
           AND u.role = 'admin'
           AND u.is_active = FALSE
         RETURNING u.id, lower(u.email) AS email_key
       ),
       existing_admins AS (
         SELECT u.id, lower(u.email) AS email_key
         FROM users u
         JOIN approved_apps a ON lower(u.email) = lower(a.email)
         WHERE u.role = 'admin'
       ),
       inserted_admins AS (
         INSERT INTO users (
           full_name, first_name, middle_name, last_name, email, password_hash, role,
           phone, college_name, state_name, is_active, is_primary_admin
         )
         SELECT
           a.full_name, a.first_name, a.middle_name, a.last_name, a.email,
           a.password_hash, 'admin', a.mobile, a.college_name, a.state_name,
           TRUE, FALSE
         FROM approved_apps a
         WHERE NOT EXISTS (
           SELECT 1 FROM users u WHERE lower(u.email) = lower(a.email)
         )
         RETURNING id, lower(email) AS email_key
       ),
       linked_admins AS (
         SELECT * FROM existing_admins
         UNION
         SELECT * FROM inserted_admins
         UNION
         SELECT * FROM reactivated_admins
       )
       UPDATE admin_applications a
       SET created_admin_id = l.id
       FROM linked_admins l
       WHERE lower(a.email) = l.email_key
         AND a.status = 'approved'
         AND (a.created_admin_id IS NULL OR a.created_admin_id <> l.id)`,
      []
    );

    const primaryRows = await tx(
      `UPDATE users
       SET is_primary_admin = TRUE,
           is_active = TRUE,
           updated_at = CURRENT_TIMESTAMP
       WHERE role = 'admin' AND lower(email) = $1
       RETURNING id`,
      [PRIMARY_ADMIN_EMAIL]
    );

    if (primaryRows[0]) {
      await tx(
        `UPDATE users
         SET is_primary_admin = FALSE,
             updated_at = CURRENT_TIMESTAMP
         WHERE role = 'admin' AND id <> $1 AND is_primary_admin = TRUE`,
        [primaryRows[0].id]
      );
      return;
    }

    const existingPrimary = await tx(
      `SELECT id FROM users
       WHERE role = 'admin' AND is_primary_admin = TRUE AND is_active = TRUE
       LIMIT 1`,
      []
    );
    if (existingPrimary[0]) return;

    const fallback = await tx(
      `SELECT id FROM users
       WHERE role = 'admin' AND is_active = TRUE
       ORDER BY created_at ASC, id ASC
       LIMIT 1`,
      []
    );
    if (!fallback[0]) return;
    await tx(
      `UPDATE users
       SET is_primary_admin = TRUE,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $1 AND role = 'admin'`,
      [fallback[0].id]
    );
  });
}

module.exports = {
  listAdmins,
  listApplications,
  createAdmin,
  requestCreateAdminOtp,
  notifyAppUpdate,
  approveApplication,
  rejectApplication,
  deleteApplication,
  updateAdmin,
  setAdminActive,
  setPrimaryAdmin,
  deleteAdmin,
  clearData
};
