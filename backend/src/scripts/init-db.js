const { pool, query } = require('../config/db');
const fs = require('fs');
const path = require('path');

async function main() {
  console.log('Connecting to Supabase PostgreSQL...');
  
  const schemaPath = path.join(__dirname, '..', '..', 'database', 'schema.sql');
  const schema = fs.readFileSync(schemaPath, 'utf-8');
  
  // Split by semicolons and run each statement
  const statements = schema
    .split(';')
    .map(s => s.trim())
    .filter(s => s.length > 0);
  
  for (const stmt of statements) {
    try {
      await pool.query(stmt);
      console.log('✓', stmt.substring(0, 60).replace(/\n/g, ' ') + '...');
    } catch (err) {
      console.error('✗ Error:', err.message);
      console.error('  Statement:', stmt.substring(0, 80));
    }
  }
  
  console.log('\nSchema initialized successfully!');
}

main()
  .catch(err => { console.error('Fatal:', err.message); process.exit(1); })
  .finally(() => pool.end());
