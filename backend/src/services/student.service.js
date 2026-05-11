const { query } = require('../config/db');
const { ApiError } = require('../utils/api-error');

const STUDENT_SELECT = `
  SELECT u.id, u.full_name, u.email, u.college_id, u.role, u.branch_id,
         u.dob, u.semester, u.roll_no, u.board_roll_no, u.college_name,
         u.course_name, u.guardian_name, u.phone, u.address,
         u.admission_year, u.photo_url, u.is_active, u.created_at,
         b.name AS branch_name, b.code AS branch_code
  FROM users u
  LEFT JOIN branches b ON b.id = u.branch_id`;

async function getStudentProfile(userId) {
  const rows = await query(`${STUDENT_SELECT} WHERE u.id = $1 AND u.is_active = true LIMIT 1`, [userId]);
  if (!rows[0]) throw new ApiError(404, 'Student not found');
  return rows[0];
}

async function updateStudentProfile(userId, patch) {
  const allowed = ['phone', 'address', 'guardian_name'];
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

async function listAllStudents(filters = {}) {
  const conditions = ["u.role = 'student'"];
  const params = [];
  let idx = 1;

  if (filters.branchId) {
    conditions.push(`u.branch_id = $${idx++}`);
    params.push(filters.branchId);
  }
  if (filters.semester) {
    conditions.push(`u.semester = $${idx++}`);
    params.push(filters.semester);
  }
  if (filters.search) {
    conditions.push(`(u.full_name ILIKE $${idx} OR u.college_id ILIKE $${idx} OR u.roll_no ILIKE $${idx})`);
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

async function getStudentById(studentId) {
  const rows = await query(`${STUDENT_SELECT} WHERE u.id = $1 LIMIT 1`, [studentId]);
  if (!rows[0]) throw new ApiError(404, 'Student not found');
  return rows[0];
}

async function adminUpdateStudent(studentId, patch) {
  const allowed = [
    'full_name', 'dob', 'semester', 'roll_no', 'board_roll_no',
    'college_name', 'course_name', 'guardian_name', 'phone',
    'address', 'admission_year', 'is_active', 'branch_id'
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
  if (sets.length === 0) throw new ApiError(422, 'No valid fields to update');

  params.push(studentId);
  await query(
    `UPDATE users SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $${idx} AND role = 'student'`,
    params
  );
  return getStudentById(studentId);
}

module.exports = { getStudentProfile, updateStudentProfile, listAllStudents, getStudentById, adminUpdateStudent };
