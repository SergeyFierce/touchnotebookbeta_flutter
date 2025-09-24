import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/reminder.dart';

class ReminderScheduler {
  ReminderScheduler._();

  static final ReminderScheduler instance = ReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'contact_reminders';
  static const String _channelName = 'Напоминания о контактах';
  static const String _channelDescription = 'Напоминания, связанные с контактами';

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    try {
      await _plugin.initialize(settings);
    } catch (e, stack) {
      debugPrint('ReminderScheduler initialization error: $e\n$stack');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<DarwinFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> scheduleReminder(Reminder reminder, {String? contactName}) async {
    if (kIsWeb) return;
    final id = reminder.id;
    if (id == null) return;

    await ensureInitialized();

    await _cancel(id);

    if (reminder.isCompleted) return;
    if (!reminder.remindAt.isAfter(DateTime.now())) return;

    final trimmedName = contactName?.trim();
    final title = (trimmedName != null && trimmedName.isNotEmpty)
        ? 'Напоминание: $trimmedName'
        : 'Напоминание о контакте';

    try {
      await _plugin.schedule(
        id,
        title,
        reminder.title,
        reminder.remindAt,
        _notificationDetails(),
        androidAllowWhileIdle: true,
      );
    } catch (e, stack) {
      debugPrint('Failed to schedule reminder#$id: $e\n$stack');
    }
  }

  Future<void> scheduleMany(Iterable<Reminder> reminders, {String? contactName}) async {
    for (final reminder in reminders) {
      await scheduleReminder(reminder, contactName: contactName);
    }
  }

  Future<void> cancelReminder(int id) async {
    if (kIsWeb) return;
    await ensureInitialized();
    await _cancel(id);
  }

  Future<void> cancelMany(Iterable<int> ids) async {
    if (kIsWeb) return;
    await ensureInitialized();
    for (final id in ids) {
      await _cancel(id);
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e, stack) {
      debugPrint('Failed to cancel reminder#$id: $e\n$stack');
    }
  }
}

