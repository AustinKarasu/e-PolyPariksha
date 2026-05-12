const { query } = require('../config/db');
const { ApiError } = require('../utils/api-error');

const criticalEvents = new Set(['app_backgrounded', 'app_detached', 'app_hidden', 'back_blocked', 'split_screen_detected']);
const warningEvents = new Set(['app_inactive', 'app_resumed']);

async function startAttempt(testId, user, context = {}) {
  const test = await getAssignedLiveTestForUser(testId, user);
  const existing = await getAttemptByStudent(testId, user.sub);

  if (existing?.status === 'completed') {
    throw new ApiError(409, 'This attempt has already been submitted.');
  }

  if (existing) {
    await query(
      `UPDATE test_attempts
       SET last_seen_at = CURRENT_TIMESTAMP,
           status = CASE WHEN status IN ('admin_allowed', 'blocked') THEN 'started' ELSE status END,
           blocked_reason = NULL
       WHERE id = $1`,
      [existing.id]
    );
    await recordEvent({
      attemptId: existing.id, testId, studentId: user.sub, branchId: test.branch_id,
      eventType: 'attempt_started', message: 'Student reopened the test paper after a valid start request.', context
    });
    return { ...existing, status: 'started' };
  }

  const rows = await query(
    `INSERT INTO test_attempts (test_id, student_id, started_at, last_seen_at, status)
     VALUES ($1, $2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'started') RETURNING id`,
    [testId, user.sub]
  );

  await recordEvent({
    attemptId: rows[0].id, testId, studentId: user.sub, branchId: test.branch_id,
    eventType: 'attempt_started', message: 'Student started the test paper.', context
  });

  return { id: rows[0].id, status: 'started' };
}

async function completeAttempt(testId, user, answerNote, context = {}) {
  const attempt = await getAttemptByStudent(testId, user.sub);
  if (!attempt) throw new ApiError(404, 'Attempt not found');

  await query(
    `UPDATE test_attempts
     SET completed_at = CURRENT_TIMESTAMP, last_seen_at = CURRENT_TIMESTAMP,
         status = 'completed', answer_note = $1
     WHERE id = $2`,
    [answerNote || null, attempt.id]
  );

  await recordEvent({
    attemptId: attempt.id, testId, studentId: user.sub, branchId: attempt.branch_id,
    eventType: 'submit_completed', message: 'Student marked the physical-answer-sheet test complete.', context
  });
}

async function recordStudentEvent(testId, user, eventType, metadata = {}, context = {}) {
  const attempt = await getAttemptByStudent(testId, user.sub);
  if (!attempt) throw new ApiError(404, 'Attempt not found');

  let message = metadata.message || `Student event: ${eventType}`;
  let severity = warningEvents.has(eventType) ? 'warning' : 'info';

  if (criticalEvents.has(eventType)) {
    severity = 'critical';
    message = metadata.message || 'Student left or attempted to leave secure exam mode.';
  } else {
    severity = warningEvents.has(eventType) ? 'warning' : 'info';
  }

  await query('UPDATE test_attempts SET last_seen_at = CURRENT_TIMESTAMP WHERE id = $1', [attempt.id]);

  await recordEvent({
    attemptId: attempt.id, testId, studentId: user.sub, branchId: attempt.branch_id,
    eventType, severity, message, metadata, context
  });

  return { locked: false };
}

