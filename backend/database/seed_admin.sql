-- Optional first-admin seed for PostgreSQL.
-- Replace every value before running. Do not commit real password hashes.

INSERT INTO users (full_name, email, password_hash, role, is_active, is_primary_admin)
VALUES (
  '<Admin Full Name>',
  '<admin-email@example.edu>',
  '<bcrypt-password-hash>',
  'admin',
  TRUE,
  TRUE
)
ON CONFLICT (email) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  password_hash = EXCLUDED.password_hash,
  role = 'admin',
  is_active = TRUE,
  is_primary_admin = TRUE,
  updated_at = CURRENT_TIMESTAMP;
