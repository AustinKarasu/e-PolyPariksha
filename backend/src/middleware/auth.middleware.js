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
      `SELECT id FROM auth_sessions
       WHERE token_jti = $1 AND revoked_at IS NULL AND expires_at > CURRENT_TIMESTAMP
       LIMIT 1`,
      [payload.jti]
    );
    if (!sessions[0]) {
      return next(new ApiError(401, 'Session expired or revoked'));
    }
    req.user = payload;
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
