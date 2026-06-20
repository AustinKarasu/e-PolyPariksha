const compression = require('compression');
const cors = require('cors');
const helmet = require('helmet');
const hpp = require('hpp');
const rateLimit = require('express-rate-limit');
const { env } = require('../config/env');
const { ApiError } = require('../utils/api-error');

function clientIp(req) {
  return req.ip || req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown-ip';
}

function normalizedBodyValue(req, field) {
  return String(req.body?.[field] || '').trim().toLowerCase();
}

const globalLimiter = rateLimit({
  windowMs: env.rateLimit.globalWindowMs,
  limit: env.rateLimit.globalMax,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  skip: (req) => req.path.startsWith('/api/auth/')
});

const authLimiter = rateLimit({
  windowMs: env.rateLimit.authWindowMs,
  limit: Math.max(env.rateLimit.authMax, 30),
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  requestWasSuccessful: (_req, res) => res.statusCode < 400 || res.statusCode >= 500,
  keyGenerator: (req) => {
    const identity = normalizedBodyValue(req, 'identifier') || normalizedBodyValue(req, 'email') || 'anonymous';
    return [clientIp(req), req.method, req.baseUrl, req.path, identity].join(':');
  },
  message: { message: 'Too many authentication attempts. Try again later.' }
});

const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  skipFailedRequests: true,
  requestWasSuccessful: (_req, res) => res.statusCode < 400,
  keyGenerator: (req) => {
    const email = normalizedBodyValue(req, 'email') || 'missing-email';
    const role = normalizedBodyValue(req, 'role') || 'missing-role';
    return [clientIp(req), req.method, req.baseUrl, req.path, role, email].join(':');
  },
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
