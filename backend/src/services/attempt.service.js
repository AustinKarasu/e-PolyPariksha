const { query } = require('../config/db');
const { ApiError } = require('../utils/api-error');

const navigationEvents = new Set([
  'back_navigation_attempt',
  'home_navigation_attempt',
  'split_screen_attempt',
  'picture_in_picture_attempt'
]);
const warningEvents = new Set(['app_inactive', 'app_resumed', 'time_limit_reached', ...navigationEvents]);
const maxNavigationAttempts = 30;

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
  await getAssignedTestForUser(testId, user);
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
  await getAssignedTestForUser(testId, user);
  const attempt = await getAttemptByStudent(testId, user.sub);
  if (!attempt) throw new ApiError(404, 'Attempt not found');

  let message = metadata.message || `Student event: ${eventType}`;
  let severity = warningEvents.has(eventType) ? 'warning' : 'info';

  if (attempt.status === 'blocked') {
    await query('UPDATE test_attempts SET last_seen_at = CURRENT_TIMESTAMP WHERE id = $1', [attempt.id]);
    await recordEvent({
      attemptId: attempt.id, testId, studentId: user.sub, branchId: attempt.branch_id,
      eventType, severity: 'warning', message: message || 'Blocked attempt continued to report activity.', metadata, context
    });
    return { locked: true };
  }

  severity = warningEvents.has(eventType) ? 'warning' : 'info';
  if (navigationEvents.has(eventType)) {
    message = metadata.message || 'Student attempted navigation during the examination.';
  }

  await recordEvent({
    attemptId: attempt.id, testId, studentId: user.sub, branchId: attempt.branch_id,
    eventType, severity, message, metadata, context
  });

  if (navigationEvents.has(eventType)) {
    const countRows = await query(
      'SELECT COUNT(*)::INT AS count FROM exam_events WHERE attempt_id = $1 AND event_type = $2',
      [attempt.id, eventType]
    );
    const attempts = Number(countRows[0]?.count || 0);
    if (attempts > maxNavigationAttempts) {
      const lockMessage = `${eventType.replace(/_/g, ' ')} exceeded ${maxNavigationAttempts} attempts.`;
      await query(
        `UPDATE test_attempts
         SET last_seen_at = CURRENT_TIMESTAMP, status = 'blocked', blocked_reason = $1, blocked_at = CURRENT_TIMESTAMP
         WHERE id = $2`,
        [lockMessage, attempt.id]
      );
      return { locked: true, attempts };
    }
    await query('UPDATE test_attempts SET last_seen_at = CURRENT_TIMESTAMP WHERE id = $1', [attempt.id]);
    return { locked: false, attempts };
  }

  if (eventType === 'app_detached') {
    await query(
      `UPDATE test_attempts
       SET last_seen_at = CURRENT_TIMESTAMP,
           status = 'blocked',
           blocked_reason = $1,
           blocked_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [message, attempt.id]
    );
  } else {
    await query('UPDATE test_attempts SET last_seen_at = CURRENT_TIMESTAMP WHERE id = $1', [attempt.id]);
  }

  return { locked: eventType === 'app_detached' };
}

async function recordEvent({ attemptId, testId, studentId, branchId, eventType, severity = 'info', message = null, metadata = null, context = {} }) {
  await query(
    `INSERT INTO exam_events (attempt_id, test_id, student_id, branch_id, event_type, severity, message, metadata, ip_address, user_agent)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
    [attemptId || null, testId, studentId, branchId, eventType, severity, message,
     metadata ? JSON.stringify(metadata) : null, context.ipAddress || null, context.userAgent || null]
  );
}

async function isPrimaryAdmin(adminId) {
  const rows = await query(
    'SELECT is_primary_admin FROM users WHERE id = $1 AND role = $2 AND is_active = true LIMIT 1',
    [adminId, 'admin']
  );
  return rows[0]?.is_primary_admin === true;
}

