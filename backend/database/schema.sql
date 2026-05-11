-- PolyH.T Database Schema (PostgreSQL / Supabase)

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
  email VARCHAR(160) UNIQUE,
  college_id VARCHAR(60) UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(10) NOT NULL CHECK (role IN ('admin', 'student')),
  branch_id INT REFERENCES branches(id),
  dob DATE,
  semester SMALLINT,
  roll_no VARCHAR(40),
  board_roll_no VARCHAR(40),
  college_name VARCHAR(200) DEFAULT 'Govt. Polytechnic Kangra',
  course_name VARCHAR(120),
  guardian_name VARCHAR(120),
  phone VARCHAR(20),
  address TEXT,
  admission_year INT,
  photo_url VARCHAR(500),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tests (
  id SERIAL PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  branch_id INT NOT NULL REFERENCES branches(id),
  pdf_path VARCHAR(500) NOT NULL,
  scheduled_start TIMESTAMP NOT NULL,
  scheduled_end TIMESTAMP NOT NULL,
  time_limit_minutes INT NOT NULL DEFAULT 60,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by INT NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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

CREATE INDEX IF NOT EXISTS idx_attempts_student ON test_attempts(student_id);
CREATE INDEX IF NOT EXISTS idx_attempts_test ON test_attempts(test_id);
CREATE INDEX IF NOT EXISTS idx_events_attempt ON exam_events(attempt_id);
CREATE INDEX IF NOT EXISTS idx_events_test ON exam_events(test_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON auth_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_jti ON auth_sessions(token_jti);
