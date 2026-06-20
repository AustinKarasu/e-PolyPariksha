import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/student_test.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin
          .initialize(const InitializationSettings(android: android, iOS: ios));
      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
        try {
          await androidPlugin?.requestExactAlarmsPermission();
        } catch (_) {}
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> scheduleTests(List<StudentTest> tests) async {
    await init();
    if (!_ready) return;
    final prefs = await SharedPreferences.getInstance();
    final seen =
        prefs.getStringList('notified_test_ids')?.toSet() ?? <String>{};
    final now = DateTime.now();
    for (final test in tests) {
      try {
        if (test.status == 'ended') continue;
        final start = test.scheduledStart.toLocal();
        final end = test.scheduledEnd.toLocal();
        final scheduledKey =
            '${test.id}:scheduled:${start.millisecondsSinceEpoch}';
        final liveKey = '${test.id}:live:${start.millisecondsSinceEpoch}';
        final upcomingKey =
            '${test.id}:upcoming:${start.millisecondsSinceEpoch}';
        final alarmsKey =
            '${test.id}:alarms:${start.millisecondsSinceEpoch}:${end.millisecondsSinceEpoch}';
        if (test.status == 'upcoming' && !seen.contains(scheduledKey)) {
          await _showNow(
            id: _id(test.id, 4),
            title: 'House test scheduled',
            body: '${test.title} is scheduled for ${_time(start)}.',
          );
          seen.add(scheduledKey);
        }
        if (test.status == 'live' && !seen.contains(liveKey)) {
          await _showNow(
            id: _id(test.id, 2),
            title: 'House test started',
            body: '${test.title} is available now.',
          );
          seen.add(liveKey);
        }
        if (test.status == 'upcoming' &&
            !seen.contains(upcomingKey) &&
            start.difference(now) <= const Duration(minutes: 2)) {
          await _showNow(
            id: _id(test.id, 1),
            title: 'Upcoming house test',
            body: '${test.title} starts at ${_time(start)}.',
          );
          seen.add(upcomingKey);
        }
        if (!seen.contains(alarmsKey)) {
          await _cancelTest(test.id);
          await _schedule(
            id: _id(test.id, 1),
            when: _upcomingTime(start),
            title: 'Upcoming house test',
            body: '${test.title} starts at ${_time(start)}.',
          );
          await _schedule(
            id: _id(test.id, 2),
            when: start,
            title: 'House test started',
            body: '${test.title} is available now.',
          );
          await _schedule(
            id: _id(test.id, 3),
            when: end,
            title: 'House test ended',
            body: '${test.title} has ended. The PDF is now in history.',
          );
          seen.add(alarmsKey);
        }
      } catch (_) {}
    }
    await prefs.setStringList('notified_test_ids', seen.toList());
  }

  Future<void> _cancelTest(int testId) async {
    try {
      await _plugin.cancel(_id(testId, 1));
      await _plugin.cancel(_id(testId, 2));
      await _plugin.cancel(_id(testId, 3));
      await _plugin.cancel(_id(testId, 4));
    } catch (_) {}
  }

  Future<void> _schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    if (!when.isAfter(now.add(const Duration(seconds: 10)))) {
      await _showNow(id: id, title: title, body: body);
      return;
    }
    final scheduledTime = tz.TZDateTime.from(when.toLocal(), tz.local);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      _notificationDetails(),
    );
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'house_tests',
        'House tests',
        channelDescription: 'Upcoming, started, and ended house test alerts',
        category: AndroidNotificationCategory.alarm,
        importance: Importance.max,
        priority: Priority.max,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  DateTime _upcomingTime(DateTime start) {
    final reminder = start.subtract(const Duration(minutes: 15));
    final soon = DateTime.now().add(const Duration(seconds: 10));
    return reminder.isAfter(soon) ? reminder : soon;
  }

  int _id(int testId, int kind) => testId * 10 + kind;

  String _time(DateTime value) {
    final local = value.toLocal();
    final hour =
        local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
