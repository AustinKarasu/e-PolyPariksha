import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:math';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'polyht_admin_token';
  static const _buildKey = 'polyht_admin_token_build';
  static const _deviceKey = 'polyht_admin_device_id';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
        key: _buildKey, value: (await PackageInfo.fromPlatform()).buildNumber);
  }

  Future<String?> readToken() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;
    if (await _storage.read(key: _buildKey) !=
        (await PackageInfo.fromPlatform()).buildNumber) {
      await clear();
      return null;
    }
    return token;
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _buildKey);
  }

  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final value =
        List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
    await _storage.write(key: _deviceKey, value: value);
    return value;
  }
}
