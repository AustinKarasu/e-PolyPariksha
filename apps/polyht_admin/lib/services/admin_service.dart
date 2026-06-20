import '../models/admin_account.dart';
import '../models/admin_analytics.dart';
import '../models/admin_application.dart';
import '../models/app_user.dart';
import 'api_client.dart';

class AdminService {
  AdminService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<AdminAccount>> fetchAdmins() async {
    try {
      final data = await _apiClient.get('/admins');
      return (data['admins'] as List)
          .map((item) => AdminAccount.fromJson(item))
          .toList();
    } catch (err) {
      final message = err.toString().toLowerCase();
      if (!message.contains('req is not defined')) rethrow;
      return _fetchAdminsFromApplicationsFallback();
    }
  }

  Future<List<AdminAccount>> _fetchAdminsFromApplicationsFallback() async {
    final meData = await _apiClient.get('/auth/me');
    final currentUser =
        AppUser.fromJson(meData['user'] as Map<String, dynamic>);
    final applicationsData = await _apiClient.get('/admins/applications');
    final applications = applicationsData['applications'] as List;
    final admins = <AdminAccount>[
      AdminAccount(
        id: currentUser.id,
        fullName: currentUser.fullName,
        email: currentUser.email ?? 'admin@gpkangra.gov.in',
        isActive: currentUser.isActive ?? true,
        twoFactorEnabled: currentUser.twoFactorEnabled ?? false,
        isPrimaryAdmin: currentUser.isPrimaryAdmin ?? true,
      ),
    ];
    final currentEmail = (currentUser.email ?? '').trim().toLowerCase();
    final seenIds = <int>{currentUser.id};
    for (final item in applications) {
      final json = item as Map<String, dynamic>;
      if (json['status'] != 'approved') continue;
      final id = json['created_admin_id'] as int?;
      final email = (json['email'] as String? ?? '').trim();
      if (id == null || seenIds.contains(id)) continue;
      if (email.toLowerCase() == currentEmail) continue;
      seenIds.add(id);
      admins.add(AdminAccount(
        id: id,
        fullName: json['full_name'] as String? ?? email,
        email: email,
        isActive: true,
        twoFactorEnabled: false,
        isPrimaryAdmin: false,
      ));
    }
    return admins;
  }

  Future<void> createAdmin({
    required String fullName,
    required String email,
    required String password,
    String? otpCode,
  }) async {
    await _apiClient.post('/admins', {
      'fullName': fullName,
      'email': email,
      'password': password,
      if (otpCode != null && otpCode.isNotEmpty) 'otpCode': otpCode,
    });
  }

  Future<void> requestCreateAdminOtp() async {
    await _apiClient.post('/admins/request-create-otp', {});
  }

  Future<AdminAnalytics> fetchAnalytics() async {
    final data = await _apiClient.get('/admins/analytics');
    return AdminAnalytics.fromJson(data['analytics'] as Map<String, dynamic>);
  }

  Future<List<AppErrorReport>> fetchAppErrors({int limit = 50}) async {
    final data = await _apiClient.get('/admins/app-errors?limit=$limit');
    return (data['reports'] as List)
        .map((item) => AppErrorReport.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> setActive(int adminId, bool isActive) async {
    await _apiClient.patch('/admins/$adminId/active', {'isActive': isActive});
  }

  Future<List<AdminApplication>> fetchApplications() async {
    final data = await _apiClient.get('/admins/applications');
    return (data['applications'] as List)
        .map((item) => AdminApplication.fromJson(item))
        .toList();
  }

  Future<void> approveApplication(int applicationId) async {
    await _apiClient.post('/admins/applications/$applicationId/approve', {});
  }

  Future<void> rejectApplication(int applicationId) async {
    await _apiClient.post('/admins/applications/$applicationId/reject', {});
  }

  Future<void> deleteApplication(int applicationId) async {
    await _apiClient.delete('/admins/applications/$applicationId');
  }

  Future<void> setPrimary(int adminId, {String? otpCode}) async {
    await _apiClient.patch('/admins/$adminId/primary', {
      if (otpCode != null && otpCode.isNotEmpty) 'otpCode': otpCode,
    });
  }

  Future<void> deleteAdmin(int adminId) async {
    await _apiClient.delete('/admins/$adminId');
  }

  Future<void> clearData({
    required String totpCode,
    required bool tests,
    required bool history,
    required bool students,
    required bool sessions,
    bool logs = false,
    bool applications = false,
  }) async {
    await _apiClient.post('/admins/clear-data', {
      'totpCode': totpCode,
      'tests': tests,
      'history': history,
      'students': students,
      'sessions': sessions,
      'logs': logs,
      'applications': applications,
    });
  }

  Future<void> updateAdmin({
    required int id,
    String? fullName,
    String? email,
    String? password,
    bool? isActive,
  }) async {
    await _apiClient.patch('/admins/$id', {
      if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
      if (email != null && email.isNotEmpty) 'email': email,
      if (password != null && password.isNotEmpty) 'password': password,
      if (isActive != null) 'isActive': isActive,
    });
  }
}
