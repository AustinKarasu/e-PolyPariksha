class StudentTest {
  StudentTest({
    required this.id,
    required this.title,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.semester,
    required this.timeLimitMinutes,
    required this.status,
    this.originalFilename,
    this.attemptStatus,
    this.blockedReason,
  });

  final int id;
  final String title;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int semester;
  final int timeLimitMinutes;
  final String status;
  final String? originalFilename;
  final String? attemptStatus;
  final String? blockedReason;

  bool get isLive => status == 'live';
  bool get isLocked => false;
  bool get isCompleted => attemptStatus == 'completed';
  bool get canStart => isLive && !isLocked && !isCompleted;
  bool get canDownloadAfterEnd => status == 'ended' && isCompleted;

  factory StudentTest.fromJson(Map<String, dynamic> json) {
    return StudentTest(
      id: json['id'] as int,
      title: json['title'] as String,
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
      semester: json['semester'] as int? ?? 1,
      timeLimitMinutes: json['time_limit_minutes'] as int,
      status: json['status'] as String,
      originalFilename: json['original_filename'] as String?,
      attemptStatus: json['attempt_status'] as String?,
      blockedReason: json['blocked_reason'] as String?,
    );
  }
}
