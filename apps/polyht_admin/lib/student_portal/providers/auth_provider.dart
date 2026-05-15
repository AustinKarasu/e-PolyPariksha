import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

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
    if (token != null) {
      try {
        user = await _authService.me();
        requiresTwoFactor = false;
      } catch (_) {
        await _tokenStorage.clear();
        user = null;
        requiresTwoFactor = false;
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> login(String identifier, String password, {String? totpCode}) async {
    isLoading = true;
    error = null;
    if (totpCode != null && totpCode.trim().isNotEmpty) {
      requiresTwoFactor = false;
    }
    notifyListeners();
    try {
      user = await _authService.login(identifier, password, totpCode: totpCode);
      requiresTwoFactor = false;
    } on TwoFactorRequiredException catch (err) {
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

  Future<void> updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? guardianName,
    String? address,
  }) async {
    user = await _authService.updateProfile(
      fullName: fullName,
      email: email,
      phone: phone,
      guardianName: guardianName,
      address: address,
    );
    notifyListeners();
  }

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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    String? totpCode,
  }) async {
    await _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      totpCode: totpCode,
    );
  }

  Future<Map<String, dynamic>> setupTwoFactor() => _authService.setupTwoFactor();

  Future<void> enableTwoFactor(String code) async {
    user = await _authService.enableTwoFactor(code);
    notifyListeners();
  }

  Future<void> disableTwoFactor(String code) async {
    user = await _authService.disableTwoFactor(code);
    notifyListeners();
  }
}
