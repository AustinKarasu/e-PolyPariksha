-- e-PolyPariksha HP Database Schema (PostgreSQL)

CREATE TABLE IF NOT EXISTS branches (
  id SERIAL PRIMARY KEY,
  name VARCHAR(80) NOT NULL,
  code VARCHAR(10) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO branches (name, code) VALUES
  ('Computer Engg', 'CE'),
  ('Mechanical Engg', 'ME'),
  ('Electrical Engg', 'EE'),
  ('Instrumental Engg', 'IE'),
  ('Electronic Engg', 'EC'),
  ('Civil Engg', 'CV')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  first_name VARCHAR(60),
  middle_name VARCHAR(60),
  last_name VARCHAR(60),
  email VARCHAR(160) UNIQUE,
  college_id VARCHAR(60) UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(10) NOT NULL CHECK (role IN ('admin', 'student')),
  created_by_admin_id INT REFERENCES users(id),
  branch_id INT REFERENCES branches(id),
  dob DATE,
  semester SMALLINT,
  roll_no VARCHAR(40),
  board_roll_no VARCHAR(40),
  college_name VARCHAR(200) DEFAULT 'Govt. Polytechnic Kangra',
  state_name VARCHAR(80),
  course_name VARCHAR(120),
  guardian_name VARCHAR(120),
  phone VARCHAR(20),
  address TEXT,
  admission_year INT,
  dropout_year INT,
  photo_url TEXT,
  two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  two_factor_secret VARCHAR(160),
  biometric_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  must_change_credentials BOOLEAN NOT NULL DEFAULT FALSE,
  is_primary_admin BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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

CREATE TABLE IF NOT EXISTS tests (
  id SERIAL PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  branch_id INT NOT NULL REFERENCES branches(id),
  semester SMALLINT NOT NULL DEFAULT 1 CHECK (semester BETWEEN 1 AND 6),
  pdf_path VARCHAR(500) NOT NULL,
  pdf_data BYTEA,
  pdf_original_name VARCHAR(255),
  pdf_mime_type VARCHAR(120) DEFAULT 'application/pdf',
  pdf_size INT,
  scheduled_start TIMESTAMPTZ NOT NULL,
  scheduled_end TIMESTAMPTZ NOT NULL,
  time_limit_minutes INT NOT NULL DEFAULT 60,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by INT NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS test_attempts (
  id SERIAL PRIMARY KEY,
  test_id INT NOT NULL REFERENCES tests(id),
  student_id INT NOT NULL REFERENCES users(id),
  status VARCHAR(20) NOT NULL DEFAULT 'started' CHECK (status IN ('started', 'blocked', 'completed', 'admin_allowed')),
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  blocked_at TIMESTAMP,
  blocked_reason VARCHAR(120),
  allowed_by INT REFERENCES users(id),
  allowed_at TIMESTAMP,
  answer_note TEXT,
  UNIQUE(student_id, test_id)
);

CREATE TABLE IF NOT EXISTS exam_events (
  id SERIAL PRIMARY KEY,
  attempt_id INT REFERENCES test_attempts(id),
  test_id INT NOT NULL REFERENCES tests(id),
  student_id INT NOT NULL REFERENCES users(id),
  branch_id INT NOT NULL REFERENCES branches(id),
  event_type VARCHAR(60) NOT NULL,
  severity VARCHAR(20) NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  message TEXT,
  metadata JSONB DEFAULT '{}',
  ip_address VARCHAR(50),
  user_agent VARCHAR(300),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auth_sessions (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id),
  token_jti VARCHAR(128) NOT NULL UNIQUE,
  device_label VARCHAR(120),
  ip_address VARCHAR(50),
  user_agent VARCHAR(300),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  revoked_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS login_failures (
  identifier_hash VARCHAR(64) NOT NULL,
  ip_address VARCHAR(50) NOT NULL,
  failed_count INT NOT NULL DEFAULT 0,
  first_failed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_failed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  locked_until TIMESTAMP,
  PRIMARY KEY (identifier_hash, ip_address)
);

CREATE TABLE IF NOT EXISTS email_otps (
  id SERIAL PRIMARY KEY,
  email VARCHAR(160) NOT NULL,
  purpose VARCHAR(40) NOT NULL,
  code_hash VARCHAR(64) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS otp_security (
  email VARCHAR(160) NOT NULL,
  purpose VARCHAR(40) NOT NULL,
  failed_attempts INT NOT NULL DEFAULT 0,
  failed_window_started_at TIMESTAMPTZ,
  locked_until TIMESTAMPTZ,
  PRIMARY KEY (email, purpose)
);

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  token_nonce UUID PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS email_notifications (
  id SERIAL PRIMARY KEY,
  event_key VARCHAR(255) NOT NULL UNIQUE,
  event_type VARCHAR(40) NOT NULL,
  test_id INT REFERENCES tests(id) ON DELETE CASCADE,
  recipient_email VARCHAR(160) NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_attempts_student ON test_attempts(student_id);
CREATE INDEX IF NOT EXISTS idx_attempts_test ON test_attempts(test_id);
CREATE INDEX IF NOT EXISTS idx_events_attempt ON exam_events(attempt_id);
CREATE INDEX IF NOT EXISTS idx_events_test ON exam_events(test_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON auth_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_jti ON auth_sessions(token_jti);

CREATE TABLE IF NOT EXISTS admin_trusted_devices (
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_key VARCHAR(64) NOT NULL,
  verified_until TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, device_key)
);

CREATE TABLE IF NOT EXISTS app_error_reports (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id) ON DELETE SET NULL,
  severity VARCHAR(20) NOT NULL DEFAULT 'error' CHECK (severity IN ('error', 'crash')),
  source VARCHAR(40) NOT NULL DEFAULT 'flutter',
  page VARCHAR(120),
  message TEXT NOT NULL,
  stack_trace TEXT,
  device_platform VARCHAR(80),
  device_model VARCHAR(160),
  app_version VARCHAR(40),
  app_build VARCHAR(40),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_email_otps_lookup ON email_otps (email, purpose, expires_at);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user ON password_reset_tokens (user_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_email_notifications_test ON email_notifications (test_id, event_type);
CREATE INDEX IF NOT EXISTS idx_users_created_by_admin ON users(created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_tests_created_by ON tests(created_by);
CREATE INDEX IF NOT EXISTS idx_admin_applications_status ON admin_applications(status);
CREATE INDEX IF NOT EXISTS idx_app_error_reports_created ON app_error_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_error_reports_user ON app_error_reports(user_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_one_primary_admin
  ON users (role)
  WHERE role = 'admin' AND is_primary_admin = TRUE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_student_board_roll_no
  ON users (board_roll_no)
  WHERE role = 'student' AND board_roll_no IS NOT NULL AND board_roll_no <> '';
