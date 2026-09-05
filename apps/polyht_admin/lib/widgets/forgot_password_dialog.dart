import 'package:flutter/material.dart';

typedef RequestPasswordReset = Future<void> Function(String email, String role);
typedef VerifyPasswordReset = Future<String> Function(
    String email, String role, String otp);
typedef CompletePasswordReset = Future<void> Function(
    String resetToken, String password);

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({
    super.key,
    required this.role,
    required this.requestReset,
    required this.verifyReset,
    required this.completeReset,
  });

  final String role;
  final RequestPasswordReset requestReset;
  final VerifyPasswordReset verifyReset;
  final CompletePasswordReset completeReset;

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  int _step = 0;
  bool _busy = false;
  String? _resetToken;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_step == 0
            ? 'Reset password'
            : _step == 1
                ? 'Confirm OTP'
                : 'Create new password'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_step == 0
                ? 'Enter the email address connected to your ${widget.role} account.'
                : _step == 1
                    ? 'Enter the six-digit code sent to ${_email.text.trim()}.'
                    : 'Choose a strong new password for your account.'),
            const SizedBox(height: 16),
            if (_step == 0)
              TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined))),
            if (_step == 1)
              TextField(
                  controller: _otp,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                      labelText: 'OTP',
                      prefixIcon: Icon(Icons.verified_outlined))),
            if (_step == 2) ...[
              TextField(
                  controller: _password,
                  autofocus: true,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Create new password',
                      prefixIcon: Icon(Icons.lock_outline))),
              const SizedBox(height: 12),
              TextField(
                  controller: _confirmPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_reset_outlined))),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _busy ? null : _continue,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_step == 0
                      ? 'Request OTP'
                      : _step == 1
                          ? 'Confirm OTP'
                          : 'Done')),
        ],
      );

  Future<void> _continue() async {
    final email = _email.text.trim();
    if (_step == 0 && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return _setError('Enter a valid email address.');
    }
    if (_step == 1 && _otp.text.trim().length != 6) {
      return _setError('Enter the six-digit OTP.');
    }
    if (_step == 2) {
      if (_password.text.length < 8 ||
          !_password.text.contains(RegExp(r'[A-Z]')) ||
          !_password.text.contains(RegExp(r'[a-z]')) ||
          !_password.text.contains(RegExp(r'[0-9]')) ||
          !_password.text.contains(RegExp(r'[^A-Za-z0-9]'))) {
        return _setError(
            'Use 8+ characters with upper, lower, number, and symbol.');
      }
      if (_password.text != _confirmPassword.text) {
        return _setError('Passwords do not match.');
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_step == 0) {
        await widget.requestReset(email, widget.role);
        if (mounted) setState(() => _step = 1);
      } else if (_step == 1) {
        _resetToken =
            await widget.verifyReset(email, widget.role, _otp.text.trim());
        if (mounted) setState(() => _step = 2);
      } else {
        await widget.completeReset(_resetToken!, _password.text);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Password updated. You can now sign in.')));
        }
      }
    } catch (error) {
      _setError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setError(String message) {
    setState(() => _error = message);
  }
}
