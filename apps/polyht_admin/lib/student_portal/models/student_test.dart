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
    this.startedAt,
    this.lastSeenAt,
    this.completedAt,
    this.pdfSize,
    this.activeSeconds,
    this.canDownloadPdf,
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
  final DateTime? startedAt;
  final DateTime? lastSeenAt;
  final DateTime? completedAt;
  final int? pdfSize;
  final int? activeSeconds;
  final bool? canDownloadPdf;

  bool get isLive => status == 'live';
  bool get isLocked => false;
  bool get isCompleted => attemptStatus == 'completed';
  bool get canStart => isLive && !isLocked && !isCompleted;
  bool get canDownloadAfterEnd => status == 'ended' && canDownloadPdf != false;

  factory StudentTest.fromJson(Map<String, dynamic> json) {
    return StudentTest(
      id: json['id'] as int,
      title: json['title'] as String,
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
      semester: json['semester'] as int? ?? 1,
      timeLimitMinutes: json['time_limit_minutes'] as int,
      status: json['status'] as String,
      originalFilename: (json['pdf_original_name'] as String?) ?? (json['original_filename'] as String?),
      attemptStatus: json['attempt_status'] as String?,
      blockedReason: json['blocked_reason'] as String?,
      startedAt: _date(json['started_at']),
      lastSeenAt: _date(json['last_seen_at']),
      completedAt: _date(json['completed_at']),
      pdfSize: json['pdf_size'] as int?,
      activeSeconds: _int(json['active_seconds']),
      canDownloadPdf: json['can_download_pdf'] as bool?,
    );
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
