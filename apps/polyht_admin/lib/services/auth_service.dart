import '../models/app_user.dart';
import 'api_client.dart';
import 'token_storage.dart';

class VerificationRequiredException implements Exception {
  const VerificationRequiredException(
      [this.message = 'Enter your verification code to continue.']);

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

  Future<AppUser> login(String identifier, String password,
      {String? emailOtpCode}) async {
    final data = await _apiClient.post('/auth/login', {
      'identifier': identifier,
      'password': password,
      if (emailOtpCode != null && emailOtpCode.isNotEmpty)
        'emailOtpCode': emailOtpCode,
    });
    if (data['requiresTwoFactor'] == true || data['requiresEmailOtp'] == true) {
      throw VerificationRequiredException(data['message']?.toString() ??
          'Enter your verification code to continue.');
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
    required String emailOtpCode,
  }) async {
    await _apiClient.post('/auth/register-admin', {
      'firstName': firstName,
      if (middleName != null && middleName.trim().isNotEmpty)
        'middleName': middleName.trim(),
      'lastName': lastName,
      'mobile': mobile,
      'email': email,
      'college': college,
      'state': state,
      'password': password,
      'emailOtpCode': emailOtpCode,
    });
  }

  Future<void> requestAdminRegistrationOtp(String email) async {
    await _apiClient.post('/auth/register-admin/request-otp', {'email': email});
  }

  Future<AppUser> updateProfile({
    required String fullName,
    String? email,
    String? phone,
    String? address,
    String? emailOtpCode,
  }) async {
    final data = await _apiClient.patch('/auth/me', {
      'fullName': fullName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (emailOtpCode != null && emailOtpCode.isNotEmpty)
        'emailOtpCode': emailOtpCode,
    });
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> requestEmailChangeOtp(String email) async {
    await _apiClient.post('/auth/me/email-otp', {'email': email});
  }

  Future<void> requestPasswordReset(String email, String role) => _apiClient
      .post('/auth/password-reset/request', {'email': email, 'role': role});
  Future<String> verifyPasswordReset(
      String email, String role, String otpCode) async {
    final data = await _apiClient.post('/auth/password-reset/verify',
        {'email': email, 'role': role, 'otpCode': otpCode});
    return data['resetToken'] as String;
  }

  Future<void> completePasswordReset(String resetToken, String newPassword) =>
      _apiClient.post('/auth/password-reset/complete',
          {'resetToken': resetToken, 'newPassword': newPassword});

  Future<void> requestPasswordChangeOtp() =>
      _apiClient.post('/auth/me/password-otp', {});

  Future<void> changePassword(
      {required String currentPassword,
      required String newPassword,
      required String emailOtpCode,
      String? totpCode}) async {
    await _apiClient.post('/auth/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'emailOtpCode': emailOtpCode,
      if (totpCode != null && totpCode.isNotEmpty) 'totpCode': totpCode
    });
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
