CREATE TABLE IF NOT EXISTS otp_security (
  email VARCHAR(160) NOT NULL,
  purpose VARCHAR(40) NOT NULL,
  failed_attempts INT NOT NULL DEFAULT 0,
  failed_window_started_at TIMESTAMPTZ,
  locked_until TIMESTAMPTZ,
  PRIMARY KEY (email, purpose)
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS biometric_enabled BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS email_notifications (
  id SERIAL PRIMARY KEY,
  event_key VARCHAR(255) NOT NULL UNIQUE,
  event_type VARCHAR(40) NOT NULL,
  test_id INT REFERENCES tests(id) ON DELETE CASCADE,
  recipient_email VARCHAR(160) NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_email_notifications_test ON email_notifications (test_id, event_type);
