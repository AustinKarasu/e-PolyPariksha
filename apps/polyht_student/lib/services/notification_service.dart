import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/student_test.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    _ready = true;
  }

  Future<void> scheduleTests(List<StudentTest> tests) async {
    await init();
    for (final test in tests) {
      await _cancelTest(test.id);
      if (test.status == 'ended') continue;
      await _schedule(
        id: _id(test.id, 1),
        when: _upcomingTime(test.scheduledStart),
        title: 'Upcoming house test',
        body: '${test.title} starts at ${_time(test.scheduledStart)}.',
      );
      await _schedule(
        id: _id(test.id, 2),
        when: test.scheduledStart,
        title: 'House test started',
        body: '${test.title} is available now.',
      );
      await _schedule(
        id: _id(test.id, 3),
        when: test.scheduledEnd,
        title: 'House test ended',
        body: '${test.title} has ended. The PDF is now in history.',
      );
    }
  }

  Future<void> _cancelTest(int testId) async {
    await _plugin.cancel(_id(testId, 1));
    await _plugin.cancel(_id(testId, 2));
    await _plugin.cancel(_id(testId, 3));
  }

  Future<void> _schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    if (!when.isAfter(now.add(const Duration(seconds: 5)))) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'house_tests',
          'House tests',
          channelDescription: 'Upcoming, started, and ended house test alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  DateTime _upcomingTime(DateTime start) {
    final reminder = start.subtract(const Duration(minutes: 15));
    final soon = DateTime.now().add(const Duration(minutes: 1));
    return reminder.isAfter(soon) ? reminder : soon;
  }

  int _id(int testId, int kind) => testId * 10 + kind;

  String _time(DateTime value) {
    final hour = value.hour > 12 ? value.hour - 12 : (value.hour == 0 ? 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
