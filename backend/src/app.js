const express = require('express');
const path = require('path');
const { env } = require('./config/env');
const authRoutes = require('./routes/auth.routes');
const adminRoutes = require('./routes/admin.routes');
const branchRoutes = require('./routes/branch.routes');
const testRoutes = require('./routes/test.routes');
const attemptRoutes = require('./routes/attempt.routes');
const studentRoutes = require('./routes/student.routes');
const { errorHandler } = require('./middleware/error.middleware');
const {
  compression,
  corsMiddleware,
  helmet,
  hpp,
  globalLimiter
} = require('./middleware/security.middleware');

const app = express();

app.set('trust proxy', env.trustProxy);
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(corsMiddleware());
app.use(compression());
app.use(hpp());
app.use(globalLimiter);
app.use(express.json({ limit: env.bodyLimit }));

if (env.storage.driver === 'local') {
  app.use('/uploads', express.static(process.env.VERCEL ? '/tmp' : path.resolve(env.uploadDir)));
}

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'epolypariksha-hp-api' });
});

app.use('/api/auth', authRoutes);
app.use('/api/admins', adminRoutes);
app.use('/api/branches', branchRoutes);
app.use('/api/tests', testRoutes);
app.use('/api/attempts', attemptRoutes);
app.use('/api/students', studentRoutes);
app.use(errorHandler);

module.exports = app;
