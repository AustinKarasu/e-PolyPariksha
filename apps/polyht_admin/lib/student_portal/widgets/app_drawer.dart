import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../screens/history_screen.dart';
import '../screens/info_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user;
    final collegeName = user?.collegeName?.trim().isNotEmpty == true ? user!.collegeName! : 'e-PolyPariksha HP';

    return Drawer(
      child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 20, right: 20, bottom: 20),
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/images/e-PolyPariksha HP_logo.png', width: 52, height: 52, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        collegeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user?.fullName ?? 'Student',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                if (user?.collegeId != null)
                  Text(
                    user!.collegeId!,
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (user?.branchName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user!.branchName!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    if (user?.semester != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Sem ${user!.semester}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Menu items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.person_outline_rounded,
                  label: 'My Profile',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  },
                ),
                _DrawerItem(
                  icon: Icons.history_rounded,
                  label: 'Test History',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
                _DrawerItem(
                  icon: Icons.info_outline_rounded,
                  label: 'App Info',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoScreen()));
                  },
                ),
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  secondary: Icon(theme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppTheme.primary),
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500)),
                  value: theme.isDark,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (_) => theme.toggle(),
                ),
                const Divider(height: 24),
                _DrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  color: AppTheme.error,
                  onTap: () {
                    Navigator.of(context).pop();
                    auth.logout();
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'e-PolyPariksha HP Student v1.0.0',
              style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: color ?? AppTheme.primary),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
