const bcrypt = require('bcryptjs');
const { query } = require('../config/db');
const { ApiError } = require('../utils/api-error');
const storageService = require('./storage.service');
const emailOtpService = require('./email-otp.service');

const STUDENT_SELECT = `
  SELECT u.id, u.full_name, u.email, u.college_id, u.role, u.branch_id,
         u.dob, u.semester, u.roll_no, u.board_roll_no, u.college_name,
         u.course_name, u.guardian_name, u.phone, u.address,
         u.admission_year, u.dropout_year, u.photo_url, u.is_active, u.two_factor_enabled, u.created_at,
         u.created_by_admin_id,
         b.name AS branch_name, b.code AS branch_code
  FROM users u
  LEFT JOIN branches b ON b.id = u.branch_id`;

async function getStudentProfile(userId) {
  const rows = await query(`${STUDENT_SELECT} WHERE u.id = $1 AND u.is_active = true LIMIT 1`, [userId]);
  if (!rows[0]) throw new ApiError(404, 'Student not found');
  return rows[0];
}

async function updateStudentProfile(userId, patch) {
  const existingRows = await query('SELECT email FROM users WHERE id = $1 AND role = $2 AND is_active = true LIMIT 1', [userId, 'student']);
  const existing = existingRows[0];
  if (!existing) throw new ApiError(401, 'Student account is inactive or no longer exists');
  const nextEmail = String(patch.email || '').trim().toLowerCase();
  if (patch.email !== undefined && nextEmail && nextEmail !== String(existing.email || '').trim().toLowerCase()) {
    if (!patch.emailOtpCode) throw new ApiError(428, 'Verify the new email address before saving it');
    await emailOtpService.verifyOtp(nextEmail, 'email_change', patch.emailOtpCode);
    patch.email = nextEmail;
  }
  const allowed = ['email', 'phone', 'address', 'guardian_name'];
  const sets = [];
  const params = [];
  let idx = 1;

  for (const key of allowed) {
    const camelKey = key.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
    if (patch[camelKey] !== undefined) {
      sets.push(`${key} = $${idx++}`);
      params.push(patch[camelKey]);
    }
  }
  if (sets.length === 0) throw new ApiError(422, 'No valid fields to update');

  params.push(userId);
  await query(`UPDATE users SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $${idx}`, params);
  return getStudentProfile(userId);
}

async function requestStudentEmailChangeOtp(userId, email) {
  const requested = String(email || '').trim().toLowerCase();
  if (!requested) throw new ApiError(422, 'A new email address is required');
  const rows = await query('SELECT email FROM users WHERE id = $1 AND role = $2 AND is_active = true LIMIT 1', [userId, 'student']);
  if (!rows[0]) throw new ApiError(401, 'Student account is inactive or no longer exists');
  if (requested === String(rows[0].email || '').trim().toLowerCase()) throw new ApiError(422, 'Enter a different email address');
  await emailOtpService.sendOtp(requested, 'email_change', 'e-PolyPariksha HP email change verification code');
  return { status: 'sent' };
}

async function updateStudentPhoto(userId, file) {
  if (!file) throw new ApiError(422, 'Profile photo is required');
  const photoUrl = await storageService.saveProfilePhoto(file);
  await query(
    'UPDATE users SET photo_url = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 AND role = $3',
    [photoUrl, userId, 'student']
  );
  return getStudentProfile(userId);
}

async function adminUpdateStudentPhoto(studentId, file, actingAdminId) {
  const student = await getStudentById(studentId, actingAdminId);
  if (student.role !== 'student') throw new ApiError(404, 'Student not found');
  return updateStudentPhoto(studentId, file);
}

async function isPrimaryAdmin(adminId) {
  const rows = await query(
    'SELECT is_primary_admin FROM users WHERE id = $1 AND role = $2 AND is_active = true LIMIT 1',
    [adminId, 'admin']
  );
  return rows[0]?.is_primary_admin === true;
}

async function listAllStudents(filters = {}, actingAdminId) {
  const conditions = ["u.role = 'student'"];
  const params = [];
  let idx = 1;

  if (actingAdminId && !(await isPrimaryAdmin(actingAdminId))) {
    conditions.push(`u.created_by_admin_id = $${idx++}`);
    params.push(actingAdminId);
  }

  if (filters.branchId) {
    conditions.push(`u.branch_id = $${idx++}`);
    params.push(filters.branchId);
  }
  if (filters.semester) {
    conditions.push(`u.semester = $${idx++}`);
    params.push(filters.semester);
  }
  if (filters.search) {
    conditions.push(`(u.full_name ILIKE $${idx} OR u.college_id ILIKE $${idx} OR u.roll_no ILIKE $${idx} OR u.board_roll_no ILIKE $${idx})`);
    params.push(`%${filters.search}%`);
    idx++;
  }

  const limit = Math.min(Number(filters.limit || 100), 500);
  const offset = Number(filters.offset || 0);

  const students = await query(
    `${STUDENT_SELECT} WHERE ${conditions.join(' AND ')} ORDER BY u.full_name ASC LIMIT $${idx++} OFFSET $${idx}`,
    [...params, limit, offset]
  );

  const countRows = await query(
    `SELECT COUNT(*) AS total FROM users u WHERE ${conditions.join(' AND ')}`,
    params
  );

  return { students, total: Number(countRows[0].total) };
}

