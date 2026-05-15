const jwt = require('jsonwebtoken');
const { env } = require('../config/env');
const { query } = require('../config/db');
const { ApiError } = require('../utils/api-error');

async function authenticate(req, _res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return next(new ApiError(401, 'Authentication token is required'));
  }

  try {
    const payload = jwt.verify(token, env.jwtSecret);
    const sessions = await query(
      `SELECT s.id, u.branch_id, u.semester, u.created_by_admin_id
       FROM auth_sessions s
       JOIN users u ON u.id = s.user_id
       WHERE s.token_jti = $1 AND s.revoked_at IS NULL AND s.expires_at > CURRENT_TIMESTAMP
       LIMIT 1`,
      [payload.jti]
    );
    if (!sessions[0]) {
      return next(new ApiError(401, 'Session expired or revoked'));
    }
    req.user = {
      ...payload,
      branchId: sessions[0].branch_id ?? payload.branchId,
      semester: sessions[0].semester ?? payload.semester,
      createdByAdminId: sessions[0].created_by_admin_id ?? payload.createdByAdminId
    };
    return next();
  } catch (_err) {
    return next(new ApiError(401, 'Invalid or expired token'));
  }
}

function requireRole(...roles) {
  return (req, _res, next) => {
    if (!roles.includes(req.user.role)) {
      return next(new ApiError(403, 'You do not have permission for this action'));
    }
    return next();
  };
}

module.exports = { authenticate, requireRole };
