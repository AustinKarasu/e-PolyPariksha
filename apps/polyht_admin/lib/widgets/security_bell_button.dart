import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../screens/security_log_screen.dart';
import '../services/test_service.dart';

class SecurityBellButton extends StatefulWidget {
  const SecurityBellButton({super.key});

  @override
  State<SecurityBellButton> createState() => _SecurityBellButtonState();
}

class _SecurityBellButtonState extends State<SecurityBellButton> {
  final _service = TestService();
  Timer? _pollTimer;
  int _alertCount = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchAlerts();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAlerts() async {
    if (!mounted || _loading) return;
    try {
      _loading = true;
      final events = await _service.fetchEvents(limit: 100);
      if (!mounted) return;

      final securityAlerts = events.where((e) {
        return e.eventType == 'unpinned_app' ||
            e.eventType == 'split_screen_attempt' ||
            e.eventType == 'picture_in_picture_attempt' ||
            e.eventType == 'window_focus_lost' ||
            e.eventType == 'home_navigation_attempt' ||
            e.severity == 'critical' ||
            e.severity == 'warning';
      }).toList();

      setState(() {
        _alertCount = securityAlerts.length;
      });
    } catch (_) {
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SecurityLogScreen()),
        );
        _fetchAlerts();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _alertCount > 0
                ? AppTheme.error.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.25),
            width: _alertCount > 0 ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _alertCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: _alertCount > 0 ? Colors.amberAccent : Colors.white,
                  size: 22,
                ),
                if (_alertCount > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        _alertCount > 99 ? '99+' : '$_alertCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              _alertCount > 0 ? '$_alertCount Alerts' : 'Security',
              style: TextStyle(
                color: _alertCount > 0 ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: _alertCount > 0 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
