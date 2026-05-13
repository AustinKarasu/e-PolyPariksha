import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_theme.dart';
import '../models/admin_account.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import '../services/excel_bulk_service.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  final _service = AdminService();
  final _bulkService = ExcelBulkService();
  late Future<List<AdminAccount>> _admins;
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    _admins = _service.fetchAdmins();
  }

  void _refresh() => setState(() => _admins = _service.fetchAdmins());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Accounts'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: [
          IconButton(
            tooltip: 'Import Excel',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: _bulkBusy ? null : _importAdmins,
          ),
          IconButton(
            tooltip: 'Export Excel',
            icon: const Icon(Icons.download_rounded),
            onPressed: _bulkBusy ? null : _exportAdmins,
          ),
          IconButton(
            tooltip: 'My 2FA',
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: _manageMy2fa,
          ),
          IconButton(
            tooltip: 'Clear data',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _showClearDataDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Admin'),
      ),
      body: FutureBuilder<List<AdminAccount>>(
        future: _admins,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final admins = snapshot.data ?? [];
          if (admins.isEmpty) {
            return const Center(child: Text('No admin accounts found'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: admins.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _AdminTile(
              admin: admins[index],
              onPrimary: () async {
                await _service.setPrimary(admins[index].id);
                _refresh();
              },
              onToggle: () async {
                await _service.setActive(admins[index].id, !admins[index].isActive);
                _refresh();
              },
              onDelete: () => _confirmDelete(admins[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(AdminAccount admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete admin?'),
        content: Text('Delete ${admin.fullName}? Primary admins cannot be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteAdmin(admin.id);
      _refresh();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _importAdmins() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;

    setState(() => _bulkBusy = true);
    try {
      final importResult = await _bulkService.importAdmins(bytes);
      _refresh();
      if (!mounted) return;
      final details = importResult.messages.take(8).join('\n');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Admin import complete'),
          content: SingleChildScrollView(
            child: Text(details.isEmpty ? importResult.summary : '${importResult.summary}\n\n$details'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _exportAdmins() async {
    setState(() => _bulkBusy = true);
    try {
      final admins = await _service.fetchAdmins();
      final file = await _bulkService.exportAdmins(admins);
      await _bulkService.open(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${admins.length} admins')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Admin'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => value == null || value.trim().length < 2 ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (value) => value == null || !value.contains('@') ? 'Enter valid email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Temporary password', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (value) => value == null || value.length < 10 ? 'Minimum 10 characters' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await _service.createAdmin(
                fullName: nameController.text.trim(),
                email: emailController.text.trim(),
                password: passwordController.text,
              );
              if (context.mounted) Navigator.of(context).pop();
              _refresh();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _showClearDataDialog() async {
    final auth = context.read<AuthProvider>();
    if (auth.user?.twoFactorEnabled != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable 2FA before clearing data.')));
      return;
    }
    final codeController = TextEditingController();
    bool tests = false;
    bool history = false;
    bool students = false;
    bool sessions = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Clear app data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select exactly what to clear. This action cannot be undone.'),
                CheckboxListTile(
                  value: tests,
                  onChanged: (value) => setDialogState(() => tests = value ?? false),
                  title: const Text('Tests and PDFs'),
                  subtitle: const Text('Deletes tests, attempts, and test events.'),
                ),
                CheckboxListTile(
                  value: history,
                  onChanged: (value) => setDialogState(() => history = value ?? false),
                  title: const Text('Student test history'),
                  subtitle: const Text('Deletes attempts and exam logs only.'),
                ),
                CheckboxListTile(
                  value: students,
                  onChanged: (value) => setDialogState(() => students = value ?? false),
                  title: const Text('Student accounts'),
                  subtitle: const Text('Deletes students and their sessions/history.'),
                ),
                CheckboxListTile(
                  value: sessions,
                  onChanged: (value) => setDialogState(() => sessions = value ?? false),
                  title: const Text('All login sessions'),
                  subtitle: const Text('Forces every user to sign in again.'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '2FA code'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear selected'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      codeController.dispose();
      return;
    }
    try {
      await _service.clearData(
        totpCode: codeController.text.trim(),
        tests: tests,
        history: history,
        students: students,
        sessions: sessions,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected data cleared')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      codeController.dispose();
    }
  }

  Future<void> _manageMy2fa() async {
    final auth = context.read<AuthProvider>();
    final enabled = auth.user?.twoFactorEnabled == true;
    if (enabled) {
      await _disable2fa(auth);
    } else {
      await _enable2fa(auth);
    }
    _refresh();
  }

  Future<void> _enable2fa(AuthProvider auth) async {
    final setup = await auth.setupTwoFactor();
    if (!mounted) return;
    final codeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable 2FA'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Scan the QR code with an authenticator app, then enter the 6-digit code.'),
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
            TextField(controller: codeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Authenticator code')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Enable')),
        ],
      ),
    );
    if (confirmed == true) await auth.enableTwoFactor(codeController.text.trim());
    codeController.dispose();
  }

  Future<void> _disable2fa(AuthProvider auth) async {
    final codeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable 2FA'),
        content: TextField(controller: codeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Authenticator code')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Disable')),
        ],
      ),
    );
    if (confirmed == true) await auth.disableTwoFactor(codeController.text.trim());
    codeController.dispose();
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.admin,
    required this.onPrimary,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminAccount admin;
  final VoidCallback onPrimary;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.1)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.admin_panel_settings_rounded, size: 22, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(admin.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                if (admin.isPrimaryAdmin) const Chip(label: Text('Primary'), visualDensity: VisualDensity.compact),
              ]),
              Text(admin.email, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6))),
              const SizedBox(height: 4),
              Text(
                '${admin.twoFactorEnabled ? '2FA enabled' : '2FA off'} - ${admin.isActive ? 'Active' : 'Inactive'}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
              ),
            ]),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'primary') onPrimary();
              if (value == 'toggle') onToggle();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              if (!admin.isPrimaryAdmin) const PopupMenuItem(value: 'primary', child: Text('Make primary')),
              PopupMenuItem(value: 'toggle', child: Text(admin.isActive ? 'Deactivate' : 'Activate')),
              if (!admin.isPrimaryAdmin) const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}
