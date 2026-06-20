import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';
import '../services/biometric_service.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  final _tokenStorage = TokenStorage();

  AppUser? user;
  bool isLoading = true;
  bool requiresTwoFactor = false;
  String? error;

  bool get isAuthenticated => user != null;

  Future<void> restoreSession() async {
    final token = await _tokenStorage.readToken();
    if (token == null) {
      isLoading = false;
      notifyListeners();
      return;
    }
    final biometrics = BiometricService();
    if (await biometrics.enabled(false) && !await biometrics.authenticate()) {
      await _tokenStorage.clear();
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      user = await _authService.me();
      requiresTwoFactor = false;
    } catch (_) {
      await _tokenStorage.clear();
      user = null;
      requiresTwoFactor = false;
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> login(String identifier, String password,
      {String? emailOtpCode}) async {
    isLoading = true;
    error = null;
    if (emailOtpCode != null && emailOtpCode.trim().isNotEmpty) {
      requiresTwoFactor = false;
    }
    notifyListeners();
    try {
      user = await _authService.login(identifier, password,
          emailOtpCode: emailOtpCode);
      requiresTwoFactor = false;
    } on VerificationRequiredException catch (err) {
      requiresTwoFactor = true;
      error = err.toString();
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    user = null;
    requiresTwoFactor = false;
    error = null;
    notifyListeners();
  }

  Future<bool> registerAdmin({
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
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _authService.registerAdmin(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        mobile: mobile,
        email: email,
        college: college,
        state: state,
        password: password,
        emailOtpCode: emailOtpCode,
      );
      return true;
    } catch (err) {
      error = err.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestAdminRegistrationOtp(String email) =>
      _authService.requestAdminRegistrationOtp(email);
  Future<void> requestPasswordReset(String email, String role) =>
      _authService.requestPasswordReset(email, role);
  Future<String> verifyPasswordReset(
          String email, String role, String otpCode) =>
      _authService.verifyPasswordReset(email, role, otpCode);
  Future<void> completePasswordReset(String resetToken, String newPassword) =>
      _authService.completePasswordReset(resetToken, newPassword);

  Future<Map<String, dynamic>> setupTwoFactor() =>
      _authService.setupTwoFactor();

  Future<void> enableTwoFactor(String code) async {
    user = await _authService.enableTwoFactor(code);
    notifyListeners();
  }

  Future<void> disableTwoFactor(String code) async {
    user = await _authService.disableTwoFactor(code);
    notifyListeners();
  }

  Future<void> updateProfile({
    required String fullName,
    String? email,
    String? phone,
    String? address,
    String? emailOtpCode,
  }) async {
    user = await _authService.updateProfile(
        fullName: fullName,
        email: email,
        phone: phone,
        address: address,
        emailOtpCode: emailOtpCode);
    notifyListeners();
  }

  Future<void> requestEmailChangeOtp(String email) =>
      _authService.requestEmailChangeOtp(email);
  Future<void> requestPasswordChangeOtp() =>
      _authService.requestPasswordChangeOtp();
  Future<void> changePassword(
          {required String currentPassword,
          required String newPassword,
          required String emailOtpCode,
          String? totpCode}) =>
      _authService.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          emailOtpCode: emailOtpCode,
          totpCode: totpCode);

  Future<void> uploadProfilePhoto({
    String? imagePath,
    List<int>? imageBytes,
    required String imageName,
  }) async {
    user = await _authService.uploadProfilePhoto(
      imagePath: imagePath,
      imageBytes: imageBytes,
      imageName: imageName,
    );
    notifyListeners();
  }
}
