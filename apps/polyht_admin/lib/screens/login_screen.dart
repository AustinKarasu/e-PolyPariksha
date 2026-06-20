import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import 'admin_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  bool _obscurePassword = true;
  bool _showTotp = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final showTotp = _showTotp || auth.requiresTwoFactor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final muted = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF160B2A), Color(0xFF31205B), Color(0xFF0F0A1A)]
                : const [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFF8F5FF)],
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
                              color: AppTheme.primaryDark.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset('assets/images/e-PolyPariksha HP_logo.png', fit: BoxFit.cover),
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
                        'Admin Portal',
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
                          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryDark.withValues(alpha: 0.12),
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
                                'Welcome back',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage branches, schedules, and question papers.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: muted,
                                    ),
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _identifierController,
                                decoration: const InputDecoration(
                                  labelText: 'Email or Admin ID',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                ),
                                textInputAction: TextInputAction.next,
                                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (value) => value == null || value.length < 6 ? 'Minimum 6 characters' : null,
                              ),
                              if (showTotp) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _totpController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '2FA code',
                                    prefixIcon: Icon(Icons.verified_user_outlined),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: (value) => showTotp && (value == null || value.trim().length < 6) ? 'Enter your authenticator code' : null,
                                ),
                              ],
                              const SizedBox(height: 8),
                              if (auth.error != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, size: 18, color: AppTheme.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          auth.error!.replaceAll('Exception: ', ''),
                                          style: const TextStyle(color: AppTheme.error, fontSize: 13),
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
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                        )
                                      : Text(showTotp ? 'Verify & sign in' : 'Sign in'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: auth.isLoading
                                    ? null
                                    : () => Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const AdminRegisterScreen()),
                                        ),
                                child: const Text('Register admin account'),
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
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    await auth.login(
      identifier,
      password,
      totpCode: _totpController.text.trim(),
    );
    if (mounted && auth.requiresTwoFactor) {
      setState(() {
        _identifierController.text = identifier;
        _passwordController.text = password;
        _showTotp = true;
        _totpController.clear();
      });
    } else if (mounted && auth.isAuthenticated) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

}
