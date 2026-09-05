const jwt = require('jsonwebtoken');
const { env } = require('../config/env');
const { query } = require('../config/db');
const { ApiError } = require('../utils/api-error');

async function authenticate(req, _res, next) {
  const header = req.headers.authorization || '';
  const token = /^Bearer\s+([A-Za-z0-9._-]{20,4096})$/.exec(header)?.[1] || null;

  if (!token) {
    return next(new ApiError(401, 'Authentication token is required'));
  }

  try {
    const payload = jwt.verify(token, env.jwtSecret, {
      algorithms: ['HS256'],
      issuer: env.jwtIssuer,
      audience: env.jwtAudience
    });

    if (
      !Number.isInteger(payload.sub) ||
      !['admin', 'student'].includes(payload.role) ||
      typeof payload.jti !== 'string'
    ) {
      return next(new ApiError(401, 'Invalid authentication token'));
    }

    const sessions = await query(
      `SELECT s.id, u.branch_id, u.semester, u.created_by_admin_id
       FROM auth_sessions s
       JOIN users u ON u.id = s.user_id
       WHERE s.token_jti = $1 AND s.user_id = $2 AND u.role = $3 AND u.is_active = true
         AND s.revoked_at IS NULL AND s.expires_at > CURRENT_TIMESTAMP
       LIMIT 1`,
      [payload.jti, payload.sub, payload.role]
    );

    let session = sessions[0];
    if (!session) {
      const activeUsers = await query(
        `SELECT id, branch_id, semester, created_by_admin_id
         FROM users
         WHERE id = $1 AND role = $2 AND is_active = true
         LIMIT 1`,
        [payload.sub, payload.role]
      );
      if (activeUsers[0]) {
        await query(
          `INSERT INTO auth_sessions (user_id, token_jti, expires_at)
           VALUES ($1, $2, to_timestamp($3))
           ON CONFLICT (token_jti) DO UPDATE SET revoked_at = NULL, expires_at = to_timestamp($3)`,
          [payload.sub, payload.jti, payload.exp || Math.floor(Date.now() / 1000) + 86400 * 30]
        );
        session = activeUsers[0];
      }
    }

    if (!session) {
      return next(new ApiError(401, 'Session expired or revoked'));
    }

    req.user = {
      ...payload,
      branchId: session.branch_id ?? payload.branchId,
      semester: session.semester ?? payload.semester,
      createdByAdminId: session.created_by_admin_id ?? payload.createdByAdminId
    };
    return next();
  } catch (_err) {
    return next(new ApiError(401, 'Invalid or expired token'));
  }
}

function requireRole(...roles) {
  return (req, _res, next) => {
    if (!roles.includes(req.user?.role)) {
      return next(new ApiError(403, 'You do not have permission for this action'));
    }
    return next();
  };
}

module.exports = { authenticate, requireRole };
