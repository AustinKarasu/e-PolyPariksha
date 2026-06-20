const compression = require('compression');
const cors = require('cors');
const helmet = require('helmet');
const hpp = require('hpp');
const rateLimit = require('express-rate-limit');
const { env } = require('../config/env');
const { ApiError } = require('../utils/api-error');

const globalLimiter = rateLimit({
  windowMs: env.rateLimit.globalWindowMs,
  limit: env.rateLimit.globalMax,
  standardHeaders: 'draft-7',
  legacyHeaders: false
});

const authLimiter = rateLimit({
  windowMs: env.rateLimit.authWindowMs,
  limit: env.rateLimit.authMax,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { message: 'Too many authentication attempts. Try again later.' }
});

const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { message: 'Too many password reset attempts. Try again in one hour.' }
});

function corsMiddleware() {
  return cors({
    origin(origin, callback) {
      if (!origin || env.corsOrigins.includes('*') || env.corsOrigins.includes(origin)) {
        return callback(null, true);
      }
      if (env.nodeEnv !== 'production' && env.corsOrigins.length === 0) return callback(null, true);
      return callback(new ApiError(403, 'Origin is not allowed'));
    }
  });
}

module.exports = {
  compression,
  corsMiddleware,
  helmet,
  hpp,
  globalLimiter,
  authLimiter,
  passwordResetLimiter
};
