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
  bool _onlyBreaches = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    setState(() {
      _events = _service.fetchEvents(limit: 150);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Alerts & Logs'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh logs',
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Chips ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                FilterChip(
                  selected: !_onlyBreaches,
                  label: const Text('All Logs'),
                  onSelected: (val) {
                    if (val) setState(() => _onlyBreaches = false);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _onlyBreaches,
                  selectedColor: AppTheme.error.withValues(alpha: 0.2),
                  avatar: const Icon(Icons.security_rounded, size: 16, color: AppTheme.error),
                  label: const Text(
                    'Security Breaches Only',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onSelected: (val) {
                    setState(() => _onlyBreaches = val);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Events List ──
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async => _loadEvents(),
              child: FutureBuilder<List<ExamEvent>>(
                future: _events,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                                const SizedBox(height: 12),
                                Text(
                                  'Unable to load activity logs: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadEvents,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  final allEvents = snapshot.data ?? [];
                  final displayEvents = _onlyBreaches
                      ? allEvents.where((e) {
                          return e.eventType == 'unpinned_app' ||
                              e.eventType == 'split_screen_attempt' ||
                              e.eventType == 'picture_in_picture_attempt' ||
                              e.eventType == 'window_focus_lost' ||
                              e.eventType == 'home_navigation_attempt' ||
                              e.eventType == 'back_navigation_attempt' ||
                              e.severity == 'critical' ||
                              e.severity == 'warning';
                        }).toList()
                      : allEvents;

                  return _EventList(
                    events: displayEvents,
                    onRefreshNeeded: _loadEvents,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events, required this.onRefreshNeeded});

  final List<ExamEvent> events;
  final VoidCallback onRefreshNeeded;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.shield_outlined,
              size: 64, color: AppTheme.primaryLight.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No security incidents recorded',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Activity logs and breach alerts will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.ink.withValues(alpha: 0.5))),
        ],
      );
    }
    final format = DateFormat('dd MMM, hh:mm:ss a');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final event = events[index];
        final isCritical = event.severity == 'critical' || event.eventType == 'unpinned_app';
        final isWarning = event.severity == 'warning' ||
            event.eventType == 'split_screen_attempt' ||
            event.eventType == 'window_focus_lost' ||
            event.eventType == 'home_navigation_attempt';
        final color = isCritical
            ? AppTheme.error
            : isWarning
                ? Colors.orange.shade800
                : AppTheme.primary;

        final violationTitle = _violationTitle(event.eventType);

        return Material(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          elevation: isCritical ? 2 : 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: () => _showEventDetails(context, event),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: color.withValues(alpha: isCritical ? 0.6 : 0.25),
                  width: isCritical ? 1.8 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top: Violation Badge + Time ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCritical
                                  ? Icons.gpp_bad_rounded
                                  : isWarning
                                      ? Icons.warning_rounded
                                      : Icons.info_outline_rounded,
                              size: 15,
                              color: color,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              violationTitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        format.format(event.createdAt),
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
                  const SizedBox(height: 10),

                  // ── Student Name ──
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.studentName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Academic Info: Branch | Semester | Roll No ──
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _infoChip(Icons.account_tree_outlined, event.branchName),
                      if (event.semester != null)
                        _infoChip(Icons.school_outlined, 'Sem ${event.semester}'),
                      if (event.rollNo != null && event.rollNo!.isNotEmpty)
                        _infoChip(Icons.badge_outlined, 'Roll: ${event.rollNo}'),
                      if (event.boardRollNo != null && event.boardRollNo!.isNotEmpty)
                        _infoChip(Icons.confirmation_number_outlined, 'Board: ${event.boardRollNo}'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Test Title & Message ──
                  Text(
                    'Test: ${event.testTitle}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.message != null && event.message!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.message!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isCritical
                            ? AppTheme.error
                            : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.ink.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.ink.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
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
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Row(
                  children: [
                    Icon(
                      event.severity == 'critical'
                          ? Icons.gpp_bad_rounded
                          : Icons.warning_rounded,
                      color: event.severity == 'critical' ? AppTheme.error : Colors.orange.shade800,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _violationTitle(event.eventType),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _EventDetailRow('Student Name', event.studentName),
                _EventDetailRow('Branch', event.branchName),
                _EventDetailRow('Semester', event.semester != null ? 'Semester ${event.semester}' : 'N/A'),
                _EventDetailRow('Class Roll Number', event.rollNo ?? 'N/A'),
                _EventDetailRow('Board Roll Number', event.boardRollNo ?? event.collegeId ?? 'N/A'),
                _EventDetailRow('Student Email', event.studentEmail ?? 'N/A'),
                _EventDetailRow('Test Paper', event.testTitle),
                _EventDetailRow('Security Violation', _violationTitle(event.eventType)),
                _EventDetailRow('Severity Level', event.severity.toUpperCase()),
                _EventDetailRow('Incident Time', format.format(event.createdAt)),
                _EventDetailRow(
                  'Event Details / Description',
                  event.message?.trim().isNotEmpty == true
                      ? event.message!
                      : 'No additional description recorded.',
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _violationTitle(String eventType) {
    switch (eventType) {
      case 'unpinned_app':
        return 'Unpinned Exam App (Exited Pinned Mode)';
      case 'split_screen_attempt':
        return 'Split-Screen Mode Attempt';
      case 'picture_in_picture_attempt':
        return 'Picture-In-Picture Attempt';
      case 'window_focus_lost':
        return 'Window Focus Lost (App Switched)';
      case 'home_navigation_attempt':
        return 'Home Button Navigation Attempt';
      case 'back_navigation_attempt':
        return 'Back Button Pressed';
      case 'app_inactive':
        return 'App Became Inactive';
      case 'app_detached':
        return 'App Terminated / Detached';
      case 'submit_completed':
        return 'Test Submitted Successfully';
      case 'attempt_started':
        return 'Test Started';
      case 'pdf_opened':
        return 'Question Paper Opened';
      default:
        return eventType.replaceAll('_', ' ').toUpperCase();
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
      padding: const EdgeInsets.only(bottom: 12),
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
          SelectableText(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
