import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/test_paper.dart';
import '../providers/auth_provider.dart';
import '../services/test_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/update_button.dart';
import 'admin_pdf_viewer_screen.dart';
import 'upload_test_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = TestService();
  late Future<List<TestPaper>> _tests;

  @override
  void initState() {
    super.initState();
    _tests = _service.fetchTests();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      drawer: const AppDrawer(),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
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
                              child: Image.asset('assets/images/polyht_logo.png', width: 44, height: 44, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, ${auth.user?.fullName ?? 'Admin'}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                  Text(
                                    'Manage house test papers and schedules',
                                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
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
            actions: const [UpdateButton()],
          ),
        ],
        body: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => setState(() => _tests = _service.fetchTests()),
          child: FutureBuilder<List<TestPaper>>(
            future: _tests,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }
              if (snapshot.hasError) {
                final message = snapshot.error.toString().replaceFirst('Exception: ', '');
                return _EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Connection error',
                  subtitle: '$message. Pull to refresh.',
                );
              }
              final tests = snapshot.data ?? [];
              if (tests.isEmpty) {
                return const _EmptyState(
                  icon: Icons.quiz_outlined,
                  title: 'No tests yet',
                  subtitle: 'Tap the button below to upload your first house test PDF.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: tests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _TestCard(
                  test: tests[index],
                  onChanged: () => setState(() => _tests = _service.fetchTests()),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUpload,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Upload PDF'),
      ),
    );
  }

  Future<void> _openUpload() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadTestScreen()));
    setState(() => _tests = _service.fetchTests());
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.55);
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 72, color: AppTheme.primaryLight.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ),
      ],
    );
  }
}

class _TestCard extends StatefulWidget {
  const _TestCard({required this.test, required this.onChanged});

  final TestPaper test;
  final VoidCallback onChanged;

  @override
  State<_TestCard> createState() => _TestCardState();
}

class _TestCardState extends State<_TestCard> {
  bool _busy = false;

  TestPaper get test => widget.test;

  Color get _statusColor => test.isActive ? AppTheme.success : AppTheme.error;

  Future<void> _runAction(Future<void> Function() action, {String? successMessage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      }
      widget.onChanged();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd MMM, hh:mm a');
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.ink;
    final muted = textColor.withValues(alpha: 0.6);
    final scheduleBg = Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : AppTheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.1)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: AppTheme.headerGradient, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Text(
                      test.branchName.substring(0, 2).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(test.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${test.branchName} - Sem ${test.semester} - ${test.timeLimitMinutes} min', style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(test.isActive ? 'Active' : 'Hidden', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: scheduleBg, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${format.format(test.scheduledStart)} - ${format.format(test.scheduledEnd)}', style: TextStyle(fontSize: 12, color: muted)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _toggleActive,
                    icon: Icon(test.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    label: Text(test.isActive ? 'Cancel' : 'Reactivate'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: test.isActive && !_busy ? _endNow : null,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('End Now'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _viewPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('View PDF'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _replacePdf,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Re-upload'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _delete,
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: BorderSide(color: AppTheme.error.withValues(alpha: 0.3))),
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(_busy ? 'Removing...' : 'Remove'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _replacePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || (file.path == null && file.bytes == null)) return;
    await _runAction(
      () => TestService().replacePdf(
        testId: test.id,
        pdfPath: file.path,
        pdfBytes: file.bytes,
        pdfName: file.name,
      ),
      successMessage: 'PDF replaced',
    );
  }

  Future<void> _viewPdf() async {
    try {
      final path = await TestService().downloadPdf(test.id);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdminPdfViewerScreen(title: test.title, filePath: path)),
      );
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _toggleActive() async {
    await _runAction(
      () => TestService().setTestActive(testId: test.id, isActive: !test.isActive),
      successMessage: test.isActive ? 'Test hidden' : 'Test reactivated',
    );
  }

  Future<void> _endNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End test now?'),
        content: Text('Students will no longer be able to access "${test.title}".'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('End Now')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(() => TestService().endTestNow(test.id), successMessage: 'Test ended');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove PDF test?'),
        content: Text('Are you sure you want to remove "${test.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(() => TestService().deleteTest(test.id), successMessage: 'Test removed');
  }
}
