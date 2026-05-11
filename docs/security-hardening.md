# Security Hardening

Implemented controls:

- Bcrypt password hashes.
- JWT sessions backed by `auth_sessions` for server-side logout/revocation.
- Role-based authorization for admin and student APIs.
- Parameterized PostgreSQL/Supabase queries through `pg`, preventing SQL injection.
- Request validation through `express-validator`.
- Helmet security headers.
- CORS allowlist through `CORS_ORIGINS`.
- Global API rate limiting.
- Stricter login rate limiting for brute-force protection.
- HTTP parameter pollution protection.
- Body size limits.
- PDF MIME/type and file-size validation.
- Branch, schedule, attempt-state, and lockout checks before PDF access.
- Student app-switch/close/back events logged to `exam_events`.
- Admin-only account creation; no public registration route exists.

Operational requirements:

- Use HTTPS only.
- Keep `JWT_SECRET`, DB credentials, and S3 credentials in Vercel/GitHub secrets.
- Rotate the initial admin password after first login.
- Use Supabase pooled PostgreSQL with backups, SSL, and restricted credentials.
- Keep APK signing keystore outside Git and store it in GitHub secrets.
