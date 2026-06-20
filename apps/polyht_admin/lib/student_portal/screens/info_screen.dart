import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  static final Uri _collegeUri = Uri.parse('https://gpkangra.edu.in');
  static final Uri _mailUri = Uri.parse('mailto:aayankarasu@gmail.com');
  static final Uri _phoneUri = Uri.parse('tel:8091726602');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Info'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return _InfoTile(
                icon: Icons.info_outline_rounded,
                label: 'App Version',
                value: info == null
                    ? 'Loading...'
                    : '${info.version} (${info.buildNumber})',
              );
            },
          ),
          const _InfoTile(
              icon: Icons.person_rounded,
              label: 'Made by',
              value: 'Aayan Parmar'),
          _InfoTile(
              icon: Icons.phone_rounded,
              label: 'Contact',
              value: '8091726602',
              onTap: () => _open(_phoneUri)),
          _InfoTile(
              icon: Icons.email_rounded,
              label: 'Gmail',
              value: 'aayankarasu@gmail.com',
              onTap: () => _open(_mailUri)),
          _InfoTile(
              icon: Icons.language_rounded,
              label: 'College Website',
              value: 'https://gpkangra.edu.in',
              onTap: () => _open(_collegeUri)),
        ],
      ),
    );
  }

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(label),
        subtitle: Text(value),
        trailing: onTap == null ? null : const Icon(Icons.open_in_new_rounded),
        onTap: onTap,
      ),
    );
  }
}
