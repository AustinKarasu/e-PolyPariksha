import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/attempt_report.dart';
import '../models/test_paper.dart';
import '../services/excel_bulk_service.dart';
import '../services/test_service.dart';

class AttemptReportsScreen extends StatefulWidget {
  const AttemptReportsScreen({super.key});

  @override
  State<AttemptReportsScreen> createState() => _AttemptReportsScreenState();
}

class _AttemptReportsScreenState extends State<AttemptReportsScreen> {
  final _testService = TestService();
  final _excelService = ExcelBulkService();
  late Future<List<TestPaper>> _tests;
  late Future<List<AttemptReport>> _reports;
  int? _selectedTestId;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tests = _testService.fetchTests();
    _reports = _testService.fetchAttemptReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Reports'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: [
          IconButton(
            tooltip: 'Download Excel',
            onPressed: _exporting ? null : _downloadReports,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: FutureBuilder<List<TestPaper>>(
              future: _tests,
              builder: (context, snapshot) {
                final tests = snapshot.data ?? [];
                return DropdownButtonFormField<int?>(
                  initialValue: _selectedTestId,
                  decoration: const InputDecoration(
                    labelText: 'Test',
                    prefixIcon: Icon(Icons.assignment_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('All tests')),
                    ...tests.map((test) => DropdownMenuItem<int?>(
                          value: test.id,
                          child:
                              Text(test.title, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedTestId = value;
                      _reports =
                          _testService.fetchAttemptReports(testId: value);
                    });
                  },
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async => setState(() {
                _tests = _testService.fetchTests();
                _reports =
                    _testService.fetchAttemptReports(testId: _selectedTestId);
              }),
              child: FutureBuilder<List<AttemptReport>>(
                future: _reports,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary));
                  }
                  if (snapshot.hasError) {
                    final message = snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', '');
                    return ListView(children: [
                      const SizedBox(height: 120),
                      const Center(child: Text('Unable to load reports')),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color),
                        ),
                      ),
                    ]);
                  }
                  final reports = snapshot.data ?? [];
                  if (reports.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 120),
                      Icon(Icons.description_outlined,
                          size: 64,
                          color: AppTheme.primaryLight.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No attempted tests yet',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _ReportCard(report: reports[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReports() async {
    setState(() => _exporting = true);
    try {
      final reports =
          await _testService.fetchAttemptReports(testId: _selectedTestId);
      final file = await _excelService.exportAttemptReports(reports);
      await _excelService.open(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Report saved to ${file.path}')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final AttemptReport report;

  @override
  Widget build(BuildContext context) {
    final blocked = report.blockedActions.isNotEmpty;
    final color = blocked ? AppTheme.error : AppTheme.success;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(
            blocked ? Icons.gpp_bad_outlined : Icons.verified_user_outlined,
            color: color),
        title: Text(report.fullName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${report.testTitle}\n${report.branchName} - Semester ${report.semester}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_duration(report.timeTakenSeconds),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text(report.status, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
        children: [
          _SummaryBox(text: report.aiSummary),
          const SizedBox(height: 12),
          _InfoWrap(rows: [
            _Info('Board roll no', report.boardRollNo ?? '-'),
            _Info('Roll no', report.rollNo ?? '-'),
            _Info('Mobile no', report.phone ?? '-'),
            _Info('Email', report.email ?? '-'),
            _Info('Course', report.courseName ?? '-'),
            _Info('College', report.collegeName ?? '-'),
            _Info('College ID', report.collegeId ?? '-'),
            _Info('Started', _date(report.startedAt)),
            _Info('Submitted', _date(report.completedAt)),
            _Info('Blocked actions', _blockedActions(report)),
          ]),
        ],
      ),
    );
  }

  static String _duration(int? seconds) {
    if (seconds == null) return '-';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  static String _date(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
  }

  static String _blockedActions(AttemptReport report) {
    if (report.blockedActions.isEmpty) return 'None';
    return report.blockedActions
        .map((event) => event.eventType.replaceAll('_', ' '))
        .toSet()
        .join(', ');
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35)),
    );
  }
}

class _InfoWrap extends StatelessWidget {
  const _InfoWrap({required this.rows});

  final List<_Info> rows;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rows
          .map((row) => SizedBox(
                width: MediaQuery.of(context).size.width >= 640
                    ? 190
                    : double.infinity,
                child: _InfoTile(row: row),
              ))
          .toList(),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.row});

  final _Info row;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(height: 3),
            Text(row.value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Info {
  const _Info(this.label, this.value);

  final String label;
  final String value;
}
