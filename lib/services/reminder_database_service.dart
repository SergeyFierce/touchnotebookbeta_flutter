import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';
import 'contact_database.dart';

class ReminderDatabaseService {
  ReminderDatabaseService._();
  static final ReminderDatabaseService instance = ReminderDatabaseService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  void _bumpRevision() => revision.value++;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'contact_reminders',
    'Напоминания контактов',
    channelDescription: 'Уведомления о напоминаниях для контактов',
    importance: Importance.max,
    priority: Priority.high,
  );

  static const DarwinNotificationDetails _darwinDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: _darwinDetails,
    macOS: _darwinDetails,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _notificationsPlugin.initialize(initializationSettings);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _rescheduleAllReminders();

    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<List<Reminder>> remindersByContact(int contactId) async {
    await _ensureInitialized();
    final db = await ContactDatabase.instance.database;
    final maps = await db.query(
      'reminders',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'scheduledDateTime ASC',
    );
    return maps.map(Reminder.fromMap).toList();
  }

  Future<Reminder> insertReminder(Reminder reminder) async {
    await _ensureInitialized();
    final db = await ContactDatabase.instance.database;
    final id = await db.insert(
      'reminders',
      _mapForInsert(reminder.toMap()),
    );
    final inserted = reminder.copyWith(id: id);
    await _scheduleReminder(inserted);
    _bumpRevision();
    return inserted;
  }

  Future<Reminder> updateReminder(Reminder reminder) async {
    if (reminder.id == null) {
      throw ArgumentError('Reminder id is required for update');
    }
    await _ensureInitialized();
    final db = await ContactDatabase.instance.database;
    await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
    await _notificationsPlugin.cancel(reminder.id!);
    await _scheduleReminder(reminder);
    _bumpRevision();
    return reminder;
  }

  Future<void> deleteReminder(int id) async {
    await _ensureInitialized();
    final db = await ContactDatabase.instance.database;
    await _notificationsPlugin.cancel(id);
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
    _bumpRevision();
  }

  Future<void> deleteRemindersForContact(int contactId) async {
    await _ensureInitialized();
    final db = await ContactDatabase.instance.database;
    final maps = await db.query(
      'reminders',
      where: 'contactId = ?',
      whereArgs: [contactId],
      columns: ['id'],
    );
    final ids = maps.map((m) => m['id'] as int).toList();
    for (final id in ids) {
      await _notificationsPlugin.cancel(id);
    }
    await db.delete('reminders', where: 'contactId = ?', whereArgs: [contactId]);
    if (ids.isNotEmpty) {
      _bumpRevision();
    }
  }

  Future<void> _rescheduleAllReminders() async {
    await _notificationsPlugin.cancelAll();
    final db = await ContactDatabase.instance.database;
    final maps = await db.query('reminders');
    final reminders = maps.map(Reminder.fromMap).toList();
    for (final reminder in reminders) {
      await _scheduleReminder(reminder);
    }
  }

  Future<void> _scheduleReminder(Reminder reminder) async {
    if (reminder.id == null) return;

    var scheduled = tz.TZDateTime.from(reminder.scheduledDateTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (!scheduled.isAfter(now)) {
      scheduled = now.add(const Duration(seconds: 1));
    }

    final contactName = await _contactName(reminder.contactId);
    final body = contactName == null ? null : 'Контакт: $contactName';

    await _notificationsPlugin.zonedSchedule(
      reminder.id!,
      reminder.title,
      body,
      scheduled,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: reminder.contactId.toString(),
    );
  }

  Map<String, Object?> _mapForInsert(Map<String, Object?> src) {
    final map = Map<String, Object?>.from(src);
    map.remove('id');
    return map;
  }

  Future<String?> _contactName(int contactId) async {
    final db = await ContactDatabase.instance.database;
    final result = await db.query(
      'contacts',
      where: 'id = ?',
      whereArgs: [contactId],
      limit: 1,
      columns: ['name'],
    );
    if (result.isEmpty) return null;
    return result.first['name'] as String?;
  }
}
