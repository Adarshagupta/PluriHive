import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class SmartReminderService {
  static const int _reminderId = 90321;
  static const String _channelId = 'smart_reminders';
  static const String _channelName = 'Smart Reminders';
  static const String _channelDescription =
      'Daily activity reminders based on your routine';

  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  SmartReminderService({FlutterLocalNotificationsPlugin? notifications})
      : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(initSettings);
    _initialized = true;
  }

  TimeOfDay computeTypicalTime(
    List<DateTime> times, {
    TimeOfDay fallback = const TimeOfDay(hour: 19, minute: 0),
  }) {
    if (times.isEmpty) return fallback;
    double sumSin = 0;
    double sumCos = 0;
    for (final time in times) {
      final minutes = time.hour * 60 + time.minute;
      final angle = 2 * math.pi * (minutes / 1440);
      sumSin += math.sin(angle);
      sumCos += math.cos(angle);
    }
    final meanAngle = math.atan2(sumSin / times.length, sumCos / times.length);
    final normalized = meanAngle < 0 ? meanAngle + 2 * math.pi : meanAngle;
    final meanMinutes = ((normalized * 1440) / (2 * math.pi)).round() % 1440;
    return TimeOfDay(hour: meanMinutes ~/ 60, minute: meanMinutes % 60);
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay? parseTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> scheduleDaily(
    TimeOfDay time, {
    String? title,
    String? body,
  }) async {
    await initialize();
    final scheduled = _nextInstanceOf(time);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _notifications.zonedSchedule(
      _reminderId,
      title ?? 'Time to move',
      body ?? 'Your usual time is now. Capture more territory.',
      scheduled,
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    await initialize();
    await _notifications.cancel(_reminderId);
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
