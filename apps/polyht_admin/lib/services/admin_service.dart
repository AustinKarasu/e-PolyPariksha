import '../models/admin_account.dart';
import 'api_client.dart';

class AdminService {
  AdminService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<AdminAccount>> fetchAdmins() async {
    final data = await _apiClient.get('/admins');
    return (data['admins'] as List).map((item) => AdminAccount.fromJson(item)).toList();
  }

  Future<void> createAdmin({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _apiClient.post('/admins', {
      'fullName': fullName,
      'email': email,
      'password': password,
    });
  }

  Future<void> setActive(int adminId, bool isActive) async {
    await _apiClient.patch('/admins/$adminId/active', {'isActive': isActive});
  }

  Future<void> setPrimary(int adminId) async {
    await _apiClient.patch('/admins/$adminId/primary', {});
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
  }) async {
    await _apiClient.post('/admins/clear-data', {
      'totpCode': totpCode,
      'tests': tests,
      'history': history,
      'students': students,
      'sessions': sessions,
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
