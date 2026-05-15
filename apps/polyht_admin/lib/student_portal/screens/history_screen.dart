import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/student_test.dart';
import '../services/test_service.dart';
import 'exam_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = TestService();
  late Future<List<StudentTest>> _tests;

  @override
  void initState() {
    super.initState();
    _tests = _loadHistory();
  }

  Future<List<StudentTest>> _loadHistory() async {
    return _service.fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test History'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => setState(() => _tests = _loadHistory()),
        child: FutureBuilder<List<StudentTest>>(
          future: _tests,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
            }
            if (snapshot.hasError) {
              final message = snapshot.error.toString().replaceFirst('Exception: ', '');
              return _EmptyHistory(message: '$message. Pull to refresh.');
            }
            final tests = snapshot.data ?? [];
            if (tests.isEmpty) {
              return const _EmptyHistory(message: 'Ended tests will appear here with their question papers.');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: tests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _HistoryCard(
                test: tests[index],
                onRefresh: () => setState(() => _tests = _loadHistory()),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.test, required this.onRefresh});

  final StudentTest test;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd MMM yyyy, hh:mm a');
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.ink;
    final muted = textColor.withValues(alpha: 0.62);
    final filename = test.originalFilename ?? 'Question paper';
    final duration = _formatDuration(test.activeSeconds);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.12)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
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
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.history_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(test.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text('Sem ${test.semester} - ${test.timeLimitMinutes} min', style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.event_rounded, label: 'Class test', value: '${format.format(test.scheduledStart)} - ${format.format(test.scheduledEnd)}'),
          _InfoRow(icon: Icons.login_rounded, label: 'Started', value: test.startedAt == null ? 'Not started' : format.format(test.startedAt!)),
          _InfoRow(icon: Icons.update_rounded, label: 'Last activity', value: test.lastSeenAt == null ? '-' : format.format(test.lastSeenAt!)),
          _InfoRow(icon: Icons.timer_outlined, label: 'Time spent', value: duration),
          _InfoRow(icon: Icons.check_circle_outline_rounded, label: 'Status', value: test.isCompleted ? 'Submitted' : 'Ended'),
          _InfoRow(icon: Icons.picture_as_pdf_rounded, label: 'Paper', value: filename),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: test.canDownloadAfterEnd
                  ? () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamScreen(test: test, reviewOnly: true)));
                      onRefresh();
                    }
                  : null,
              icon: Icon(test.canDownloadAfterEnd ? Icons.download_rounded : Icons.block_rounded),
              label: Text(test.canDownloadAfterEnd ? 'Download question paper' : 'Question paper unavailable'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds < 0) return '-';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.58);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 8),
          SizedBox(width: 86, child: Text(label, style: TextStyle(fontSize: 12, color: muted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.history_rounded, size: 72, color: AppTheme.primaryLight.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text('No history yet', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.55))),
        ),
      ],
    );
  }
}
