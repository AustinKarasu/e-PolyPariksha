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
    int parseNum(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    final rawReports = json['recent_reports'];
    final List<AppErrorReport> reports = [];
    if (rawReports is List) {
      for (final item in rawReports) {
        if (item is Map) {
          try {
            reports.add(AppErrorReport.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
    }

    return AdminAnalytics(
      testsConductedToday: parseNum(json['tests_conducted_today']),
      userAttemptsToday: parseNum(json['user_attempts_today']),
      totalUsers: parseNum(json['total_users']),
      appErrorsToday: parseNum(json['app_errors_today']),
      crashReportsToday: parseNum(json['crash_reports_today']),
      recentReports: reports,
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
    DateTime parsedDate;
    final rawDate = json['created_at'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    int parsedId = 0;
    final rawId = json['id'];
    if (rawId is num) {
      parsedId = rawId.toInt();
    } else if (rawId is String) {
      parsedId = int.tryParse(rawId) ?? 0;
    }

    return AppErrorReport(
      id: parsedId,
      severity: json['severity']?.toString() ?? 'error',
      source: json['source']?.toString(),
      page: json['page']?.toString(),
      message: json['message']?.toString() ?? 'No error message recorded',
      stackTrace: json['stack_trace']?.toString(),
      devicePlatform: json['device_platform']?.toString(),
      deviceModel: json['device_model']?.toString(),
      appVersion: json['app_version']?.toString(),
      appBuild: json['app_build']?.toString(),
      createdAt: parsedDate,
      fullName: json['full_name']?.toString(),
      email: json['email']?.toString(),
      collegeName: json['college_name']?.toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString(),
      branchName: json['branch_name']?.toString(),
    );
  }
}
