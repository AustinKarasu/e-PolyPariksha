const { Pool } = require('pg');
const { env } = require('./env');

const pool = new Pool({
  connectionString: env.db.connectionString || undefined,
  host: env.db.connectionString ? undefined : env.db.host,
  port: env.db.connectionString ? undefined : env.db.port,
  user: env.db.connectionString ? undefined : env.db.user,
  password: env.db.connectionString ? undefined : env.db.password,
  database: env.db.connectionString ? undefined : env.db.database,
  ssl: env.db.ssl ? { rejectUnauthorized: false } : false,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000
});

let runtimeSchemaReady;

async function ensureRuntimeSchema() {
  if (!runtimeSchemaReady) {
    runtimeSchemaReady = pool.query(`
      ALTER TABLE tests
        ADD COLUMN IF NOT EXISTS semester SMALLINT NOT NULL DEFAULT 1;
      ALTER TABLE tests
        ADD COLUMN IF NOT EXISTS pdf_data BYTEA,
        ADD COLUMN IF NOT EXISTS pdf_original_name VARCHAR(255),
        ADD COLUMN IF NOT EXISTS pdf_mime_type VARCHAR(120) DEFAULT 'application/pdf',
        ADD COLUMN IF NOT EXISTS pdf_size INT,
        ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
      ALTER TABLE tests
        DROP CONSTRAINT IF EXISTS tests_semester_check;
      ALTER TABLE tests
        ADD CONSTRAINT tests_semester_check CHECK (semester BETWEEN 1 AND 6);

      ALTER TABLE test_attempts
        DROP CONSTRAINT IF EXISTS test_attempts_test_id_fkey,
        DROP CONSTRAINT IF EXISTS fk_attempts_test;
      ALTER TABLE test_attempts
        ADD CONSTRAINT test_attempts_test_id_fkey
          FOREIGN KEY (test_id) REFERENCES tests(id) ON DELETE CASCADE;

      ALTER TABLE exam_events
        DROP CONSTRAINT IF EXISTS exam_events_attempt_id_fkey,
        DROP CONSTRAINT IF EXISTS fk_events_attempt;
      ALTER TABLE exam_events
        ADD CONSTRAINT exam_events_attempt_id_fkey
          FOREIGN KEY (attempt_id) REFERENCES test_attempts(id) ON DELETE SET NULL;

      ALTER TABLE exam_events
        DROP CONSTRAINT IF EXISTS exam_events_test_id_fkey,
        DROP CONSTRAINT IF EXISTS fk_events_test;
      ALTER TABLE exam_events
        ADD CONSTRAINT exam_events_test_id_fkey
          FOREIGN KEY (test_id) REFERENCES tests(id) ON DELETE CASCADE;

      CREATE TABLE IF NOT EXISTS login_failures (
        id SERIAL PRIMARY KEY,
        identifier_hash VARCHAR(64) NOT NULL,
        ip_address VARCHAR(64) NOT NULL,
        failed_count INT NOT NULL DEFAULT 1,
        first_failed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_failed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
        locked_until TIMESTAMPTZ,
        UNIQUE(identifier_hash, ip_address)
      );

      CREATE INDEX IF NOT EXISTS idx_login_failures_locked
        ON login_failures (identifier_hash, ip_address, locked_until);

      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS first_name VARCHAR(60),
        ADD COLUMN IF NOT EXISTS middle_name VARCHAR(60),
        ADD COLUMN IF NOT EXISTS last_name VARCHAR(60),
        ADD COLUMN IF NOT EXISTS created_by_admin_id INT REFERENCES users(id),
        ADD COLUMN IF NOT EXISTS state_name VARCHAR(80),
        ADD COLUMN IF NOT EXISTS dropout_year INT;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS biometric_enabled BOOLEAN NOT NULL DEFAULT FALSE;

      CREATE TABLE IF NOT EXISTS admin_applications (
        id SERIAL PRIMARY KEY,
        first_name VARCHAR(60) NOT NULL,
        middle_name VARCHAR(60),
        last_name VARCHAR(60) NOT NULL,
        full_name VARCHAR(120) NOT NULL,
        mobile VARCHAR(20) NOT NULL,
        email VARCHAR(160) NOT NULL UNIQUE,
        college_name VARCHAR(200) NOT NULL,
        state_name VARCHAR(80) NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
        reviewed_by INT REFERENCES users(id),
        reviewed_at TIMESTAMPTZ,
        created_admin_id INT REFERENCES users(id),
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_users_created_by_admin ON users(created_by_admin_id);
      CREATE INDEX IF NOT EXISTS idx_tests_created_by ON tests(created_by);
      CREATE INDEX IF NOT EXISTS idx_admin_applications_status ON admin_applications(status);

      CREATE TABLE IF NOT EXISTS email_otps (
        id SERIAL PRIMARY KEY,
        email VARCHAR(160) NOT NULL,
        purpose VARCHAR(40) NOT NULL,
        code_hash VARCHAR(64) NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        consumed_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_email_otps_lookup
        ON email_otps (email, purpose, expires_at);

      CREATE TABLE IF NOT EXISTS password_reset_tokens (
        token_nonce UUID PRIMARY KEY,
        user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user
        ON password_reset_tokens (user_id, expires_at);

      CREATE TABLE IF NOT EXISTS otp_security (
        email VARCHAR(160) NOT NULL,
        purpose VARCHAR(40) NOT NULL,
        failed_attempts INT NOT NULL DEFAULT 0,
        failed_window_started_at TIMESTAMPTZ,
        locked_until TIMESTAMPTZ,
        PRIMARY KEY (email, purpose)
      );

      CREATE TABLE IF NOT EXISTS email_notifications (
        id SERIAL PRIMARY KEY,
        event_key VARCHAR(255) NOT NULL UNIQUE,
        event_type VARCHAR(40) NOT NULL,
        test_id INT REFERENCES tests(id) ON DELETE CASCADE,
        recipient_email VARCHAR(160) NOT NULL,
        sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_email_notifications_test ON email_notifications (test_id, event_type);

      UPDATE users
      SET is_primary_admin = TRUE,
          is_active = TRUE,
          updated_at = CURRENT_TIMESTAMP
      WHERE role = 'admin'
        AND lower(email) = 'aayankarasu@gmail.com';
    `).catch((err) => {
      runtimeSchemaReady = null;
      throw err;
    });
  }
  return runtimeSchemaReady;
}

// Helper: execute a parameterized query
// Usage: db.query('SELECT * FROM users WHERE id = $1', [userId])
async function query(text, params = []) {
  if (!/^\s*ALTER\s+TABLE\s+tests/i.test(text)) {
    await ensureRuntimeSchema();
  }
  const res = await pool.query(text, params);
  return res.rows;
}

async function transaction(callback) {
  await ensureRuntimeSchema();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(async (text, params = []) => {
      const res = await client.query(text, params);
      return res.rows;
    });
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { pool, query, transaction };
