# e-PolyPariksha HP - Polytechnic Test System

Govt. Polytechnic Kangra

e-PolyPariksha HP is a combined mobile examination system for securely administering and taking house tests. It includes one Flutter APK with Admin and Student portals, a Node.js/Express REST API, PostgreSQL, and optional S3-compatible PDF storage.

## Project Structure

```text
apps/
  e-PolyPariksha HP_admin/        Combined Flutter Admin and Student app
backend/              Node.js Express API
  database/           SQL schema and migrations
  src/                Controllers, services, middleware, routes
docs/                 API, database, security, release, deployment docs
website/              Public app release manifests and downloads
.github/workflows/    CI and app release automation
```

### e-PolyPariksha HP Student

- Login with college-provided credentials.
- View assigned tests by branch.
- Open PDFs only during the scheduled exam window.
- Secure exam mode with screenshot blocking, app pinning, back-button blocking, wakelock, and app lifecycle event logging.
- Submit/mark PDF-based tests complete.
- Student profile and update checks.


## Documentation

- [API Reference](docs/api.md)
- [Database](docs/database.md)
- [Security](docs/security.md)
- [Security Hardening](docs/security-hardening.md)
- [Release Process](docs/release.md)
