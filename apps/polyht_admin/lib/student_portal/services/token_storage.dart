import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'polyht_student_token';
  static const _buildKey = 'polyht_student_token_build';

  Future<void> saveToken(String token) async { await _storage.write(key: _tokenKey, value: token); await _storage.write(key: _buildKey, value: (await PackageInfo.fromPlatform()).buildNumber); }
  Future<String?> readToken() async { final token = await _storage.read(key: _tokenKey); if (token == null) return null; if (await _storage.read(key: _buildKey) != (await PackageInfo.fromPlatform()).buildNumber) { await clear(); return null; } return token; }
  Future<void> clear() async { await _storage.delete(key: _tokenKey); await _storage.delete(key: _buildKey); }
}