async function getStudentById(studentId, actingAdminId) {
  const params = [studentId];
  let scope = '';
  if (actingAdminId && !(await isPrimaryAdmin(actingAdminId))) {
    params.push(actingAdminId);
    scope = ` AND u.created_by_admin_id = $${params.length}`;
  }
  const rows = await query(`${STUDENT_SELECT} WHERE u.id = $1${scope} LIMIT 1`, params);
  if (!rows[0]) throw new ApiError(404, 'Student not found');
  return rows[0];
}

async function adminCreateStudent(payload, actingAdminId) {
  const boardRollNo = String(payload.boardRollNo || '').trim();
  if (!boardRollNo) throw new ApiError(422, 'Board roll no is required for student login');
  const requiredFields = [
    ['fullName', 'Full name'],
    ['collegeId', 'College ID'],
    ['email', 'Email'],
    ['dob', 'Date of birth'],
    ['semester', 'Semester'],
    ['rollNo', 'Roll no'],
    ['collegeName', 'College name'],
    ['courseName', 'Course'],
    ['guardianName', 'Guardian name'],
    ['phone', 'Phone'],
    ['address', 'Address'],
    ['admissionYear', 'Admission year'],
    ['dropoutYear', 'Drop out year'],
    ['branchId', 'Branch']
  ];
  const missing = requiredFields
    .filter(([key]) => payload[key] === undefined || payload[key] === null || String(payload[key]).trim() === '')
    .map(([, label]) => label);
  if (missing.length > 0) throw new ApiError(422, `Missing required student fields: ${missing.join(', ')}`);
  const semester = Number(payload.semester);
  if (!Number.isInteger(semester) || semester < 1 || semester > 6) {
    throw new ApiError(422, 'Semester must be from 1 to 6');
  }
  const dobPassword = `${String(payload.dob).slice(8, 10)}${String(payload.dob).slice(5, 7)}${String(payload.dob).slice(0, 4)}`;
  const passwordHash = await bcrypt.hash(payload.password || dobPassword, 12);
  try {
    const rows = await query(
      `INSERT INTO users (
        full_name, email, college_id, password_hash, role, branch_id,
        dob, semester, roll_no, board_roll_no, college_name, course_name,
        guardian_name, phone, address, admission_year, dropout_year, created_by_admin_id, is_active, must_change_credentials
      )
      VALUES ($1, $2, $3, $4, 'student', $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, TRUE, $18)
      RETURNING id`,
      [
        payload.fullName,
        payload.email || null,
        payload.collegeId,
        passwordHash,
        payload.branchId,
        payload.dob,
        semester,
        payload.rollNo,
        boardRollNo,
        payload.collegeName,
        payload.courseName,
        payload.guardianName,
        payload.phone,
        payload.address,
        payload.admissionYear,
        payload.dropoutYear,
        actingAdminId,
        !payload.password
      ]
    );
    return getStudentById(rows[0].id, actingAdminId);
  } catch (err) {
    if (err.code === '23505') {
      throw new ApiError(409, 'A user with this email or college ID already exists');
    }
    throw err;
  }
}

async function adminUpdateStudent(studentId, patch, actingAdminId) {
  const allowed = [
    'full_name', 'email', 'college_id', 'dob', 'semester', 'roll_no', 'board_roll_no',
    'college_name', 'course_name', 'guardian_name', 'phone',
    'address', 'admission_year', 'dropout_year', 'is_active', 'branch_id'
  ];
  const sets = [];
  const params = [];
  let idx = 1;

  for (const key of allowed) {
    const camelKey = key.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
    if (patch[camelKey] !== undefined) {
      sets.push(`${key} = $${idx++}`);
      params.push(patch[camelKey]);
    }
  }
  if (patch.boardRollNo !== undefined) {
    const boardRollNo = String(patch.boardRollNo || '').trim();
    if (!boardRollNo) throw new ApiError(422, 'Board roll no is required for student login');
  }
  if (patch.password !== undefined && patch.password !== '') {
    sets.push(`password_hash = $${idx++}`);
    params.push(await bcrypt.hash(patch.password, 12));
  }
  if (sets.length === 0) throw new ApiError(422, 'No valid fields to update');

  params.push(studentId);
  await getStudentById(studentId, actingAdminId);
  try {
    await query(
      `UPDATE users SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $${idx} AND role = 'student'`,
      params
    );
  } catch (err) {
    if (err.code === '23505') {
      throw new ApiError(409, 'A user with this email or college ID already exists');
    }
    throw err;
  }
  return getStudentById(studentId, actingAdminId);
}

async function adminDeleteStudent(studentId, actingAdminId) {
  const student = await getStudentById(studentId, actingAdminId);
  await query('DELETE FROM exam_events WHERE student_id = $1', [studentId]);
  await query('DELETE FROM test_attempts WHERE student_id = $1', [studentId]);
  await query('DELETE FROM auth_sessions WHERE user_id = $1', [studentId]);
  await query('DELETE FROM users WHERE id = $1 AND role = $2', [studentId, 'student']);
  return student;
}

module.exports = {
  getStudentProfile,
  updateStudentProfile,
  requestStudentEmailChangeOtp,
  updateStudentPhoto,
  adminUpdateStudentPhoto,
  listAllStudents,
  getStudentById,
  adminCreateStudent,
  adminUpdateStudent,
  adminDeleteStudent
};
