# PolyH.T — Polytechnic House Test System

**Govt. Polytechnic Kangra**

A dual-app mobile examination system for securely administering and taking house tests. Built with Flutter (Admin + Student apps) and a Node.js/Express REST API backed by MySQL.

## Architecture

```
├── apps/
│   ├── polyht_admin/       # Flutter Admin app
│   └── polyht_student/     # Flutter Student app
├── backend/                # Node.js Express API
│   ├── database/           # SQL schema & migrations
│   └── src/                # Controllers, services, middleware, routes
├── docs/                   # API documentation
└── .github/workflows/      # CI/CD (lint, test, APK release)
```

## Features

### Admin App
- Upload, schedule, and manage house test PDF question papers
- Support for 6 branches: Computer, Mechanical, Electrical, Instrumental, Electronic, Civil
- Student directory with search — view every student's profile data
- Exam security logs with locked attempt management
- Admin account management (create, activate/deactivate)
- Light/Dark theme toggle

### Student App
- View scheduled house tests with live status indicators
- Secure exam mode with PDF viewer (screenshots blocked, app pinning)
- Real-time timer and page navigation during exam
- Student profile with ID card, academic, and personal info
- Light/Dark theme toggle
- Automatic lockout on app switching / background detection

### Backend API
- JWT authentication with session tracking
- Role-based access (admin / student)
- Student profile CRUD with admin oversight
- PDF storage (local filesystem or S3-compatible)
- Rate limiting, CORS, helmet, HPP security middleware
- Exam attempt lifecycle with security event logging

## Setup

### Prerequisites
- Node.js 18+
- MySQL 8+
- Flutter SDK 3.3+

### Backend

```bash
cd backend
cp .env.example .env    # Edit with your MySQL credentials and JWT secret
npm install
```

Initialize the database:

```bash
mysql -u root -p < database/schema.sql
mysql -u root -p polyht < database/migrations/002_student_profile.sql
```

Create the first admin:

```bash
npm run create-user
```

Start the server:

```bash
npm run dev     # development with nodemon
npm start       # production
```

### Flutter Apps

Update the API base URL in each app:
- `apps/polyht_admin/lib/config/api_config.dart`
- `apps/polyht_student/lib/config/api_config.dart`

```bash
cd apps/polyht_admin
flutter pub get
flutter run

cd apps/polyht_student
flutter pub get
flutter run
```

## API Reference

See [docs/api.md](docs/api.md) for the complete REST API reference.

Key endpoint groups:
- `POST /api/auth/login` — Authentication
- `GET /api/tests` — Test management
- `GET /api/students` — Student profiles (admin)
- `GET /api/students/me` — Student self-service profile
- `POST /api/attempts/:testId/start` — Exam attempts
- `GET /api/attempts/admin/locked` — Locked attempt monitoring

## CI/CD

- **CI** (`ci.yml`): Runs Flutter analyze + backend lint on every push
- **Release** (`release-apk.yml`): Builds signed APKs, creates GitHub Release with download links

## Security

- **Exam Mode**: Android `FLAG_SECURE` (blocks screenshots) + `startLockTask()` (pins app)
- **Event Detection**: `WidgetsBindingObserver` detects app lifecycle changes → logs to server → auto-locks attempt on critical events (`app_backgrounded`, `app_detached`, `back_blocked`)
- **JWT Sessions**: Tracked in `auth_sessions` table with revocation support
- **Rate Limiting**: Auth endpoint limited to 8 attempts per 15 minutes
- **Secure Storage**: Tokens stored via `flutter_secure_storage` (Keychain/Keystore)

## License

Private — Govt. Polytechnic Kangra
