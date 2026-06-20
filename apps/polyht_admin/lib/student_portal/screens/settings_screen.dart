import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../services/biometric_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  @override
  void initState() {
    super.initState();
    BiometricService().enabled(true).then((value) {
      if (mounted) setState(() => _biometricEnabled = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final enabled = auth.user?.twoFactorEnabled == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.cardShadow),
            child: Row(children: [
              const Icon(Icons.verified_user_outlined, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(enabled
                      ? 'Two-factor authentication is enabled'
                      : 'Two-factor authentication is off')),
              FilledButton(
                  onPressed: () =>
                      enabled ? _disable(context) : _enable(context),
                  child: Text(enabled ? 'Disable' : 'Enable')),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: AppTheme.cardShadow),
              child: Row(children: [
                const Icon(Icons.fingerprint_rounded, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(_biometricEnabled
                        ? 'Biometric unlock is enabled'
                        : 'Biometric unlock is off')),
                Switch(
                    value: _biometricEnabled,
                    onChanged: (value) async {
                      final biometrics = BiometricService();
                      if (value &&
                          (!(await biometrics.available()) ||
                              !(await biometrics.authenticate()))) {
                        return;
                      }
                      await biometrics.setEnabled(true, value);
                      if (mounted) setState(() => _biometricEnabled = value);
                    })
              ])),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.cardShadow),
            child: Row(children: [
              const Icon(Icons.lock_reset_rounded, color: AppTheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Reset your password using email OTP'),
              ),
              FilledButton(
                onPressed: () => _changePassword(context),
                child: const Text('Change'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String? _strongPassword(String value) {
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Add an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Add a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Add a number';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return 'Add a symbol';
    return null;
  }

  Future<void> _changePassword(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final code = TextEditingController();
    final emailOtp = TextEditingController();
    final twoFactorEnabled = auth.user?.twoFactorEnabled == true;
    var sendingOtp = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Reset Password'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                  'Send an OTP to your registered email, then create a new password.'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: sendingOtp
                      ? null
                      : () async {
                          setDialogState(() => sendingOtp = true);
                          try {
                            await auth.requestPasswordChangeOtp();
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Password reset OTP sent to your email')));
                            }
                          } catch (err) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(
                                      content: Text(err
                                          .toString()
                                          .replaceFirst('Exception: ', ''))));
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => sendingOtp = false);
                            }
                          }
                        },
                  icon: sendingOtp
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_outlined),
                  label: Text(sendingOtp ? 'Sending OTP...' : 'Send email OTP'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: emailOtp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Email OTP')),
              const SizedBox(height: 12),
              TextField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password')),
              const SizedBox(height: 12),
              TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm new password')),
              if (twoFactorEnabled) ...[
                const SizedBox(height: 12),
                TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Authenticator code')),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) {
      next.dispose();
      confirm.dispose();
      code.dispose();
      emailOtp.dispose();
      return;
    }
    if (!context.mounted) {
      next.dispose();
      confirm.dispose();
      code.dispose();
      emailOtp.dispose();
      return;
    }

    final passwordError = _strongPassword(next.text);
    if (passwordError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(passwordError)));
    } else if (next.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New passwords do not match')));
    } else if (emailOtp.text.trim().length < 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter the email OTP')));
    } else {
      try {
        await auth.changePassword(
          newPassword: next.text,
          totpCode: code.text.trim(),
          emailOtpCode: emailOtp.text.trim(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Password changed')));
        }
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(err.toString().replaceFirst('Exception: ', ''))));
        }
      }
    }
    next.dispose();
    confirm.dispose();
    code.dispose();
    emailOtp.dispose();
  }

  Future<void> _enable(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final setup = await auth.setupTwoFactor();
    if (!context.mounted) return;
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable 2FA'),
        content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Scan the QR code with your authenticator app, then enter the generated code.'),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                        data: setup['otpauthUrl'] as String, size: 190),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(setup['secret'] as String),
                const SizedBox(height: 12),
                TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Authenticator code')),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enable')),
        ],
      ),
    );
    if (ok == true) await auth.enableTwoFactor(code.text.trim());
    code.dispose();
  }

  Future<void> _disable(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable 2FA'),
        content: TextField(
            controller: code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Authenticator code')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Disable')),
        ],
      ),
    );
    if (ok == true) await auth.disableTwoFactor(code.text.trim());
    code.dispose();
  }
}
