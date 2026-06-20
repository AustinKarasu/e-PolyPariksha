require('dotenv').config();

const jwtSecret = process.env.JWT_SECRET || '';
if (process.env.NODE_ENV === 'production' && (jwtSecret.length < 32 || jwtSecret === 'dev_secret_change_me')) {
  throw new Error('JWT_SECRET must be a unique value of at least 32 characters in production');
}

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 4000),
  trustProxy: process.env.TRUST_PROXY || '0',
  corsOrigins: (process.env.CORS_ORIGINS || '').split(',').map((item) => item.trim()).filter(Boolean),
  bodyLimit: process.env.BODY_LIMIT || '1mb',
  rateLimit: {
    authWindowMs: Number(process.env.AUTH_RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
    authMax: Number(process.env.AUTH_RATE_LIMIT_MAX || 8),
    globalWindowMs: Number(process.env.GLOBAL_RATE_LIMIT_WINDOW_MS || 60 * 1000),
    globalMax: Number(process.env.GLOBAL_RATE_LIMIT_MAX || 120)
  },
  db: {
    connectionString: process.env.DATABASE_URL || '',
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'postgres',
    ssl: process.env.DB_SSL === 'true' || process.env.DB_SSL === '1'
  },
  jwtSecret: jwtSecret || 'dev_secret_change_me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '8h',
  jwtIssuer: process.env.JWT_ISSUER || 'epolypariksha-hp-api',
  jwtAudience: process.env.JWT_AUDIENCE || 'epolypariksha-hp-mobile',
  uploadDir: process.env.UPLOAD_DIR || 'uploads',
  storage: {
    driver: process.env.STORAGE_DRIVER || 'local',
    s3: {
      region: process.env.S3_REGION || 'ap-south-1',
      bucket: process.env.S3_BUCKET || '',
      accessKeyId: process.env.S3_ACCESS_KEY_ID || '',
      secretAccessKey: process.env.S3_SECRET_ACCESS_KEY || '',
      endpoint: process.env.S3_ENDPOINT || '',
      publicBaseUrl: process.env.S3_PUBLIC_BASE_URL || ''
    }
  },
  smtp: {
    host: process.env.SMTP_HOST || '',
    port: Number(process.env.SMTP_PORT || 587),
    secure: process.env.SMTP_SECURE === 'true' || process.env.SMTP_SECURE === '1',
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.MAIL_FROM || process.env.SMTP_USER || ''
  }
};

module.exports = { env };
