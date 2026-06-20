# e-PolyPariksha HP REST API

Base URL: `http://localhost:4000/api`

## Authentication

`POST /auth/login`

Request:

```json
{
  "identifier": "<admin_email_or_student_college_id>",
  "password": "<account_password>"
}
```

Response:

```json
{
  "token": "jwt",
  "user": {
    "id": 1,
    "full_name": "Admin",
    "email": "<admin_email>",
    "role": "admin",
    "branch_id": null,
    "branch_name": null,
    "branch_code": null,
    "dob": null,
    "semester": null,
    "roll_no": null,
    "board_roll_no": null,
    "college_name": "Govt. Polytechnic Kangra",
    "course_name": null,
    "guardian_name": null,
    "phone": null,
    "address": null,
    "admission_year": null,
    "photo_url": null
  }
}
```

Use `Authorization: Bearer <token>` for protected endpoints.

`GET /auth/me`

Returns the currently authenticated user with full profile data. Both apps use this to restore sessions.

`POST /auth/logout`

Revokes the current JWT session.

## Branches

`GET /branches`

Returns all branches. Requires any authenticated user.

## Tests

`GET /tests`

- Admin receives all tests.
- Student receives tests assigned to their branch with `status`: `upcoming`, `live`, or `ended`.

`POST /tests`

Admin only. Multipart form data:

- `title`
- `branchId`
- `scheduledStart` ISO-8601 datetime
- `scheduledEnd` ISO-8601 datetime
- `timeLimitMinutes`
- `pdf` PDF file

`PUT /tests/:id`

Admin only. Updates title, branch, schedule, time limit, and active state.

`PATCH /tests/:id/active`

Admin only. Cancels or reactivates a test without changing the schedule or PDF.

```json
{ "isActive": false }
```

`POST /tests/:id/end`

Admin only. Ends the test immediately and hides it from student access.

`PUT /tests/:id/pdf`

Admin only. Multipart field `pdf`; replaces the current PDF.

`DELETE /tests/:id`

Admin only. Removes test metadata and PDF file.

`GET /tests/:id/pdf`

Student only. Downloads the PDF only when:

- Student belongs to the assigned branch.
- Current time is between `scheduled_start` and `scheduled_end`.
- Test is active.
- Student has started the attempt.
- Attempt is not blocked or completed.

## Students

`GET /students/me`

Student only. Returns the authenticated student's full profile with branch info.

`PATCH /students/me`

Student only. Updates limited self-service fields:

```json
{
  "phone": "9876543210",
  "address": "Village, Kangra, HP",
  "guardianName": "Parent Name"
}
```

`GET /students?branchId=1&semester=3&search=kumar&limit=50&offset=0`

Admin only. Lists students with optional filtering by branch, semester, or search term (matches name, college ID, or roll number).

Response:

```json
{
  "students": [...],
  "total": 120
}
```

`POST /students`

Admin only. Creates a student login account:

```json
{
  "fullName": "Student Name",
  "collegeId": "GPK-CE-2026-001",
  "password": "Strong@123",
  "branchId": 1,
  "email": "student@example.edu",
  "semester": 3,
  "rollNo": "CE-042",
  "boardRollNo": "HP-2026-042",
  "collegeName": "Govt. Polytechnic Kangra",
  "courseName": "Diploma in Computer Engineering",
  "guardianName": "Guardian Name",
  "phone": "9876543210",
  "address": "Kangra, Himachal Pradesh",
  "admissionYear": 2026,
  "dropoutYear": 2029
}
```

The student logs in with `boardRollNo` and `password` in the Student portal.

`GET /students/:id`

Admin only. Returns a single student's full profile.

`PATCH /students/:id`

Admin only. Updates any student field:

```json
{
  "fullName": "Updated Name",
  "semester": 4,
  "rollNo": "CE-2024-042",
  "boardRollNo": "HP-2024-1234",
  "courseName": "Diploma in Computer Engineering",
  "dob": "2005-03-15",
  "branchId": 1,
  "isActive": true
}
```

## Attempts

`POST /attempts/:testId/start`

Student only. Creates a test attempt record.

`POST /attempts/:testId/complete`

Student only. Marks the PDF-based test complete.

Request:

```json
{
  "answerNote": "Optional note or answer reference"
}
```

`POST /attempts/:testId/events`

Student only. Logs mobile exam actions.

Request:

```json
{
  "eventType": "app_backgrounded",
  "metadata": {
    "page": "exam"
  }
}
```

Blocking event types are `app_backgrounded`, `app_detached`, and `back_blocked`. These lock the attempt.

`GET /attempts/admin/events?branchId=1&testId=2&studentId=10`

Admin only. Returns branch-level exam event logs.

`GET /attempts/admin/locked?branchId=1`

Admin only. Returns blocked attempts.

`POST /attempts/admin/:attemptId/allow`

Admin only. Allows a blocked student to reopen the PDF during the valid schedule window.

## Admin Accounts

`GET /admins`

Admin only. Lists all admin accounts.

`POST /admins`

Admin only. Creates a new admin:

```json
{
  "fullName": "New Admin",
  "email": "admin2@college.edu",
  "password": "<strong-temporary-password>"
}
```

`PATCH /admins/:id/active`

Admin only. Activates or deactivates an admin:

```json
{
  "isActive": false
}
```
