import '../models/app_user.dart';
import 'api_client.dart';
import 'token_storage.dart';

class TwoFactorRequiredException implements Exception {
  const TwoFactorRequiredException([this.message = 'Enter your authenticator code to continue.']);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({ApiClient? apiClient, TokenStorage? tokenStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AppUser> login(String identifier, String password, {String? totpCode}) async {
    final data = await _apiClient.post('/auth/login', {
      'identifier': identifier,
      'password': password,
      if (totpCode != null && totpCode.isNotEmpty) 'totpCode': totpCode,
    });
    if (data['requiresTwoFactor'] == true) {
      throw TwoFactorRequiredException(data['message']?.toString() ?? 'Enter your authenticator code to continue.');
    }
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    if (user.role != 'admin') {
      throw Exception('Admin access only');
    }
    await _tokenStorage.saveToken(data['token'] as String);
    return user;
  }

  Future<AppUser> me() async {
    final data = await _apiClient.get('/auth/me');
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    if (user.role != 'admin') {
      await _tokenStorage.clear();
      throw Exception('Admin access only');
    }
    return user;
  }

  Future<void> logout() async {
    await _apiClient.postEmpty('/auth/logout').catchError((_) {});
    await _tokenStorage.clear();
  }

  Future<void> registerAdmin({
    required String firstName,
    String? middleName,
    required String lastName,
    required String mobile,
    required String email,
    required String college,
    required String state,
    required String password,
  }) async {
    await _apiClient.post('/auth/register-admin', {
      'firstName': firstName,
      if (middleName != null && middleName.trim().isNotEmpty) 'middleName': middleName.trim(),
      'lastName': lastName,
      'mobile': mobile,
      'email': email,
      'college': college,
      'state': state,
      'password': password,
    });
  }

  Future<AppUser> updateProfile({
    required String fullName,
    String? email,
    String? phone,
    String? address,
  }) async {
    final data = await _apiClient.patch('/auth/me', {
      'fullName': fullName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
    });
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> uploadProfilePhoto({
    String? imagePath,
    List<int>? imageBytes,
    required String imageName,
  }) async {
    final data = await _apiClient.uploadPhoto(
      path: '/auth/me/photo',
      imagePath: imagePath,
      imageBytes: imageBytes,
      imageName: imageName,
    );
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> setupTwoFactor() async {
    return await _apiClient.post('/auth/2fa/setup', {}) as Map<String, dynamic>;
  }

  Future<AppUser> enableTwoFactor(String code) async {
    final data = await _apiClient.post('/auth/2fa/enable', {'code': code});
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> disableTwoFactor(String code) async {
    final data = await _apiClient.post('/auth/2fa/disable', {'code': code});
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }
}
