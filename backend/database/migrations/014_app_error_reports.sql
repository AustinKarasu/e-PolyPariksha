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

CREATE INDEX IF NOT EXISTS idx_app_error_reports_created ON app_error_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_error_reports_user ON app_error_reports(user_id);
