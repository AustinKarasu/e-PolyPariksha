# PolyH.T - Polytechnic House Test System

Govt. Polytechnic Kangra

PolyH.T is a dual-app mobile examination system for securely administering and taking house tests. It includes two Flutter apps, a Node.js/Express REST API, a Supabase PostgreSQL database, and optional Supabase Storage/S3-compatible PDF storage.

## Project Structure

```text
apps/
  polyht_admin/        Flutter Admin app
  polyht_student/      Flutter Student app
backend/              Node.js Express API
  database/           SQL schema and migrations
  src/                Controllers, services, middleware, routes
docs/                 API, database, security, release, deployment docs
website/              Public APK release manifests and downloads
.github/workflows/    CI, Vercel deploy, APK release automation
```

## Features

### PolyH.T Admin

- Secure admin login with JWT session tracking.
- Dashboard for Computer, Mechanical, Electrical, Instrumental, Electronic, and Civil Engg branches.
- Upload, schedule, replace, and remove PDF question papers.
- Configure scheduled start/end time and test duration.
- Manage student profiles and admin accounts.
- Review exam security events and unlock blocked attempts.
- Professional purple theme with light/dark support.

### PolyH.T Student

- Login with college-provided credentials.
- View assigned tests by branch.
- Open PDFs only during the scheduled exam window.
- Secure exam mode with screenshot blocking, app pinning, back-button blocking, wakelock, and app lifecycle event logging.
- Submit/mark PDF-based tests complete.
- Student profile and update checks.

### Backend

- Express REST API with role-based authorization.
- Supabase PostgreSQL schema for users, branches, tests, attempts, events, and sessions.
- Bcrypt password hashing.
- JWT authentication plus server-side session revocation.
- PDF upload/download through local storage in development or Supabase Storage/S3 in production.
- Helmet, CORS allowlist, rate limiting, HPP protection, validation, and centralized error handling.

## Setup

### Backend

```bash
cd backend
cp .env.example .env
npm install
npm start
```

For Supabase production setup, see [docs/supabase.md](docs/supabase.md).

Initialize the database by running:

```text
backend/database/schema.sql
backend/database/migrations/*.sql
```

Create the first admin:

```bash
cd backend
npm run create-user
```

### Flutter Apps

Set the API base URL at build time:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-vercel-project.vercel.app/api
```

Local defaults are in:

- `apps/polyht_admin/lib/config/api_config.dart`
- `apps/polyht_student/lib/config/api_config.dart`

## Documentation

- [API Reference](docs/api.md)
- [Database](docs/database.md)
- [Supabase Setup](docs/supabase.md)
- [Security](docs/security.md)
- [Security Hardening](docs/security-hardening.md)
- [Vercel Deployment](docs/vercel.md)
- [Release Process](docs/release.md)

## Deployment and Releases

- Backend deployment to Vercel is configured in `.github/workflows/vercel-deploy.yml`.
- APK release automation is configured in `.github/workflows/release-apk.yml`.
- The release workflow builds both Android APKs, creates a GitHub Release, attaches both APKs, and publishes update manifests.

## Important Security Note

Real `.env` and `.env.production` files must never be committed. Store Supabase, JWT, Vercel, Android signing, and storage secrets in Vercel environment variables or GitHub repository secrets.

If a secret was previously committed, rotate it immediately in Supabase/Vercel/GitHub before production use.
