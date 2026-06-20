import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/exam_event.dart';
import '../services/test_service.dart';

class SecurityLogScreen extends StatefulWidget {
  const SecurityLogScreen({super.key});

  @override
  State<SecurityLogScreen> createState() => _SecurityLogScreenState();
}

class _SecurityLogScreenState extends State<SecurityLogScreen> {
  final _service = TestService();
  late Future<List<ExamEvent>> _events;

  @override
  void initState() {
    super.initState();
    _events = _service.fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Activity'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => setState(() => _events = _service.fetchEvents()),
        child: FutureBuilder<List<ExamEvent>>(
          future: _events,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary));
            }
            if (snapshot.hasError) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('Unable to load exam activity')),
              ]);
            }
            return _EventList(events: snapshot.data ?? []);
          },
        ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events});

  final List<ExamEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 120),
        Icon(Icons.history_rounded,
            size: 64, color: AppTheme.primaryLight.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text('No exam activity yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
      ]);
    }
    final format = DateFormat('dd MMM, hh:mm:ss a');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final event = events[index];
        final isCritical = event.severity == 'critical';
        final isWarning = event.severity == 'warning';
        final color = isCritical
            ? AppTheme.error
            : isWarning
                ? AppTheme.accent
                : AppTheme.primary;
        return Material(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: () => _showEventDetails(context, event),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    event.eventType == 'submit_completed'
                        ? Icons.assignment_turned_in_outlined
                        : isCritical
                            ? Icons.error_outline
                            : isWarning
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline,
                    size: 20,
                    color: color,
                  ),
                ),
                title: Text(
                  '${_labelFor(event.eventType)} - ${event.studentName}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${event.branchName} - ${event.testTitle}\n${event.studentEmail ?? 'Email not available'}\n${event.message ?? ''}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.65)),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: SizedBox(
                  width: 86,
                  child: Text(
                    format.format(event.createdAt),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.55)),
                  ),
                ),
                isThreeLine: true,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEventDetails(BuildContext context, ExamEvent event) {
    final format = DateFormat('dd MMM yyyy, hh:mm:ss a');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  _labelFor(event.eventType),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                _EventDetailRow('Student', event.studentName),
                _EventDetailRow(
                    'Email', event.studentEmail ?? 'Email not available'),
                _EventDetailRow(
                    'College ID', event.collegeId ?? 'Not available'),
                _EventDetailRow('Branch', event.branchName),
                _EventDetailRow('Test', event.testTitle),
                _EventDetailRow('Event type', event.eventType),
                _EventDetailRow('Severity', event.severity),
                _EventDetailRow('Time', format.format(event.createdAt)),
                _EventDetailRow(
                    'Description',
                    event.message?.trim().isNotEmpty == true
                        ? event.message!
                        : 'No additional description recorded.'),
              ],
            );
          },
        );
      },
    );
  }

  String _labelFor(String eventType) {
    switch (eventType) {
      case 'submit_completed':
        return 'Submitted';
      case 'pdf_opened':
        return 'PDF opened';
      case 'attempt_started':
        return 'Started';
      case 'pdf_requested':
        return 'PDF requested';
      default:
        return eventType.replaceAll('_', ' ');
    }
  }
}

class _EventDetailRow extends StatelessWidget {
  const _EventDetailRow(this.label, this.value);

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
