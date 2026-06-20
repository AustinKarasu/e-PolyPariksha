import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_theme.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../utils/photo_image.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const Scaffold(body: Center(child: Text('Not signed in')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: InkWell(
              onTap: _saving ? null : _pickPhoto,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                backgroundImage: profileImageProvider(user.photoUrl, ApiConfig.baseUrl),
                child: user.photoUrl == null ? Text(user.fullName[0].toUpperCase()) : null,
              ),
            ),
            title: Text(user.fullName),
            subtitle: Text(user.email ?? 'Administrator'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _saving ? null : _editProfile, icon: const Icon(Icons.edit_rounded), label: const Text('Edit Profile')),
          const SizedBox(height: 20),
          _SettingCard(
            title: 'Two-factor authentication',
            subtitle: user.twoFactorEnabled == true ? 'Enabled for this admin account' : 'Off for this admin account',
            action: FilledButton(
              onPressed: _saving ? null : () => user.twoFactorEnabled == true ? _disable2fa(auth) : _enable2fa(auth),
              child: Text(user.twoFactorEnabled == true ? 'Disable' : 'Enable'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final auth = context.read<AuthProvider>();
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file == null || (file.path == null && file.bytes == null)) return;
    setState(() => _saving = true);
    try {
      await auth.uploadProfilePhoto(
        imagePath: file.path,
        imageBytes: file.bytes,
        imageName: file.name,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editProfile() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user!;
    final name = TextEditingController(text: user.fullName);
    final email = TextEditingController(text: user.email ?? '');
    final phone = TextEditingController(text: user.phone ?? '');
    final address = TextEditingController(text: user.address ?? '');
    final emailOtp = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(
              controller: emailOtp,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Email OTP (required only when changing email)',
                suffixIcon: IconButton(
                  tooltip: 'Send email OTP',
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () async {
                    await auth.requestEmailChangeOtp(email.text.trim());
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification code sent to the new email')));
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 12),
            TextField(controller: address, maxLines: 3, decoration: const InputDecoration(labelText: 'Address')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await auth.updateProfile(fullName: name.text.trim(), email: email.text.trim(), phone: phone.text.trim(), address: address.text.trim(), emailOtpCode: emailOtp.text.trim());
    }
    name.dispose();
    email.dispose();
    phone.dispose();
    address.dispose();
    emailOtp.dispose();
  }

  Future<void> _enable2fa(AuthProvider auth) async {
    final setup = await auth.setupTwoFactor();
    if (!mounted) return;
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable 2FA'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Scan the QR code with your authenticator app, then enter the generated code.'),
            const SizedBox(height: 12),
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: setup['otpauthUrl'] as String, size: 190),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(setup['secret'] as String),
            const SizedBox(height: 12),
            TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Authenticator code')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Enable')),
        ],
      ),
    );
    if (ok == true) await auth.enableTwoFactor(code.text.trim());
    code.dispose();
  }

  Future<void> _disable2fa(AuthProvider auth) async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable 2FA'),
        content: TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Authenticator code')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Disable')),
        ],
      ),
    );
    if (ok == true) await auth.disableTwoFactor(code.text.trim());
    code.dispose();
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.title, required this.subtitle, required this.action});
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(AppTheme.radiusLg), boxShadow: AppTheme.cardShadow),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(subtitle)])),
        action,
      ]),
    );
  }
}
