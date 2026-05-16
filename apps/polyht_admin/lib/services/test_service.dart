import '../models/branch.dart';
import '../models/attempt_report.dart';
import '../models/exam_event.dart';
import '../models/locked_attempt.dart';
import '../models/test_paper.dart';
import 'api_client.dart';
import 'student_service.dart';

class TestService {
  TestService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Branch>> fetchBranches() async {
    final data = await _apiClient.get('/branches');
    return (data['branches'] as List)
        .map((item) => Branch.fromJson(item))
        .toList();
  }

  Future<List<TestPaper>> fetchTests() async {
    final data = await _apiClient.get('/tests');
    return (data['tests'] as List)
        .map((item) => TestPaper.fromJson(item))
        .toList();
  }

  Future<void> uploadTest({
    required String title,
    required int branchId,
    required int semester,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    required int timeLimitMinutes,
    String? pdfPath,
    List<int>? pdfBytes,
    required String pdfName,
  }) async {
    await _apiClient.uploadTest(
      title: title,
      branchId: branchId,
      semester: semester,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      timeLimitMinutes: timeLimitMinutes,
      pdfPath: pdfPath,
      pdfBytes: pdfBytes,
      pdfName: pdfName,
    );
  }

  Future<void> replacePdf({
    required int testId,
    String? pdfPath,
    List<int>? pdfBytes,
    required String pdfName,
  }) async {
    await _apiClient.replacePdf(
        testId: testId, pdfPath: pdfPath, pdfBytes: pdfBytes, pdfName: pdfName);
  }

  Future<void> deleteTest(int testId) async {
    await _apiClient.delete('/tests/$testId');
  }

  Future<void> setTestActive(
      {required int testId, required bool isActive}) async {
    await _apiClient.patch('/tests/$testId/active', {'isActive': isActive});
  }

  Future<void> endTestNow(int testId) async {
    await _apiClient.postEmpty('/tests/$testId/end');
  }

