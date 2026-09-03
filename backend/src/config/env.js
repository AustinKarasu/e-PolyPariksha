require('dotenv').config();

const jwtSecret = process.env.JWT_SECRET || '';
if (process.env.NODE_ENV === 'production' && (jwtSecret.length < 32 || jwtSecret === 'dev_secret_change_me')) {
  throw new Error('JWT_SECRET must be a unique value of at least 32 characters in production');
}

const env = {
  nodeEnv: (process.env.NODE_ENV || 'development').trim(),
  port: Number(process.env.PORT || 4000),
  trustProxy: (process.env.TRUST_PROXY || '0').trim(),
  corsOrigins: (process.env.CORS_ORIGINS || '').split(',').map((item) => item.trim()).filter(Boolean),
  bodyLimit: (process.env.BODY_LIMIT || '1mb').trim(),
  rateLimit: {
    authWindowMs: Number(process.env.AUTH_RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
    authMax: Number(process.env.AUTH_RATE_LIMIT_MAX || 8),
    globalWindowMs: Number(process.env.GLOBAL_RATE_LIMIT_WINDOW_MS || 60 * 1000),
    globalMax: Number(process.env.GLOBAL_RATE_LIMIT_MAX || 600)
  },
  db: {
    connectionString: (process.env.DATABASE_URL || '').trim(),
    host: (process.env.DB_HOST || 'localhost').trim(),
    port: Number(process.env.DB_PORT || 5432),
    user: (process.env.DB_USER || 'postgres').trim(),
    password: (process.env.DB_PASSWORD || '').trim(),
    database: (process.env.DB_NAME || 'postgres').trim(),
    ssl: (process.env.DB_SSL || '').trim() === 'true' || (process.env.DB_SSL || '').trim() === '1'
  },
  jwtSecret: jwtSecret.trim() || 'dev_secret_change_me',
  jwtExpiresIn: (process.env.JWT_EXPIRES_IN || '8h').trim(),
  jwtIssuer: (process.env.JWT_ISSUER || 'epolypariksha-hp-api').trim(),
  jwtAudience: (process.env.JWT_AUDIENCE || 'epolypariksha-hp-mobile').trim(),
  uploadDir: (process.env.UPLOAD_DIR || 'uploads').trim(),
  storage: {
    driver: (process.env.STORAGE_DRIVER || 'local').trim(),
    s3: {
      region: (process.env.S3_REGION || 'ap-south-1').trim(),
      bucket: (process.env.S3_BUCKET || '').trim(),
      accessKeyId: (process.env.S3_ACCESS_KEY_ID || '').trim(),
      secretAccessKey: (process.env.S3_SECRET_ACCESS_KEY || '').trim(),
      endpoint: (process.env.S3_ENDPOINT || '').trim(),
      publicBaseUrl: (process.env.S3_PUBLIC_BASE_URL || '').trim()
    }
  },
  smtp: {
    host: (process.env.SMTP_HOST || '').trim(),
    port: Number(process.env.SMTP_PORT || 587),
    secure: (process.env.SMTP_SECURE || '').trim() === 'true' || (process.env.SMTP_SECURE || '').trim() === '1',
    user: (process.env.SMTP_USER || '').trim(),
    pass: (process.env.SMTP_PASS || '').trim(),
    from: (process.env.MAIL_FROM || process.env.SMTP_USER || '').trim()
  }
};

module.exports = { env };
