const { query, transaction } = require('../config/db');
const { ApiError } = require('../utils/api-error');
const attemptService = require('./attempt.service');
const storageService = require('./storage.service');

async function createTest({ title, branchId, semester, scheduledStart, scheduledEnd, timeLimitMinutes, file, createdBy }) {
  if (!file) throw new ApiError(422, 'PDF file is required');

  const saved = await storageService.savePdf(file);
  const pdfBytes = await storageService.getUploadedFileBytes(file);
  const rows = await query(
    `INSERT INTO tests (
       title, branch_id, semester, pdf_path, pdf_data, pdf_original_name, pdf_mime_type, pdf_size,
       scheduled_start, scheduled_end, time_limit_minutes, created_by
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING id`,
    [
      title, branchId, semester, saved.path, pdfBytes, file.originalname,
      file.mimetype || 'application/pdf', pdfBytes.length,
      scheduledStart, scheduledEnd, timeLimitMinutes, createdBy
    ]
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
    `SELECT t.id, t.title, t.pdf_path, t.pdf_original_name, t.pdf_size, t.semester, t.scheduled_start, t.scheduled_end,
            t.time_limit_minutes, t.is_active, b.name AS branch_name, b.code AS branch_code
     FROM tests t JOIN branches b ON b.id = t.branch_id
     WHERE t.deleted_at IS NULL
     ORDER BY t.scheduled_start DESC`
  );
}

async function listStudentTests(user) {
  const tests = await query(
    `SELECT t.id, t.title, t.pdf_path, t.pdf_original_name, t.pdf_size, t.semester, t.scheduled_start, t.scheduled_end,
            t.time_limit_minutes, a.id AS attempt_id, a.status AS attempt_status,
            a.blocked_reason, a.blocked_at, a.allowed_at, a.started_at, a.last_seen_at, a.completed_at
     FROM tests t
     LEFT JOIN test_attempts a ON a.test_id = t.id AND a.student_id = $1
     WHERE t.branch_id = $2 AND t.semester = $3
       AND (t.is_active = true OR t.scheduled_end < CURRENT_TIMESTAMP)
       AND t.deleted_at IS NULL
     ORDER BY t.scheduled_start DESC`,
    [user.sub, user.branchId, user.semester]
  );
  return tests.map((test) => ({
    ...test,
    status: statusForTest(test)
  }));
}

async function listStudentHistory(user) {
  await query(
    `DELETE FROM exam_events
     WHERE student_id = $1
       AND test_id IN (SELECT id FROM tests WHERE scheduled_end < CURRENT_TIMESTAMP - INTERVAL '30 days')`,
    [user.sub]
  );
  await query(
    `DELETE FROM test_attempts
     WHERE student_id = $1
       AND test_id IN (SELECT id FROM tests WHERE scheduled_end < CURRENT_TIMESTAMP - INTERVAL '30 days')`,
    [user.sub]
  );

  const tests = await query(
    `SELECT t.id, t.title, t.pdf_original_name, t.pdf_size, t.semester,
            t.scheduled_start, t.scheduled_end, t.time_limit_minutes,
            (t.pdf_data IS NOT NULL OR t.pdf_path IS NOT NULL) AS has_pdf,
            a.id AS attempt_id, a.status AS attempt_status,
            a.started_at, a.last_seen_at, a.completed_at, a.answer_note,
            CASE
              WHEN a.started_at IS NOT NULL AND a.completed_at IS NOT NULL
                THEN EXTRACT(EPOCH FROM (a.completed_at - a.started_at))::INT
              WHEN a.started_at IS NOT NULL AND a.last_seen_at IS NOT NULL
                THEN EXTRACT(EPOCH FROM (a.last_seen_at - a.started_at))::INT
              ELSE NULL
            END AS active_seconds
     FROM tests t
     LEFT JOIN test_attempts a ON a.test_id = t.id AND a.student_id = $1
     WHERE t.branch_id = $2
       AND t.semester = $3
       AND t.scheduled_end < CURRENT_TIMESTAMP
       AND t.scheduled_end >= CURRENT_TIMESTAMP - INTERVAL '30 days'
     ORDER BY t.scheduled_end DESC, t.scheduled_start DESC`,
    [user.sub, user.branchId, user.semester]
  );

  return tests.map((test) => ({
    ...test,
    status: 'ended',
    can_download_pdf: Boolean(test.has_pdf)
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
  const pdfBytes = await storageService.getUploadedFileBytes(file);
  await query(
    `UPDATE tests
     SET pdf_path = $1, pdf_data = $2, pdf_original_name = $3, pdf_mime_type = $4,
         pdf_size = $5, updated_at = CURRENT_TIMESTAMP
     WHERE id = $6`,
    [saved.path, pdfBytes, file.originalname, file.mimetype || 'application/pdf', pdfBytes.length, id]
  );
  await storageService.deletePdf(existing.pdf_path);
  return getTestById(id);
}

async function removeTest(id) {
  await transaction(async (tx) => {
    const rows = await tx('SELECT id FROM tests WHERE id = $1 AND deleted_at IS NULL FOR UPDATE', [id]);
    if (!rows[0]) throw new ApiError(404, 'Test not found');
    await tx(
      `UPDATE tests
       SET deleted_at = CURRENT_TIMESTAMP, is_active = false, updated_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [id]
    );
  });
}

async function getStudentPdf(testId, user, context = {}) {
  const test = await getTestById(testId);
  if (test.branch_id !== user.branchId) throw new ApiError(403, 'This test is not assigned to your branch');
  if (test.semester !== user.semester) throw new ApiError(403, 'This test is not assigned to your semester');
  const status = statusForTest(test);
  if (!test.is_active && status !== 'ended') throw new ApiError(403, 'This test is not active');
  if (status === 'ended') {
    await attemptService.recordEndedPdfAccess(test, user, context);
    return storageService.getPdfDelivery(test.pdf_path, test);
  }
  if (status !== 'live') throw new ApiError(403, 'PDF is available only during scheduled test time');
  await attemptService.assertLivePdfAccess(testId, user, context);
  return storageService.getPdfDelivery(test.pdf_path, test);
}

async function getAdminPdf(testId) {
  const test = await getTestById(testId);
  return storageService.getPdfDelivery(test.pdf_path, test);
}

function statusForTest(test) {
  const now = Date.now();
  const start = new Date(test.scheduled_start).getTime();
  const end = new Date(test.scheduled_end).getTime();
  if (now < start) return 'upcoming';
  if (now > end) return 'ended';
  return 'live';
}

module.exports = { createTest, listAdminTests, listStudentTests, listStudentHistory, updateTest, setTestActive, endTestNow, replacePdf, removeTest, getStudentPdf, getAdminPdf };