  Future<List<ExamEvent>> fetchEvents({
    int? branchId,
    int? testId,
    int? limit,
    bool reportFallback = false,
  }) async {
    final params = <String>[
      if (branchId != null) 'branchId=$branchId',
      if (testId != null) 'testId=$testId',
      if (limit != null) 'limit=$limit',
      if (reportFallback) 'reportFallback=true',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final data = await _apiClient.get('/attempts/admin/events$query');
    return (data['events'] as List)
        .map((item) => ExamEvent.fromJson(item))
        .toList();
  }

  Future<List<LockedAttempt>> fetchLockedAttempts({int? branchId}) async {
    final query = branchId == null ? '' : '?branchId=$branchId';
    final data = await _apiClient.get('/attempts/admin/locked$query');
    return (data['attempts'] as List)
        .map((item) => LockedAttempt.fromJson(item))
        .toList();
  }

  Future<List<AttemptReport>> fetchAttemptReports(
      {int? testId, int? branchId}) async {
    final params = <String>[
      if (testId != null) 'testId=$testId',
      if (branchId != null) 'branchId=$branchId',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    try {
      final data = await _apiClient.get('/attempts/admin/reports$query');
      return (data['reports'] as List)
          .map((item) => AttemptReport.fromJson(item))
          .toList();
    } catch (_) {
      return _fallbackAttemptReports(testId: testId, branchId: branchId);
    }
  }

  Future<List<AttemptReport>> _fallbackAttemptReports(
      {int? testId, int? branchId}) async {
    final events = await fetchEvents(
      branchId: branchId,
      testId: testId,
      limit: 500,
      reportFallback: true,
    );
    final students =
        await StudentService(apiClient: _apiClient).fetchAllStudents();
    final tests = await fetchTests();
    final studentsById = {for (final student in students) student.id: student};
    final testsById = {for (final test in tests) test.id: test};
    final grouped = <String, List<ExamEvent>>{};

    for (final event in events) {
      if (event.studentId == null || event.testId == null) continue;
      grouped
          .putIfAbsent('${event.studentId}:${event.testId}', () => [])
          .add(event);
    }

    final reports = <AttemptReport>[];
    for (final entry in grouped.entries) {
      final items = [...entry.value]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final first = items.first;
      final student = studentsById[first.studentId];
      final test = testsById[first.testId];
      if (student == null || test == null) continue;
      final startedAt =
          _firstEvent(items, 'attempt_started')?.createdAt ?? first.createdAt;
      final completedAt = _firstEvent(items, 'submit_completed')?.createdAt;
      final lastSeenAt = items.last.createdAt;
      final blockedActions = items
          .where((event) => _criticalEvents.contains(event.eventType))
          .toList();
      final blockedAt =
          blockedActions.isEmpty ? null : blockedActions.first.createdAt;
      final seconds =
          (completedAt ?? lastSeenAt).difference(startedAt).inSeconds;

      reports.add(AttemptReport(
        attemptId: first.attemptId ?? 0,
        testId: test.id,
        testTitle: test.title,
        studentId: student.id,
        fullName: student.fullName,
        branchName: student.branchName ?? test.branchName,
        branchCode: student.branchCode,
        semester: student.semester ?? test.semester,
        status: completedAt != null
            ? 'completed'
            : blockedActions.isNotEmpty
                ? 'blocked'
                : 'started',
        events: items
            .map((event) => AttemptReportEvent(
                  eventType: event.eventType,
                  severity: event.severity,
                  message: event.message,
                  createdAt: event.createdAt,
                ))
            .toList(),
        blockedActions: blockedActions
            .map((event) => AttemptReportEvent(
                  eventType: event.eventType,
                  severity: event.severity,
                  message: event.message,
                  createdAt: event.createdAt,
                ))
            .toList(),
        aiSummary: _fallbackSummary(
            student.fullName, test.title, seconds, blockedActions),
        boardRollNo: student.boardRollNo,
        rollNo: student.rollNo,
        collegeId: student.collegeId,
        email: student.email,
        phone: student.phone,
        collegeName: student.collegeName,
        courseName: student.courseName,
        guardianName: student.guardianName,
        startedAt: startedAt,
        lastSeenAt: lastSeenAt,
        completedAt: completedAt,
        blockedAt: blockedAt,
        blockedReason:
            blockedActions.isEmpty ? null : blockedActions.first.message,
        timeTakenSeconds: seconds < 0 ? null : seconds,
      ));
    }

    reports.sort((a, b) =>
        (b.completedAt ?? b.lastSeenAt ?? b.startedAt ?? DateTime(0)).compareTo(
            a.completedAt ?? a.lastSeenAt ?? a.startedAt ?? DateTime(0)));
    return reports;
  }

  ExamEvent? _firstEvent(List<ExamEvent> events, String eventType) {
    for (final event in events) {
      if (event.eventType == eventType) return event;
    }
    return null;
  }

  String _fallbackSummary(String studentName, String testTitle, int seconds,
      List<ExamEvent> blockedActions) {
    final minutes = seconds < 0
        ? 'not available'
        : '${(seconds / 60).ceil().clamp(1, 9999)} minute(s)';
    if (blockedActions.isEmpty) {
      return '$studentName attempted $testTitle and spent $minutes with no blocked actions recorded.';
    }
    final actions = blockedActions
        .map((event) => event.eventType.replaceAll('_', ' '))
        .toSet()
        .join(', ');
    return '$studentName attempted $testTitle, spent $minutes, and triggered blocked action(s): $actions.';
  }

  static const _criticalEvents = {
    'app_backgrounded',
    'app_detached',
    'app_hidden',
    'back_blocked',
    'split_screen_detected',
    'picture_in_picture_detected',
    'window_focus_lost',
  };

  Future<void> allowAttempt(int attemptId) async {
    await _apiClient.postEmpty('/attempts/admin/$attemptId/allow');
  }

  Future<String> downloadPdf(int testId) => _apiClient.downloadPdf(testId);
}