async function listEvents(filters = {}, adminUser) {
  if (adminUser?.role === 'admin' && filters.reportFallback !== 'true') {
    const primary = await isPrimaryAdmin(adminUser.sub);
    if (!primary) throw new ApiError(403, 'Only the superuser can view logs');
  }
  const conditions = [];
  const params = [];
  let idx = 1;

  if (adminUser?.sub && !(await isPrimaryAdmin(adminUser.sub))) {
    conditions.push(`t.created_by = $${idx++}`);
    params.push(adminUser.sub);
  }
  if (filters.branchId) { conditions.push(`e.branch_id = $${idx++}`); params.push(filters.branchId); }
  if (filters.testId) { conditions.push(`e.test_id = $${idx++}`); params.push(filters.testId); }
  if (filters.studentId) { conditions.push(`e.student_id = $${idx++}`); params.push(filters.studentId); }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const limit = Math.min(Number(filters.limit || 100), 500);

  return query(
    `SELECT e.id, e.attempt_id, e.test_id, e.student_id, e.branch_id, e.event_type,
            e.severity, e.message, e.metadata, e.ip_address, e.user_agent, e.created_at,
            u.full_name AS student_name, u.email AS student_email, u.college_id, b.name AS branch_name, b.code AS branch_code,
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

async function listLockedAttempts(filters = {}, adminUser) {
  if (adminUser?.role === 'admin') {
    const primary = await isPrimaryAdmin(adminUser.sub);
    if (!primary) throw new ApiError(403, 'Only the superuser can view logs');
  }
  const conditions = ["a.status = 'blocked'"];
  const params = [];
  let idx = 1;

  if (adminUser?.sub && !(await isPrimaryAdmin(adminUser.sub))) {
    conditions.push(`t.created_by = $${idx++}`);
    params.push(adminUser.sub);
  }
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

async function listAttemptReports(filters = {}, adminUser) {
  const conditions = [];
  const params = [];
  let idx = 1;

  if (adminUser?.sub && !(await isPrimaryAdmin(adminUser.sub))) {
    conditions.push(`t.created_by = $${idx++}`);
    params.push(adminUser.sub);
  }
  if (filters.testId) {
    conditions.push(`a.test_id = $${idx++}`);
    params.push(filters.testId);
  }
  if (filters.studentId) {
    conditions.push(`a.student_id = $${idx++}`);
    params.push(filters.studentId);
  }
  if (filters.branchId) {
    conditions.push(`t.branch_id = $${idx++}`);
    params.push(filters.branchId);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const limit = Math.min(Number(filters.limit || 500), 1000);
  const criticalTypes = Array.from(navigationEvents);

  const reports = await query(
    `SELECT a.id AS attempt_id, a.status, a.started_at, a.last_seen_at, a.completed_at,
            a.blocked_at, a.blocked_reason,
            CASE
              WHEN a.started_at IS NOT NULL AND a.completed_at IS NOT NULL
                THEN EXTRACT(EPOCH FROM (a.completed_at - a.started_at))::INT
              WHEN a.started_at IS NOT NULL AND a.last_seen_at IS NOT NULL
                THEN EXTRACT(EPOCH FROM (a.last_seen_at - a.started_at))::INT
              ELSE NULL
            END AS time_taken_seconds,
            t.id AS test_id, t.title AS test_title, t.time_limit_minutes,
            t.scheduled_start, t.scheduled_end,
            u.id AS student_id, u.full_name, u.college_id, u.email, u.phone,
            u.board_roll_no, u.roll_no, u.college_name, u.course_name,
            u.guardian_name, u.semester, u.admission_year, u.dropout_year,
            b.name AS branch_name, b.code AS branch_code,
            COALESCE(
              JSON_AGG(
                JSON_BUILD_OBJECT(
                  'event_type', e.event_type,
                  'severity', e.severity,
                  'message', e.message,
                  'metadata', e.metadata,
                  'created_at', e.created_at
                )
                ORDER BY e.created_at ASC
              ) FILTER (WHERE e.id IS NOT NULL),
              '[]'::json
            ) AS events,
            COALESCE(
              JSON_AGG(
                JSON_BUILD_OBJECT(
                  'event_type', e.event_type,
                  'message', e.message,
                  'created_at', e.created_at
                )
                ORDER BY e.created_at ASC
              ) FILTER (WHERE e.event_type = ANY($${idx}::text[])),
              '[]'::json
            ) AS blocked_actions
     FROM test_attempts a
     JOIN tests t ON t.id = a.test_id
     JOIN users u ON u.id = a.student_id
     JOIN branches b ON b.id = t.branch_id
     LEFT JOIN exam_events e ON e.attempt_id = a.id
     ${where}
     GROUP BY a.id, t.id, u.id, b.id
     ORDER BY COALESCE(a.completed_at, a.last_seen_at, a.started_at) DESC
     LIMIT $${idx + 1}`,
    [...params, criticalTypes, limit]
  );

  return reports.map((report) => ({
    ...report,
    ai_summary: buildReportSummary(report)
  }));
}

function buildReportSummary(report) {
  const blocked = Array.isArray(report.blocked_actions) ? report.blocked_actions : [];
  const minutes = report.time_taken_seconds == null
    ? 'not available'
    : `${Math.max(1, Math.round(Number(report.time_taken_seconds) / 60))} minute(s)`;
  if (blocked.length > 0) {
    const actions = [...new Set(blocked.map((event) => readableEvent(event.event_type)))].join(', ');
    return `${report.full_name} attempted ${report.test_title}, spent ${minutes}, and triggered blocked action(s): ${actions}.`;
  }
  return `${report.full_name} attempted ${report.test_title} and spent ${minutes} with no blocked actions recorded.`;
}

function readableEvent(eventType) {
  return String(eventType || '').replace(/_/g, ' ');
}

async function allowAttempt(attemptId, adminUser, context = {}) {
  const rows = await query(
    `SELECT a.*, t.branch_id, t.created_by FROM test_attempts a JOIN tests t ON t.id = a.test_id WHERE a.id = $1 LIMIT 1`,
    [attemptId]
  );
  const attempt = rows[0];
  if (!attempt) throw new ApiError(404, 'Attempt not found');
  if (!(await isPrimaryAdmin(adminUser.sub)) && attempt.created_by !== adminUser.sub) {
    throw new ApiError(403, 'This attempt belongs to another admin account');
  }

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

async function recordEndedPdfAccess(test, user, context = {}) {
  const attempt = await getAttemptByStudent(test.id, user.sub);
  if (attempt) {
    await query('UPDATE test_attempts SET last_seen_at = CURRENT_TIMESTAMP WHERE id = $1', [attempt.id]);
  }

  await recordEvent({
    attemptId: attempt?.id || null,
    testId: test.id,
    studentId: user.sub,
    branchId: test.branch_id,
    eventType: 'ended_pdf_downloaded',
    message: 'Student downloaded the question paper after the test ended.',
    context
  });
}

async function getAssignedLiveTestForUser(testId, user) {
  const test = await getAssignedTestForUser(testId, user);
  const nowRows = await query(
    `SELECT id FROM tests
     WHERE id = $1 AND is_active = true
       AND CURRENT_TIMESTAMP BETWEEN scheduled_start AND scheduled_end
     LIMIT 1`,
    [test.id]
  );
  if (!nowRows[0]) throw new ApiError(403, 'This paper is not available for your branch and semester at this time.');
  return test;
}

async function getAssignedTestForUser(testId, user) {
  const rows = await query(
    `SELECT * FROM tests
     WHERE id = $1 AND branch_id = $2 AND semester = $3
       AND ($4::int IS NULL OR created_by = $4)
     LIMIT 1`,
    [testId, user.branchId, user.semester, user.createdByAdminId || null]
  );
  if (!rows[0]) throw new ApiError(403, 'This paper is not assigned to your account.');
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
  listAttemptReports,
  allowAttempt,
  assertLivePdfAccess,
  assertCompletedPdfAccess,
  recordEndedPdfAccess
};
