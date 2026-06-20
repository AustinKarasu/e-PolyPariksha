import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedAdminCredentials {
  const SavedAdminCredentials(
      {required this.identifier, required this.password});
  final String identifier;
  final String password;
}

class SavedAdminCredentialsService {
  static const _storage = FlutterSecureStorage();
  static const _identifierKey = 'polyht_admin_saved_identifier';
  static const _passwordKey = 'polyht_admin_saved_password';

  Future<SavedAdminCredentials?> read() async {
    final identifier = await _storage.read(key: _identifierKey);
    final password = await _storage.read(key: _passwordKey);
    if (identifier == null ||
        identifier.trim().isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return SavedAdminCredentials(identifier: identifier, password: password);
  }

  Future<void> save(String identifier, String password) async {
    await _storage.write(key: _identifierKey, value: identifier.trim());
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _identifierKey);
    await _storage.delete(key: _passwordKey);
  }
}
