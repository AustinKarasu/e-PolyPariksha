import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const _adminKey = 'biometric_admin_enabled';
  static const _studentKey = 'biometric_student_enabled';
  final LocalAuthentication _auth = LocalAuthentication();
  Future<bool> enabled(bool student) async => (await SharedPreferences.getInstance()).getBool(student ? _studentKey : _adminKey) ?? false;
  Future<void> setEnabled(bool student, bool value) async => (await SharedPreferences.getInstance()).setBool(student ? _studentKey : _adminKey, value);
  Future<bool> available() async => await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
  Future<bool> authenticate() => _auth.authenticate(localizedReason: 'Confirm your identity to unlock e-PolyPariksha HP', options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true));
}
