import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/admin_analytics.dart';
import '../services/admin_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _service = AdminService();
  late Future<AdminAnalytics> _analytics;

  @override
  void initState() {
    super.initState();
    _analytics = _service.fetchAnalytics();
  }

  Future<void> _refresh() async {
    setState(() => _analytics = _service.fetchAnalytics());
    await _analytics;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _refresh,
        child: FutureBuilder<AdminAnalytics>(
          future: _analytics,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 96),
                  const Icon(Icons.analytics_outlined,
                      size: 60, color: AppTheme.primaryLight),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to load analytics',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              );
            }
            return _AnalyticsBody(analytics: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.analytics});

  final AdminAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final reports = analytics.recentReports;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 3 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 3 ? 1.7 : 1.25,
              children: [
                _MetricTile(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'Tests Conducted Today',
                  value: analytics.testsConductedToday,
                  color: AppTheme.primary,
                ),
                _MetricTile(
                  icon: Icons.fact_check_outlined,
                  label: 'User Attempts',
                  value: analytics.userAttemptsToday,
                  color: AppTheme.success,
                ),
                _MetricTile(
                  icon: Icons.people_outline_rounded,
                  label: 'Total Users',
                  value: analytics.totalUsers,
                  color: AppTheme.accent,
                ),
                _MetricTile(
                  icon: Icons.error_outline_rounded,
                  label: 'App Errors',
                  value: analytics.appErrorsToday,
                  color: AppTheme.error,
                ),
                _MetricTile(
                  icon: Icons.bug_report_outlined,
                  label: 'Crash Reports',
                  value: analytics.crashReportsToday,
                  color: AppTheme.error,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Recent app errors and crashes',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (reports.isEmpty)
          const _EmptyReports()
        else
          ...reports.map((report) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReportTile(report: report),
              )),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(
            '$value',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final AppErrorReport report;

  @override
  Widget build(BuildContext context) {
    final isCrash = report.severity == 'crash';
    final color = isCrash ? AppTheme.error : AppTheme.accent;
    final format = DateFormat('dd MMM yyyy, hh:mm a');
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => _showReportDetails(context, report),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCrash ? Icons.bug_report_outlined : Icons.error_outline,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${report.email ?? 'Unknown user'} - ${report.page ?? 'Unknown page'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
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
              const SizedBox(width: 8),
              Text(
                format.format(report.createdAt),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDetails(BuildContext context, AppErrorReport report) {
    final format = DateFormat('dd MMM yyyy, hh:mm:ss a');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  report.severity == 'crash'
                      ? 'Crash report'
                      : 'App error report',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                _DetailRow('Error', report.message),
                _DetailRow('Page', report.page ?? 'Not recorded'),
                _DetailRow('Device',
                    '${report.deviceModel ?? 'Unknown model'} (${report.devicePlatform ?? 'Unknown platform'})'),
                _DetailRow('App version',
                    '${report.appVersion ?? '-'} build ${report.appBuild ?? '-'}'),
                _DetailRow('Time', format.format(report.createdAt)),
                _DetailRow('Name', report.fullName ?? 'Unknown'),
                _DetailRow('Email', report.email ?? 'Unknown'),
                _DetailRow('College', report.collegeName ?? 'Unknown'),
                _DetailRow('Phone', report.phone ?? 'Unknown'),
                _DetailRow('Branch', report.branchName ?? 'Not applicable'),
                if (report.stackTrace?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Technical details',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    report.stackTrace!,
                    style: const TextStyle(fontSize: 11, height: 1.35),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: const Column(
        children: [
          Icon(Icons.verified_outlined, size: 40, color: AppTheme.success),
          SizedBox(height: 10),
          Text('No app errors or crash reports recorded today.'),
        ],
      ),
    );
  }
}
