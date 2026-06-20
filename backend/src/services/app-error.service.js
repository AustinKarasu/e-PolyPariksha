const { query } = require('../config/db');
const { ApiError } = require('../utils/api-error');

async function recordAppError(user, payload = {}) {
  const message = String(payload.message || '').trim();
  if (!message) throw new ApiError(422, 'Error message is required');

  const severity = payload.severity === 'crash' ? 'crash' : 'error';
  const rows = await query(
    `INSERT INTO app_error_reports (
       user_id, severity, source, page, message, stack_trace,
       device_platform, device_model, app_version, app_build, metadata
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     RETURNING id`,
    [
      user?.sub || null,
      severity,
      String(payload.source || 'flutter').slice(0, 40),
      textOrNull(payload.page, 120),
      message.slice(0, 4000),
      textOrNull(payload.stackTrace, 12000),
      textOrNull(payload.devicePlatform, 80),
      textOrNull(payload.deviceModel, 160),
      textOrNull(payload.appVersion, 40),
      textOrNull(payload.appBuild, 40),
      payload.metadata && typeof payload.metadata === 'object'
        ? JSON.stringify(payload.metadata)
        : '{}'
    ]
  );
  return { id: rows[0].id };
}

async function listAppErrors(adminUser, { limit = 50 } = {}) {
  const conditions = [];
  const params = [];
  let idx = 1;

  if (adminUser?.sub && !(await isPrimaryAdmin(adminUser.sub))) {
    conditions.push(`(
      u.created_by_admin_id = $${idx}
      OR EXISTS (
        SELECT 1 FROM tests t
        JOIN test_attempts a ON a.test_id = t.id
        WHERE a.student_id = r.user_id AND t.created_by = $${idx}
      )
      OR r.user_id = $${idx}
    )`);
    params.push(adminUser.sub);
    idx++;
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const max = Math.min(Number(limit || 50), 200);
  return query(
    `SELECT r.id, r.severity, r.source, r.page, r.message, r.stack_trace,
            r.device_platform, r.device_model, r.app_version, r.app_build,
            r.metadata, r.created_at,
            u.full_name, u.email, u.college_name, u.phone, u.role,
            b.name AS branch_name, b.code AS branch_code
     FROM app_error_reports r
     LEFT JOIN users u ON u.id = r.user_id
     LEFT JOIN branches b ON b.id = u.branch_id
     ${where}
     ORDER BY r.created_at DESC
     LIMIT $${idx}`,
    [...params, max]
  );
}

async function analyticsSummary(adminUser) {
  const primary = adminUser?.sub ? await isPrimaryAdmin(adminUser.sub) : false;
  const params = [];
  let adminScope = '';
  if (adminUser?.sub && !primary) {
    params.push(adminUser.sub);
    adminScope = 'AND t.created_by = $1';
  }

  const testsToday = await query(
    `SELECT COUNT(*)::INT AS count
     FROM tests t
     WHERE t.deleted_at IS NULL
       AND t.scheduled_start::date = CURRENT_DATE
       ${adminScope}`,
    params
  );

  const attemptsToday = await query(
    `SELECT COUNT(*)::INT AS count
     FROM test_attempts a
     JOIN tests t ON t.id = a.test_id
     WHERE a.started_at::date = CURRENT_DATE
       ${adminScope}`,
    params
  );

  const usersParams = [];
  let usersScope = '';
  if (adminUser?.sub && !primary) {
    usersParams.push(adminUser.sub);
    usersScope = 'AND (created_by_admin_id = $1 OR id = $1)';
  }
  const totalUsers = await query(
    `SELECT COUNT(*)::INT AS count
     FROM users
     WHERE is_active = true
       AND role IN ('student', 'admin')
       ${usersScope}`,
    usersParams
  );

  const errorRows = await query(
    `SELECT
       COUNT(*) FILTER (WHERE severity = 'error')::INT AS errors,
       COUNT(*) FILTER (WHERE severity = 'crash')::INT AS crashes
     FROM app_error_reports
     WHERE created_at >= CURRENT_DATE`
  );

  const recent = await listAppErrors(adminUser, { limit: 25 });
  return {
    tests_conducted_today: testsToday[0]?.count || 0,
    user_attempts_today: attemptsToday[0]?.count || 0,
    total_users: totalUsers[0]?.count || 0,
    app_errors_today: errorRows[0]?.errors || 0,
    crash_reports_today: errorRows[0]?.crashes || 0,
    recent_reports: recent
  };
}

async function isPrimaryAdmin(adminId) {
  const rows = await query(
    'SELECT is_primary_admin FROM users WHERE id = $1 AND role = $2 AND is_active = true LIMIT 1',
    [adminId, 'admin']
  );
  return rows[0]?.is_primary_admin === true;
}

function textOrNull(value, max) {
  const text = String(value || '').trim();
  return text ? text.slice(0, max) : null;
}

module.exports = { recordAppError, listAppErrors, analyticsSummary };
