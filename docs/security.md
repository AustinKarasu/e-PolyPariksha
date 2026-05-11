# Security Design

## Implemented in Skeleton

- JWT authentication for admin and student apps.
- JWT sessions are checked against `auth_sessions`, so logout/revocation works server-side.
- Role checks on admin-only and student-only routes.
- Bcrypt password hashes in Supabase PostgreSQL.
- PDF upload validation by MIME type and size limit.
- Server-side branch checks before student PDF download.
- Server-side schedule checks before PDF access.
- Server-side attempt checks before PDF access.
- App background, close, and blocked-back events lock the attempt.
- Admin can review per-branch security logs and explicitly allow a locked attempt.
- Secure token storage in both Flutter apps.
- Student exam screen blocks normal back navigation.
- Student exam screen enables wakelock and reports lifecycle focus changes.

## Mobile Exam Mode Notes

Flutter alone cannot fully prevent app switching on all devices. A production Android build should add native kiosk or lock-task behavior through the `polyht/exam_security` method channel used in `ExamSecurityService`.

Recommended Android additions:

- `FLAG_SECURE` to block screenshots and screen recording.
- Lock task mode for managed devices.
- Device policy controller if college devices are centrally managed.
- Lifecycle logging API endpoint for app switching, pausing, and suspicious exits.

iOS has stricter platform limits. For high-stakes exams, use supervised devices with assessment mode or MDM policies.
