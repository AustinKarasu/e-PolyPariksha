# e-PolyPariksha HP Database

The schema is in `backend/database/schema.sql`.

The production backend is wired for Supabase PostgreSQL. Supabase is PostgreSQL-based, so the schema uses PostgreSQL features such as `SERIAL`, `CHECK`, `JSONB`, and `ON CONFLICT`.

## Main Tables

- `users`: Admin and student accounts. Passwords are stored as bcrypt hashes.
- `auth_sessions`: JWT session registry with revocation and expiry checks.
- `branches`: Polytechnic branches supported by the system.
- `tests`: PDF metadata, assigned branch, schedule, and time limit.
- `test_attempts`: Student start, completion, lockout, and admin allow records.
- `exam_events`: Branch-level audit log for mobile actions during tests.

## Branch Seed Data

- Computer Engg
- Mechanical Engg
- Electrical Engg
- Instrumental Engg
- Electronic Engg
- Civil Engg

## Security Notes

- Never store plaintext passwords.
- Keep `JWT_SECRET` private and long.
- Serve uploaded PDFs only through authenticated API routes in production.
- Validate scheduling server-side before allowing PDF downloads.
- If a student backgrounds, closes, or tries to leave the exam screen, the server marks the attempt `blocked`.
- A blocked student cannot download the PDF again until an admin uses the allow endpoint.
- Admin logs can be filtered by branch, test, or student.
