const { query } = require('../config/db');
const { ApiError } = require('../utils/api-error');
const attemptService = require('./attempt.service');
const storageService = require('./storage.service');

async function createTest({ title, branchId, semester, scheduledStart, scheduledEnd, timeLimitMinutes, file, createdBy }) {
  if (!file) throw new ApiError(422, 'PDF file is required');

  const saved = await storageService.savePdf(file);
  const rows = await query(
    `INSERT INTO tests (title, branch_id, semester, pdf_path, scheduled_start, scheduled_end, time_limit_minutes, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
    [title, branchId, semester, saved.path, scheduledStart, scheduledEnd, timeLimitMinutes, createdBy]
  );

  return getTestById(rows[0].id);
}

async function getTestById(id) {
  const rows = await query(
    `SELECT t.*, b.name AS branch_name, b.code AS branch_code
     FROM tests t JOIN branches b ON b.id = t.branch_id WHERE t.id = $1`,
    [id]
  );
  if (!rows[0]) throw new ApiError(404, 'Test not found');
  return rows[0];
}

async function listAdminTests() {
  return query(
    `SELECT t.id, t.title, t.pdf_path, t.semester, t.scheduled_start, t.scheduled_end,
            t.time_limit_minutes, t.is_active, b.name AS branch_name, b.code AS branch_code
     FROM tests t JOIN branches b ON b.id = t.branch_id
     ORDER BY t.scheduled_start DESC`
  );
}

async function listStudentTests(user) {
  const tests = await query(
    `SELECT t.id, t.title, t.pdf_path, t.semester, t.scheduled_start, t.scheduled_end,
            t.time_limit_minutes, a.id AS attempt_id, a.status AS attempt_status,
            a.blocked_reason, a.blocked_at, a.allowed_at, a.completed_at
     FROM tests t
     LEFT JOIN test_attempts a ON a.test_id = t.id AND a.student_id = $1
     WHERE t.branch_id = $2 AND t.semester = $3 AND t.is_active = true
     ORDER BY t.scheduled_start DESC`,
    [user.sub, user.branchId, user.semester]
  );
  return tests.map((test) => ({
    ...test,
    status: statusForTest(test)
  }));
}

async function updateTest(id, patch) {
  await getTestById(id);
  await query(
    `UPDATE tests SET title = $1, branch_id = $2, semester = $3, scheduled_start = $4, scheduled_end = $5,
     time_limit_minutes = $6, is_active = $7, updated_at = CURRENT_TIMESTAMP WHERE id = $8`,
    [patch.title, patch.branchId, patch.semester, patch.scheduledStart, patch.scheduledEnd, patch.timeLimitMinutes, patch.isActive, id]
  );
  return getTestById(id);
}

async function setTestActive(id, isActive) {
  await getTestById(id);
  await query(
    'UPDATE tests SET is_active = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
    [isActive, id]
  );
  return getTestById(id);
}

async function endTestNow(id) {
  await getTestById(id);
  await query(
    'UPDATE tests SET scheduled_end = CURRENT_TIMESTAMP, is_active = false, updated_at = CURRENT_TIMESTAMP WHERE id = $1',
    [id]
  );
  return getTestById(id);
}

async function replacePdf(id, file) {
  if (!file) throw new ApiError(422, 'PDF file is required');
  const existing = await getTestById(id);
  const saved = await storageService.savePdf(file);
  await query(
    `UPDATE tests SET pdf_path = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
    [saved.path, id]
  );
  await storageService.deletePdf(existing.pdf_path);
  return getTestById(id);
}

async function removeTest(id) {
  const existing = await getTestById(id);
  await query('DELETE FROM exam_events WHERE test_id = $1', [id]);
  await query('DELETE FROM test_attempts WHERE test_id = $1', [id]);
  await query('DELETE FROM tests WHERE id = $1', [id]);
  await storageService.deletePdf(existing.pdf_path);
}

async function getStudentPdf(testId, user, context = {}) {
  const test = await getTestById(testId);
  if (!test.is_active) throw new ApiError(403, 'This test is not active');
  if (test.branch_id !== user.branchId) throw new ApiError(403, 'This test is not assigned to your branch');
  if (test.semester !== user.semester) throw new ApiError(403, 'This test is not assigned to your semester');
  const status = statusForTest(test);
  if (status === 'ended') {
    await attemptService.assertCompletedPdfAccess(testId, user, context);
    return storageService.getPdfDelivery(test.pdf_path);
  }
  if (status !== 'live') throw new ApiError(403, 'PDF is available only during scheduled test time');
  await attemptService.assertLivePdfAccess(testId, user, context);
  return storageService.getPdfDelivery(test.pdf_path);
}

async function getAdminPdf(testId) {
  const test = await getTestById(testId);
  return storageService.getPdfDelivery(test.pdf_path);
}

function statusForTest(test) {
  const now = Date.now();
  const start = new Date(test.scheduled_start).getTime();
  const end = new Date(test.scheduled_end).getTime();
  if (now < start) return 'upcoming';
  if (now > end) return 'ended';
  return 'live';
}

module.exports = { createTest, listAdminTests, listStudentTests, updateTest, setTestActive, endTestNow, replacePdf, removeTest, getStudentPdf, getAdminPdf };
