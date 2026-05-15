ALTER TABLE users
  ADD COLUMN IF NOT EXISTS first_name VARCHAR(60),
  ADD COLUMN IF NOT EXISTS middle_name VARCHAR(60),
  ADD COLUMN IF NOT EXISTS last_name VARCHAR(60),
  ADD COLUMN IF NOT EXISTS created_by_admin_id INT REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS state_name VARCHAR(80),
  ADD COLUMN IF NOT EXISTS dropout_year INT;

ALTER TABLE tests
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_users_created_by_admin ON users(created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_tests_created_by ON tests(created_by);

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
  reviewed_at TIMESTAMP,
  created_admin_id INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_admin_applications_status ON admin_applications(status);

CREATE TABLE IF NOT EXISTS login_failures (
  identifier_hash VARCHAR(64) NOT NULL,
  ip_address VARCHAR(50) NOT NULL,
  failed_count INT NOT NULL DEFAULT 0,
  first_failed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_failed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  locked_until TIMESTAMP,
  PRIMARY KEY (identifier_hash, ip_address)
);

UPDATE users
SET is_primary_admin = TRUE,
    is_active = TRUE,
    updated_at = CURRENT_TIMESTAMP
WHERE role = 'admin'
  AND lower(email) = 'admin@gpkangra.edu';
