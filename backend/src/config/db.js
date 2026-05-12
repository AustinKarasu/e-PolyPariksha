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
