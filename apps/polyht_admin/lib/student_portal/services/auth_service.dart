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
    if (user.role != 'student') {
      throw Exception('Student access only');
    }
    await _tokenStorage.saveToken(data['token'] as String);
    return user;
  }

  Future<AppUser> me() async {
    final data = await _apiClient.get('/auth/me');
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    if (user.role != 'student') {
      await _tokenStorage.clear();
      throw Exception('Student access only');
    }
    return user;
  }

  Future<void> logout() async {
    await _apiClient.postEmpty('/auth/logout').catchError((_) {});
    await _tokenStorage.clear();
  }

  Future<AppUser> updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? guardianName,
    String? address,
    String? emailOtpCode,
  }) async {
    final data = await _apiClient.patch('/students/me', {
      if (fullName != null) 'fullName': fullName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (guardianName != null) 'guardianName': guardianName,
      if (address != null) 'address': address,
      if (emailOtpCode != null && emailOtpCode.isNotEmpty) 'emailOtpCode': emailOtpCode,
    });
    return AppUser.fromJson(data['student'] as Map<String, dynamic>);
  }

  Future<void> requestEmailChangeOtp(String email) async {
    await _apiClient.post('/students/me/email-otp', {'email': email});
  }

  Future<AppUser> uploadProfilePhoto({
    String? imagePath,
    List<int>? imageBytes,
    required String imageName,
  }) async {
    final data = await _apiClient.uploadProfilePhoto(
      imagePath: imagePath,
      imageBytes: imageBytes,
      imageName: imageName,
    );
    return AppUser.fromJson(data['student'] as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    String? totpCode,
  }) async {
    await _apiClient.post('/auth/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      if (totpCode != null && totpCode.isNotEmpty) 'totpCode': totpCode,
    });
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
