import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart' as admin;
import '../student_portal/providers/auth_provider.dart' as student;
import '../student_portal/screens/test_list_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../student_portal/screens/login_screen.dart' as student_login;

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminAuth = context.watch<admin.AuthProvider>();
    final studentAuth = context.watch<student.AuthProvider>();

    if (adminAuth.isAuthenticated) return const DashboardScreen();
    if (studentAuth.isAuthenticated) return const TestListScreen();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2937), Color(0xFF2563EB), Color(0xFFF8FAFC)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset('assets/images/polyht_logo.png', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Poly H.T',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your portal',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 16),
                    ),
                    const SizedBox(height: 34),
                    _RoleButton(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin',
                      subtitle: 'Login or register an admin account',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                    ),
                    const SizedBox(height: 14),
                    _RoleButton(
                      icon: Icons.school_outlined,
                      title: 'Student',
                      subtitle: 'Login with board roll no and admin-given password',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const student_login.LoginScreen())),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.65);
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
