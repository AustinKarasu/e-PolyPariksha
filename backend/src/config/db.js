const { Pool } = require('pg');
const { env } = require('./env');

const pool = new Pool({
  host: env.db.host,
  port: env.db.port,
  user: env.db.user,
  password: env.db.password,
  database: env.db.database,
  ssl: env.db.ssl ? { rejectUnauthorized: false } : false,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000
});

// Helper: execute a parameterized query
// Usage: db.query('SELECT * FROM users WHERE id = $1', [userId])
async function query(text, params = []) {
  const res = await pool.query(text, params);
  return res.rows;
}

module.exports = { pool, query };
