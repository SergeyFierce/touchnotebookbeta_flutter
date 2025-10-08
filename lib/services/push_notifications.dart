import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';              // NEW
import 'package:timezone/data/latest_all.dart' as tz;               // NEW
import 'package:timezone/timezone.dart' as tz;                      // NEW

import '../models/reminder.dart';
import 'contact_database.dart';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  await PushNotifications._handleNotificationResponse(response);
}
class PushNotifications {
  PushNotifications._();

  static FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _payloadTypeKey = 'type';
  static const String _payloadReminderType = 'reminder';
  static const String _payloadReminderIdKey = 'id';
  static const String _reminderSnoozeHourActionId = 'reminder_snooze_hour';
  static const String _reminderTomorrowActionId = 'reminder_tomorrow';

  static bool _initialized = false;
  static bool _tzReady = false;
  static bool _enabled = true;
  static Future<String> Function()? _timeZoneResolver;

  static void setEnabled(bool value) {
    _enabled = value;
  }

  static bool get isEnabled => _enabled;

  static const DarwinNotificationDetails _darwinDetails =
  DarwinNotificationDetails();

  static NotificationDetails _buildDetails({bool withReminderActions = false}) {
    final androidDetails = AndroidNotificationDetails(
      'demo_push_channel',
      'Демо уведомления',
      channelDescription: 'Канал для тестовых push-уведомлений',
      importance: Importance.max,
      priority: Priority.high,
      actions: withReminderActions
          ? const [
              AndroidNotificationAction(
                _reminderTomorrowActionId,
                'Напомнить завтра',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                _reminderSnoozeHourActionId,
                'Отложить на час',
                showsUserInterface: true,
              ),
            ]
          : null,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: _darwinDetails,
      macOS: _darwinDetails,
    );
  }

  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        unawaited(_handleNotificationResponse(response));
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Android 13+: запрос разрешения на показ уведомлений
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      // Android 14+: запрос разрешения на точные будильники,
      // если планируем EXACT (см. ниже androidScheduleMode)
      await androidImplementation.requestExactAlarmsPermission();
    }

    // iOS/macOS разрешения (дублируем на случай отсутствия выше)
    await _plugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  static Future<void> _ensureTimeZone() async {
    if (_tzReady) return;
    // Загружаем базу тайзон и выставляем локальную тайзону
    tz.initializeTimeZones();
    final name = _timeZoneResolver != null
        ? await _timeZoneResolver!.call()
        : await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
    _tzReady = true;
  }

  static String reminderPayload(int reminderId) => jsonEncode({
        _payloadTypeKey: _payloadReminderType,
        _payloadReminderIdKey: reminderId,
      });

  /// Немедленное уведомление (у вас уже было)
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_enabled) return;
    await ensureInitialized();
    try {
      await _plugin.show(id, title, body, _buildDetails());
    } catch (e, s) {
      if (kDebugMode) print('Failed to show notification: $e\n$s');
    }
  }

  @visibleForTesting
  static void resetForTests({FlutterLocalNotificationsPlugin? plugin}) {
    _plugin = plugin ?? FlutterLocalNotificationsPlugin();
    _initialized = false;
    _tzReady = false;
    _enabled = true;
    _timeZoneResolver = null;
  }

  @visibleForTesting
  static void debugOverrideTimezoneResolver(
    Future<String> Function() resolver,
  ) {
    _timeZoneResolver = resolver;
    _tzReady = false;
  }

  /// ОДИНОЧНОЕ напоминание на конкретную локальную дату/время
  static Future<void> scheduleOneTime({
    required int id,
    required DateTime whenLocal, // локальная дата/время
    required String title,
    required String body,
    bool exact = true, // для Android: точное ли срабатывание
    String? payload,
    bool withReminderActions = false,
  }) async {
    if (!_enabled) return;
    await ensureInitialized();
    await _ensureTimeZone();

    final scheduled = tz.TZDateTime.from(whenLocal, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _buildDetails(withReminderActions: withReminderActions),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime, // ⬅️ ДОБАВИТЬ
      payload: payload,
      // matchDateTimeComponents не указываем — одноразовое
    );
  }

  /// ЕЖЕДНЕВНОЕ напоминание на HH:mm
  static Future<void> scheduleDaily({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
    bool exact = false,
  }) async {
    if (!_enabled) return;
    await ensureInitialized();
    await _ensureTimeZone();

    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (first.isBefore(now)) {
      first = first.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      first,
      _buildDetails(),
      androidScheduleMode:
      exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime, // ⬅️ ДОБАВИТЬ
    );
  }

  /// ЕЖЕНЕДЕЛЬНОЕ напоминание на ДЕНЬ НЕДЕЛИ + HH:mm
  static Future<void> scheduleWeekly({
    required int id,
    required int weekday, // 1=Пн ... 7=Вс (как в DateTime.weekday)
    required TimeOfDay time,
    required String title,
    required String body,
    bool exact = false,
  }) async {
    if (!_enabled) return;
    await ensureInitialized();
    await _ensureTimeZone();

    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    // крутим до нужного дня недели в будущем
    while (first.weekday != weekday || !first.isAfter(now)) {
      first = first.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      first,
      _buildDetails(),
      androidScheduleMode:
      exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime, // ⬅️ ДОБАВИТЬ
    );

  }

  static Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final actionId = response.actionId;
    final payload = response.payload;

    if (actionId == null || actionId.isEmpty) return;
    if (payload == null || payload.isEmpty) return;

    try {
      WidgetsFlutterBinding.ensureInitialized();
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded[_payloadTypeKey] != _payloadReminderType) return;

      final rawId = decoded[_payloadReminderIdKey];
      final reminderId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      if (reminderId == null) return;

      switch (actionId) {
        case _reminderSnoozeHourActionId:
          await _rescheduleReminder(
            reminderId,
            (_) => DateTime.now().add(const Duration(hours: 1)),
          );
          break;
        case _reminderTomorrowActionId:
          await _rescheduleReminder(
            reminderId,
            (reminder) => reminder.remindAt.add(const Duration(days: 1)),
          );
          break;
        default:
          break;
      }
    } catch (e, s) {
      if (kDebugMode) {
        print('Failed to handle notification response: $e\n$s');
      }
    }
  }

  static Future<void> _rescheduleReminder(
    int reminderId,
    DateTime Function(Reminder reminder) computeNewTime,
  ) async {
    final reminder = await ContactDatabase.instance.reminderById(reminderId);
    if (reminder == null) return;

    final newWhen = _ensureFuture(computeNewTime(reminder));
    final updated = reminder.copyWith(remindAt: newWhen, completedAt: null);
    await ContactDatabase.instance.updateReminder(updated);

    final contact = await ContactDatabase.instance.contactById(reminder.contactId);
    final contactName = contact?.name ?? 'Контакт';

    await cancel(reminderId);
    await scheduleOneTime(
      id: reminderId,
      whenLocal: newWhen,
      title: 'Напоминание: ${contactName}',
      body: reminder.text,
      payload: reminderPayload(reminderId),
      withReminderActions: true,
    );
  }

  static DateTime _ensureFuture(DateTime candidate) {
    final now = DateTime.now();
    if (candidate.isAfter(now)) return candidate;
    return now.add(const Duration(minutes: 1));
  }

  static Future<void> cancel(int id) async {
    await ensureInitialized();
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await ensureInitialized();
    await _plugin.cancelAll();
  }

  static Future<List<PendingNotificationRequest>> pending() async {
    await ensureInitialized();
    return _plugin.pendingNotificationRequests();
  }
}
