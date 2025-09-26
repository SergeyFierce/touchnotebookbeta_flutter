import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

class ReminderNotifications {
  ReminderNotifications._();

  static final ReminderNotifications instance = ReminderNotifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _initialized = true;
  }

  Future<void> scheduleReminder(Reminder reminder, {required String contactName}) async {
    await init();
    if (reminder.id == null) return;

    final now = DateTime.now();
    if (reminder.scheduledAt.isBefore(now.subtract(const Duration(minutes: 1)))) {
      await cancelReminder(reminder.id!);
      return;
    }

    final scheduleDate = tz.TZDateTime.from(reminder.scheduledAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'contact_reminders',
      'Напоминания по контактам',
      channelDescription: 'Локальные напоминания для контактов',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      reminder.id!,
      contactName,
      reminder.text,
      scheduleDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: reminder.contactId.toString(),
    );
  }

  Future<void> cancelReminder(int reminderId) async {
    await init();
    await _plugin.cancel(reminderId);
  }

  Future<void> cancelReminders(Iterable<int> reminderIds) async {
    await init();
    for (final id in reminderIds) {
      await _plugin.cancel(id);
    }
  }
}
