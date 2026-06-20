class AdminAnalytics {
  AdminAnalytics({
    required this.testsConductedToday,
    required this.userAttemptsToday,
    required this.totalUsers,
    required this.appErrorsToday,
    required this.crashReportsToday,
    required this.recentReports,
  });

  final int testsConductedToday;
  final int userAttemptsToday;
  final int totalUsers;
  final int appErrorsToday;
  final int crashReportsToday;
  final List<AppErrorReport> recentReports;

  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    return AdminAnalytics(
      testsConductedToday: json['tests_conducted_today'] as int? ?? 0,
      userAttemptsToday: json['user_attempts_today'] as int? ?? 0,
      totalUsers: json['total_users'] as int? ?? 0,
      appErrorsToday: json['app_errors_today'] as int? ?? 0,
      crashReportsToday: json['crash_reports_today'] as int? ?? 0,
      recentReports: ((json['recent_reports'] as List?) ?? [])
          .map((item) => AppErrorReport.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AppErrorReport {
  AppErrorReport({
    required this.id,
    required this.severity,
    required this.message,
    required this.createdAt,
    this.source,
    this.page,
    this.stackTrace,
    this.devicePlatform,
    this.deviceModel,
    this.appVersion,
    this.appBuild,
    this.fullName,
    this.email,
    this.collegeName,
    this.phone,
    this.role,
    this.branchName,
  });

  final int id;
  final String severity;
  final String? source;
  final String? page;
  final String message;
  final String? stackTrace;
  final String? devicePlatform;
  final String? deviceModel;
  final String? appVersion;
  final String? appBuild;
  final DateTime createdAt;
  final String? fullName;
  final String? email;
  final String? collegeName;
  final String? phone;
  final String? role;
  final String? branchName;

  factory AppErrorReport.fromJson(Map<String, dynamic> json) {
    return AppErrorReport(
      id: json['id'] as int,
      severity: json['severity'] as String? ?? 'error',
      source: json['source'] as String?,
      page: json['page'] as String?,
      message: json['message'] as String? ?? 'No error message recorded',
      stackTrace: json['stack_trace'] as String?,
      devicePlatform: json['device_platform'] as String?,
      deviceModel: json['device_model'] as String?,
      appVersion: json['app_version'] as String?,
      appBuild: json['app_build'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      collegeName: json['college_name'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      branchName: json['branch_name'] as String?,
    );
  }
}