async function recordEvent({ attemptId, testId, studentId, branchId, eventType, severity = 'info', message = null, metadata = null, context = {} }) {
  await query(
    `INSERT INTO exam_events (attempt_id, test_id, student_id, branch_id, event_type, severity, message, metadata, ip_address, user_agent)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
    [attemptId || null, testId, studentId, branchId, eventType, severity, message,
     metadata ? JSON.stringify(metadata) : null, context.ipAddress || null, context.userAgent || null]
  );
}

async function listEvents(filters = {}) {
  const conditions = [];
  const params = [];
  let idx = 1;

  if (filters.branchId) { conditions.push(`e.branch_id = $${idx++}`); params.push(filters.branchId); }
  if (filters.testId) { conditions.push(`e.test_id = $${idx++}`); params.push(filters.testId); }
  if (filters.studentId) { conditions.push(`e.student_id = $${idx++}`); params.push(filters.studentId); }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const limit = Math.min(Number(filters.limit || 100), 500);

  return query(
    `SELECT e.id, e.attempt_id, e.test_id, e.student_id, e.branch_id, e.event_type,
            e.severity, e.message, e.metadata, e.ip_address, e.user_agent, e.created_at,
            u.full_name AS student_name, u.college_id, b.name AS branch_name, b.code AS branch_code,
            t.title AS test_title
     FROM exam_events e
     JOIN users u ON u.id = e.student_id
     JOIN branches b ON b.id = e.branch_id
     JOIN tests t ON t.id = e.test_id
     ${where}
     ORDER BY e.created_at DESC
     LIMIT $${idx}`,
    [...params, limit]
  );
}

async function listLockedAttempts(filters = {}) {
  const conditions = ["a.status = 'blocked'"];
  const params = [];
  let idx = 1;

  if (filters.branchId) { conditions.push(`t.branch_id = $${idx++}`); params.push(filters.branchId); }

  return query(
    `SELECT a.id, a.test_id, a.student_id, a.status, a.started_at, a.last_seen_at,
            a.blocked_at, a.blocked_reason, a.allowed_at,
            u.full_name AS student_name, u.college_id,
            b.name AS branch_name, b.code AS branch_code,
            t.title AS test_title
     FROM test_attempts a
     JOIN users u ON u.id = a.student_id
     JOIN tests t ON t.id = a.test_id
     JOIN branches b ON b.id = t.branch_id
     WHERE ${conditions.join(' AND ')}
     ORDER BY a.blocked_at DESC`,
    params
  );
}

async function allowAttempt(attemptId, adminUser, context = {}) {
  const rows = await query(
    `SELECT a.*, t.branch_id FROM test_attempts a JOIN tests t ON t.id = a.test_id WHERE a.id = $1 LIMIT 1`,
    [attemptId]
  );
  const attempt = rows[0];
  if (!attempt) throw new ApiError(404, 'Attempt not found');

  await query(
    `UPDATE test_attempts SET status = 'admin_allowed', allowed_by = $1, allowed_at = CURRENT_TIMESTAMP, blocked_reason = NULL WHERE id = $2`,
    [adminUser.sub, attemptId]
  );

  await recordEvent({
    attemptId, testId: attempt.test_id, studentId: attempt.student_id, branchId: attempt.branch_id,
    eventType: 'admin_allowed', severity: 'warning',
    message: 'Admin allowed this student to reopen the test paper.',
    metadata: { adminId: adminUser.sub }, context
  });
}

async function assertLivePdfAccess(testId, user, context = {}) {
  const attempt = await getAttemptByStudent(testId, user.sub);
  if (!attempt) throw new ApiError(403, 'Start the test before opening the PDF.');
  if (attempt.status === 'completed') throw new ApiError(403, 'This attempt has already been completed.');

  await query(
    `UPDATE test_attempts
     SET last_seen_at = CURRENT_TIMESTAMP,
         status = CASE WHEN status = 'blocked' THEN 'started' ELSE status END,
         blocked_reason = NULL
     WHERE id = $1`,
    [attempt.id]
  );
  await recordEvent({
    attemptId: attempt.id, testId, studentId: user.sub, branchId: attempt.branch_id,
    eventType: 'pdf_requested', message: 'Student requested the scheduled PDF.', context
  });
}

async function assertCompletedPdfAccess(testId, user, context = {}) {
  const attempt = await getAttemptByStudent(testId, user.sub);
  if (!attempt || attempt.status !== 'completed') {
    throw new ApiError(403, 'Submit the test before downloading the paper after it ends.');
  }

  await query('UPDATE test_attempts SET last_seen_at = CURRENT_TIMESTAMP WHERE id = $1', [attempt.id]);
  await recordEvent({
    attemptId: attempt.id, testId, studentId: user.sub, branchId: attempt.branch_id,
    eventType: 'completed_pdf_downloaded', message: 'Student downloaded the paper after the test ended.', context
  });
}

async function getAssignedLiveTestForUser(testId, user) {
  const rows = await query(
    `SELECT * FROM tests
     WHERE id = $1 AND branch_id = $2 AND semester = $3 AND is_active = true
       AND CURRENT_TIMESTAMP BETWEEN scheduled_start AND scheduled_end
     LIMIT 1`,
    [testId, user.branchId, user.semester]
  );
  if (!rows[0]) throw new ApiError(403, 'This paper is not available for your branch and semester at this time.');
  return rows[0];
}

async function getAttemptByStudent(testId, studentId) {
  const rows = await query(
    `SELECT a.*, t.branch_id FROM test_attempts a JOIN tests t ON t.id = a.test_id
     WHERE a.test_id = $1 AND a.student_id = $2 LIMIT 1`,
    [testId, studentId]
  );
  return rows[0] || null;
}

module.exports = {
  startAttempt,
  completeAttempt,
  recordStudentEvent,
  recordEvent,
  listEvents,
  listLockedAttempts,
  allowAttempt,
  assertLivePdfAccess,
  assertCompletedPdfAccess
};
