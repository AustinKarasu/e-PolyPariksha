import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_theme.dart';
import '../models/admin_account.dart';
import '../models/admin_application.dart';
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
  late Future<List<AdminApplication>> _applications;
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    _admins = _service.fetchAdmins();
    _applications = _service.fetchApplications();
  }

  void _refresh() => setState(() {
        _admins = _service.fetchAdmins();
        _applications = _service.fetchApplications();
      });

  @override
  Widget build(BuildContext context) {
    final isPrimaryAdmin =
        context.watch<AuthProvider>().user?.isPrimaryAdmin == true;
    if (!isPrimaryAdmin) {
      return const Scaffold(
        body: Center(
            child: Text('Only the superuser can manage admin accounts.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Accounts'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: [
          IconButton(
            tooltip: 'Import Excel',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: !isPrimaryAdmin || _bulkBusy ? null : _importAdmins,
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
            tooltip: 'Clear logs and applications',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _showClearDataDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isPrimaryAdmin ? _showCreateDialog : null,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Admin'),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            FutureBuilder<List<AdminApplication>>(
              future: _applications,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                              color: AppTheme.primary)));
                }
                final applications = snapshot.data ?? [];
                final pending = applications
                    .where((application) => application.status == 'pending')
                    .length;
                return _ApplicationsMenu(
                  total: applications.length,
                  pending: pending,
                  onTap: () => _showApplicationsDialog(applications),
                );
              },
            ),
            const SizedBox(height: 18),
            Text('Admins',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            FutureBuilder<List<AdminAccount>>(
              future: _admins,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                              color: AppTheme.primary)));
                }
                if (snapshot.hasError) {
                  return _EmptyPanel(
                      text: snapshot.error
                          .toString()
                          .replaceFirst('Exception: ', ''));
                }
                final admins = snapshot.data ?? [];
                if (admins.isEmpty) {
                  return const _EmptyPanel(text: 'No admin accounts found');
                }
                return Column(
                  children: [
                    for (final admin in admins) ...[
                      _AdminTile(
                        admin: admin,
                        canManagePrimary: isPrimaryAdmin,
                        onPrimary: () => _makePrimary(admin),
                        onToggle: () async {
                          await _service.setActive(admin.id, !admin.isActive);
                          _refresh();
                        },
                        onDelete: () => _confirmDelete(admin),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApplicationsDialog(
      List<AdminApplication> applications) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Applications'),
        content: SizedBox(
          width: 560,
          height: 460,
          child: applications.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No admin applications',
                      textAlign: TextAlign.center),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: applications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final application = applications[index];
                    return _ApplicationTile(
                      application: application,
                      onApprove: () {
                        Navigator.of(context).pop();
                        _approveApplication(application);
                      },
                      onReject: () {
                        Navigator.of(context).pop();
                        _rejectApplication(application);
                      },
                      onDelete: () {
                        Navigator.of(context).pop();
                        _deleteApplication(application);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _approveApplication(AdminApplication application) async {
    try {
      await _service.approveApplication(application.id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${application.fullName} approved')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _rejectApplication(AdminApplication application) async {
    try {
      await _service.rejectApplication(application.id);
      _refresh();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _deleteApplication(AdminApplication application) async {
    try {
      await _service.deleteApplication(application.id);
      _refresh();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _confirmDelete(AdminAccount admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete admin?'),
        content:
            Text('Delete ${admin.fullName}? Primary admins cannot be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _makePrimary(AdminAccount admin) async {
    try {
      await _service.setPrimary(admin.id);
    } catch (err) {
      final message = err.toString().replaceFirst('Exception: ', '');
      if (!message.toLowerCase().contains('otp')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }
    }
    if (!mounted) return;
    final otpController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify primary admin change'),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Email OTP'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Verify')),
        ],
      ),
    );
    if (confirmed != true) {
      otpController.dispose();
      return;
    }
    try {
      await _service.setPrimary(admin.id, otpCode: otpController.text.trim());
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${admin.fullName} is now primary')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      otpController.dispose();
    }
  }

  Future<void> _importAdmins() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
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
            child: Text(details.isEmpty
                ? importResult.summary
                : '${importResult.summary}\n\n$details'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK')),
          ],
        ),
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported ${admins.length} admins')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
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
    final otpController = TextEditingController();
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
                  decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined)),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter valid email'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Temporary password',
                      prefixIcon: Icon(Icons.lock_outline)),
                  validator: (value) => value == null || value.length < 10
                      ? 'Minimum 10 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Your email OTP',
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    suffixIcon: IconButton(
                      tooltip: 'Send OTP',
                      icon: const Icon(Icons.send_outlined),
                      onPressed: () async {
                        await _service.requestCreateAdminOtp();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your email')));
                        }
                      },
                    ),
                  ),
                  validator: (value) => value == null || value.trim().length != 6 ? 'Enter the 6-digit OTP' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await _service.createAdmin(
                fullName: nameController.text.trim(),
                email: emailController.text.trim(),
                password: passwordController.text,
                otpCode: otpController.text.trim(),
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
    otpController.dispose();
  }

  Future<void> _showClearDataDialog() async {
    final auth = context.read<AuthProvider>();
    if (auth.user?.twoFactorEnabled != true) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable 2FA before clearing data.')));
      return;
    }
    final codeController = TextEditingController();
    bool tests = false;
    bool history = false;
    bool students = false;
    bool sessions = false;
    bool logs = false;
    bool applications = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Clear app data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Select exactly what to clear. This action cannot be undone.'),
                CheckboxListTile(
                  value: tests,
                  onChanged: (value) =>
                      setDialogState(() => tests = value ?? false),
                  title: const Text('Tests and PDFs'),
                  subtitle:
                      const Text('Deletes tests, attempts, and test events.'),
                ),
                CheckboxListTile(
                  value: history,
                  onChanged: (value) =>
                      setDialogState(() => history = value ?? false),
                  title: const Text('Student test history'),
                  subtitle: const Text('Deletes attempts and exam logs only.'),
                ),
                CheckboxListTile(
                  value: students,
                  onChanged: (value) =>
                      setDialogState(() => students = value ?? false),
                  title: const Text('Student accounts'),
                  subtitle: const Text(
                      'Deletes students and their sessions/history.'),
                ),
                CheckboxListTile(
                  value: logs,
                  onChanged: (value) =>
                      setDialogState(() => logs = value ?? false),
                  title: const Text('All logs'),
                  subtitle:
                      const Text('Deletes exam events and login failure logs.'),
                ),
                CheckboxListTile(
                  value: applications,
                  onChanged: (value) =>
                      setDialogState(() => applications = value ?? false),
                  title: const Text('All applications'),
                  subtitle: const Text(
                      'Deletes pending, approved, and rejected admin applications.'),
                ),
                CheckboxListTile(
                  value: sessions,
                  onChanged: (value) =>
                      setDialogState(() => sessions = value ?? false),
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
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
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
        logs: logs,
        applications: applications,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected data cleared')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err.toString().replaceFirst('Exception: ', ''))));
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
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Scan the QR code with an authenticator app, then enter the 6-digit code.'),
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
                    controller: codeController,
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
    if (confirmed == true) {
      await auth.enableTwoFactor(codeController.text.trim());
    }
    codeController.dispose();
  }

  Future<void> _disable2fa(AuthProvider auth) async {
    final codeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable 2FA'),
        content: TextField(
            controller: codeController,
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
    if (confirmed == true) {
      await auth.disableTwoFactor(codeController.text.trim());
    }
    codeController.dispose();
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.admin,
    required this.canManagePrimary,
    required this.onPrimary,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminAccount admin;
  final bool canManagePrimary;
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
            decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.admin_panel_settings_rounded,
                size: 22, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(admin.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15))),
                if (admin.isPrimaryAdmin)
                  const Chip(
                      label: Text('Primary'),
                      visualDensity: VisualDensity.compact),
              ]),
              Text(admin.email,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.6))),
              const SizedBox(height: 4),
              Text(
                '${admin.twoFactorEnabled ? '2FA enabled' : '2FA off'} - ${admin.isActive ? 'Active' : 'Inactive'}',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.6)),
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
              if (canManagePrimary && !admin.isPrimaryAdmin)
                const PopupMenuItem(
                    value: 'primary', child: Text('Make primary')),
              PopupMenuItem(
                  value: 'toggle',
                  child: Text(admin.isActive ? 'Deactivate' : 'Activate')),
              if (!admin.isPrimaryAdmin)
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({
    required this.application,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  final AdminApplication application;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final pending = application.status == 'pending';
    final muted =
        Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.65);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.1)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(application.email,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: muted)),
                  ],
                ),
              ),
              _StatusPill(status: application.status),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ApplicationMeta(
                    icon: Icons.phone_outlined, text: application.mobile),
                const SizedBox(height: 5),
                _ApplicationMeta(
                    icon: Icons.account_balance_outlined,
                    text: application.collegeName),
                const SizedBox(height: 5),
                _ApplicationMeta(
                    icon: Icons.map_outlined, text: application.stateName),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final approve = FilledButton.icon(
                onPressed: pending ? onApprove : null,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Accept'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
              );
              final reject = OutlinedButton.icon(
                onPressed: pending ? onReject : null,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side:
                      BorderSide(color: AppTheme.error.withValues(alpha: 0.55)),
                  minimumSize: const Size.fromHeight(44),
                ),
              );
              final remove = IconButton.outlined(
                tooltip: 'Remove application',
                onPressed: onDelete,
                color: AppTheme.error,
                icon: const Icon(Icons.delete_outline_rounded),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    approve,
                    const SizedBox(height: 8),
                    reject,
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.35)),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: approve),
                  const SizedBox(width: 10),
                  Expanded(child: reject),
                  const SizedBox(width: 8),
                  remove,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApplicationMeta extends StatelessWidget {
  const _ApplicationMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppTheme.success,
      'rejected' => AppTheme.error,
      _ => AppTheme.accent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ApplicationsMenu extends StatelessWidget {
  const _ApplicationsMenu(
      {required this.total, required this.pending, required this.onTap});

  final int total;
  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border:
              Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.12)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.assignment_ind_outlined,
                  color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Applications',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    pending == 0
                        ? '$total total applications'
                        : '$pending pending - $total total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.65),
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.1)),
      ),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
