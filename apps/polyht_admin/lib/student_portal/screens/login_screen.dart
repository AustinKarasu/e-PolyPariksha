import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/saved_credentials_service.dart';
import '../../widgets/forgot_password_dialog.dart';
import '../widgets/password_strength_indicator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _collegeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  bool _obscurePassword = true;
  bool _showTotp = false;
  bool _saveCredentials = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _animController.dispose();
    _collegeIdController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final showTotp = _showTotp || auth.requiresTwoFactor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    final muted =
        Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF160B2A),
                    Color(0xFF31205B),
                    Color(0xFF0F0A1A)
                  ]
                : const [
                    Color(0xFF4C1D95),
                    Color(0xFF7C3AED),
                    Color(0xFFF8F5FF)
                  ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo & branding ──
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.primaryDark.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset('assets/images/polyht_logo.png',
                              fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'e-PolyPariksha HP',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Student Portal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── Login card ──
                      Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXl),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.primaryDark.withValues(alpha: 0.12),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Welcome',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Use your college-provided credentials to sign in.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: muted,
                                    ),
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _collegeIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Board roll no',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                textInputAction: TextInputAction.next,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Required'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (value) =>
                                    value == null || value.length < 6
                                        ? 'Minimum 6 characters'
                                        : null,
                              ),
                              if (showTotp) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _totpController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '2FA code',
                                    prefixIcon:
                                        Icon(Icons.verified_user_outlined),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: (value) => showTotp &&
                                          (value == null ||
                                              value.trim().length < 6)
                                      ? 'Enter your authenticator code'
                                      : null,
                                ),
                              ],
                              CheckboxListTile(
                                value: _saveCredentials,
                                onChanged: (value) => setState(
                                    () => _saveCredentials = value ?? false),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text('Save login details'),
                                subtitle: const Text(
                                    'Use only on your personal device.'),
                              ),
                              const SizedBox(height: 8),
                              if (auth.error != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.error.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          size: 18, color: AppTheme.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          auth.error!
                                              .replaceAll('Exception: ', ''),
                                          style: const TextStyle(
                                              color: AppTheme.error,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _submit,
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white),
                                        )
                                      : Text(showTotp
                                          ? 'Verify & sign in'
                                          : 'Sign in'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: auth.isLoading
                                    ? null
                                    : () => _showForgotPassword(context),
                                child: const Text('Forgot password?'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'e-PolyPariksha HP',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.65),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final identifier = _collegeIdController.text.trim();
    final password = _passwordController.text;
    await auth.login(
      identifier,
      password,
      totpCode: _totpController.text.trim(),
    );
    if (mounted && auth.requiresTwoFactor) {
      setState(() {
        _collegeIdController.text = identifier;
        _passwordController.text = password;
        _showTotp = true;
        _totpController.clear();
      });
    } else if (mounted && auth.isAuthenticated) {
      if (auth.requiresCredentialSetup) {
        // The authenticated test screen owns this mandatory dialog. Showing it
        // here as well races with that screen and can leave a stale second modal.
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        await _saveOrClearCredentials(identifier, password);
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  // Kept for the login-only credential-save preference flow; the mandatory
  // dialog itself is owned by the authenticated test screen.
  // ignore: unused_element
  Future<void> _showInitialCredentials(
      BuildContext context, String identifier) {
    final auth = context.read<AuthProvider>();
    final email = TextEditingController(text: auth.user?.email?.trim() ?? '');
    final otp = TextEditingController();
    final password = TextEditingController();
    final confirmPassword = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saveCredentials = _saveCredentials;
    var sendingOtp = false;
    var otpSent = false;
    var saving = false;
    String? submitError;

    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Secure your student account'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'You signed in with your date-of-birth password. Verify your email, then create a private password for future logins.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Email address'),
                      onChanged: (_) {
                        if (otpSent) setDialogState(() => otpSent = false);
                      },
                      validator: (value) => _isValidEmail(value ?? '')
                          ? null
                          : 'Enter a valid email address',
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: sendingOtp
                            ? null
                            : () async {
                                final targetEmail = email.text.trim();
                                if (!_isValidEmail(targetEmail)) {
                                  ScaffoldMessenger.of(dialogContext)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Enter a valid email address')));
                                  return;
                                }
                                setDialogState(() => sendingOtp = true);
                                try {
                                  await auth.requestInitialCredentialsOtp(
                                      targetEmail);
                                  if (dialogContext.mounted) {
                                    setDialogState(() {
                                      otpSent = true;
                                      submitError = null;
                                    });
                                  }
                                } catch (err) {
                                  if (dialogContext.mounted) {
                                    setDialogState(
                                        () => submitError = _cleanError(err));
                                  }
                                } finally {
                                  if (dialogContext.mounted) {
                                    setDialogState(() => sendingOtp = false);
                                  }
                                }
                              },
                        icon: sendingOtp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_outlined),
                        label: Text(sendingOtp ? 'Sending OTP' : 'Send OTP'),
                      ),
                    ),
                    if (otpSent) ...[
                      const SizedBox(height: 4),
                      Text(
                          'OTP sent. Check this email, including spam or junk.',
                          style: Theme.of(dialogContext).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: otp,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Email OTP'),
                      validator: (value) => (value ?? '').trim().length >= 6
                          ? null
                          : 'Enter the email OTP',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'New password'),
                      onChanged: (_) => setDialogState(() {}),
                      validator: (value) => _initialPasswordError(value ?? ''),
                    ),
                    const SizedBox(height: 8),
                    PasswordStrengthIndicator(password: password.text),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Confirm new password'),
                      validator: (value) => value == password.text
                          ? null
                          : 'Passwords do not match',
                    ),
                    CheckboxListTile(
                      value: saveCredentials,
                      onChanged: (value) => setDialogState(
                          () => saveCredentials = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Save new login details'),
                      subtitle: const Text('Use only on your personal device.'),
                    ),
                    if (submitError != null)
                      Text(submitError!,
                          style: TextStyle(
                              color:
                                  Theme.of(dialogContext).colorScheme.error)),
                  ],
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!otpSent) {
                          setDialogState(() => submitError =
                              'Send an OTP to your new email before continuing.');
                          return;
                        }
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => submitError = null);
                        setDialogState(() => saving = true);
                        try {
                          await auth.completeInitialCredentials(
                            email.text.trim(),
                            otp.text.trim(),
                            password.text,
                          );
                          _saveCredentials = saveCredentials;
                          await _saveOrClearCredentials(
                              identifier, password.text);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          }
                        } catch (err) {
                          if (dialogContext.mounted) {
                            setDialogState(
                                () => submitError = _cleanError(err));
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save and continue'),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      email.dispose();
      otp.dispose();
      password.dispose();
      confirmPassword.dispose();
    });
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await SavedCredentialsService().read();
    if (!mounted || saved == null) return;
    setState(() {
      _collegeIdController.text = saved.identifier;
      _passwordController.text = saved.password;
      _saveCredentials = true;
    });
  }

  Future<void> _saveOrClearCredentials(
      String identifier, String password) async {
    final storage = SavedCredentialsService();
    if (_saveCredentials) {
      await storage.save(identifier, password);
    } else {
      await storage.clear();
    }
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  String? _initialPasswordError(String value) {
    if (value.length < 8) return 'Use at least 8 characters';
    return null;
  }

  String _cleanError(Object err) {
    return err.toString().replaceFirst('Exception: ', '');
  }

  void _showForgotPassword(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (_) => ForgotPasswordDialog(
        role: 'student',
        requestReset: auth.requestPasswordReset,
        verifyReset: auth.verifyPasswordReset,
        completeReset: auth.completePasswordReset,
      ),
    );
  }
}
