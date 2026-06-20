import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/student_test.dart';
import '../services/notification_service.dart';
import '../providers/auth_provider.dart';
import '../services/test_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/update_button.dart';
import 'exam_screen.dart';

class TestListScreen extends StatefulWidget {
  const TestListScreen({super.key});

  @override
  State<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends State<TestListScreen> {
  final _service = TestService();
  late Future<List<StudentTest>> _tests;
  Timer? _refreshTimer;
  bool _credentialDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _tests = _loadTests();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_refreshTestsSilently());
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkCredentialSetup());
  }

  Future<List<StudentTest>> _loadTests() async {
    final tests = await _service.fetchTests();
    await NotificationService.instance.scheduleTests(tests);
    return tests;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshTestsSilently() async {
    try {
      final tests = await _loadTests();
      if (mounted) {
        setState(() => _tests = Future.value(tests));
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkCredentialSetup());
  }

  Future<void> _checkCredentialSetup() async {
    if (!mounted || _credentialDialogShowing) return;
    final auth = context.read<AuthProvider>();
    if (auth.requiresCredentialSetup != true) return;
    _credentialDialogShowing = true;
    try {
      await _showCredentialSetupDialog(auth);
    } finally {
      _credentialDialogShowing = false;
    }
  }

  Future<void> _showCredentialSetupDialog(AuthProvider auth) async {
    final email = TextEditingController(text: auth.user?.email?.trim() ?? '');
    final otp = TextEditingController();
    final password = TextEditingController();
    final confirmPassword = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var sendingOtp = false;
    var saving = false;

    await showDialog<void>(
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
                      'Your account is still using the date-of-birth password. Verify your email, then create a private password before continuing.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email address',
                        suffixIcon: IconButton(
                          tooltip: 'Send OTP',
                          icon: sendingOtp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_outlined),
                          onPressed: sendingOtp
                              ? null
                              : () async {
                                  final targetEmail = email.text.trim();
                                  if (!_validEmail(targetEmail)) {
                                    ScaffoldMessenger.of(dialogContext)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Enter a valid email address')),
                                    );
                                    return;
                                  }
                                  setDialogState(() => sendingOtp = true);
                                  try {
                                    await auth.requestInitialCredentialsOtp(
                                        targetEmail);
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('OTP sent to this email')),
                                      );
                                    }
                                  } catch (err) {
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(_cleanError(err))),
                                      );
                                    }
                                  } finally {
                                    if (dialogContext.mounted) {
                                      setDialogState(() => sendingOtp = false);
                                    }
                                  }
                                },
                        ),
                      ),
                      validator: (value) => _validEmail(value ?? '')
                          ? null
                          : 'Enter a valid email address',
                    ),
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
                      validator: (value) => _passwordError(value ?? ''),
                    ),
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
                  ],
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        try {
                          await auth.completeInitialCredentials(
                            email.text.trim(),
                            otp.text.trim(),
                            password.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (err) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(_cleanError(err))),
                            );
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
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save and continue'),
              ),
            ],
          ),
        ),
      ),
    );
    email.dispose();
    otp.dispose();
    password.dispose();
    confirmPassword.dispose();
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  String? _passwordError(String value) {
    if (value.length < 10) return 'Use at least 10 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Add an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Add a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Add a number';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return 'Add a symbol';
    return null;
  }

  String _cleanError(Object err) =>
      err.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      drawer: const AppDrawer(),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            expandedHeight: 170,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppTheme.headerGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                  'assets/images/polyht_logo.png',
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    auth.user?.fullName ?? 'Student',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    auth.user?.collegeName ?? 'House Tests',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: const [
              UpdateButton(),
            ],
          ),
        ],
        body: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => setState(() => _tests = _loadTests()),
          child: FutureBuilder<List<StudentTest>>(
            future: _tests,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary));
              }
              if (snapshot.hasError) {
                final message =
                    snapshot.error.toString().replaceFirst('Exception: ', '');
                return _buildEmpty(
                  Icons.cloud_off_rounded,
                  'Connection error',
                  '$message. Pull to refresh.',
                );
              }
              final tests = snapshot.data ?? [];
              if (tests.isEmpty) {
                return _buildEmpty(
                  Icons.quiz_outlined,
                  'No tests assigned',
                  'Your house tests will appear here when scheduled.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: tests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _StudentTestCard(
                  test: tests[index],
                  onRefresh: () => setState(() => _tests = _loadTests()),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(IconData icon, String title, String subtitle) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(icon,
            size: 72, color: AppTheme.primaryLight.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

class _StudentTestCard extends StatelessWidget {
  const _StudentTestCard({required this.test, required this.onRefresh});

  final StudentTest test;
  final VoidCallback onRefresh;

  Color get _statusColor {
    if (test.isLocked) return AppTheme.error;
    switch (test.status) {
      case 'live':
        return AppTheme.success;
      case 'upcoming':
        return AppTheme.accent;
      default:
        return AppTheme.ink.withValues(alpha: 0.3);
    }
  }

  IconData get _statusIcon {
    if (test.isLocked) return Icons.lock_rounded;
    switch (test.status) {
      case 'live':
        return Icons.play_circle_filled_rounded;
      case 'upcoming':
        return Icons.schedule_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  String get _statusLabel {
    if (test.isCompleted) return 'SUBMITTED';
    if (test.isLocked) return 'LOCKED';
    return test.status.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd MMM, hh:mm a');
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.ink;
    final muted = textColor.withValues(alpha: 0.6);
    final scheduleBg = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSurface
        : AppTheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: test.isLive && !test.isLocked
              ? AppTheme.success.withValues(alpha: 0.3)
              : AppTheme.primaryLight.withValues(alpha: 0.1),
          width: test.isLive && !test.isLocked ? 1.5 : 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    test.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: 14, color: _statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Schedule bar ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheduleBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${format.format(test.scheduledStart)} - ${format.format(test.scheduledEnd)}',
                    style: TextStyle(fontSize: 12, color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.timer_outlined, size: 14, color: muted),
                const SizedBox(width: 4),
                Text(
                  'Sem ${test.semester} - ${test.timeLimitMinutes} min',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: muted),
                ),
              ],
            ),
          ),

          // ── Locked reason ──
          if (test.isLocked && test.blockedReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: AppTheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        test.blockedReason!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Action button ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: test.canStart
                    ? () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ExamScreen(test: test)));
                        onRefresh();
                      }
                    : test.canDownloadAfterEnd
                        ? () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    ExamScreen(test: test, reviewOnly: true)));
                            onRefresh();
                          }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: test.canStart ? AppTheme.success : null,
                  disabledBackgroundColor:
                      AppTheme.primaryLight.withValues(alpha: 0.08),
                  disabledForegroundColor: AppTheme.ink.withValues(alpha: 0.3),
                ),
                icon: Icon(test.canDownloadAfterEnd
                    ? Icons.picture_as_pdf_rounded
                    : test.isLocked
                        ? Icons.lock_rounded
                        : Icons.play_arrow_rounded),
                label: Text(test.canDownloadAfterEnd
                    ? 'View question paper'
                    : test.isCompleted
                        ? 'Submitted'
                        : test.isLocked
                            ? 'Locked - contact admin'
                            : test.isLive
                                ? 'Start Test'
                                : test.status == 'upcoming'
                                    ? 'Not available yet'
                                    : 'Test ended'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
