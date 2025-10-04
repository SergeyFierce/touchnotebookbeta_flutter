import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';              // NEW
import 'package:timezone/data/latest_all.dart' as tz;               // NEW
import 'package:timezone/timezone.dart' as tz;                      // NEW
import 'package:flutter/material.dart' show TimeOfDay;

import '../models/reminder.dart';
import 'contact_database.dart';
class PushNotifications {
  PushNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _tzReady = false;
  static bool _enabled = true;

  static const _reminderPayloadPrefix = 'reminder:';
  static const _reminderCategoryId = 'reminder_actions';
  static const _snoozeActionId = 'reminder_snooze_1h';
  static const _tomorrowActionId = 'reminder_tomorrow';

  static final List<AndroidNotificationAction> _reminderAndroidActions =
      <AndroidNotificationAction>[
    AndroidNotificationAction(
      _snoozeActionId,
      'Отложить на час',
      showsUserInterface: true,
    ),
    AndroidNotificationAction(
      _tomorrowActionId,
      'Напомнить завтра',
      showsUserInterface: true,
    ),
  ];

  static final DarwinNotificationCategory _darwinReminderCategory =
      DarwinNotificationCategory(
    _reminderCategoryId,
    actions: <DarwinNotificationAction>[
      DarwinNotificationAction.plain(
        identifier: _snoozeActionId,
        title: 'Отложить на час',
        options: <DarwinNotificationActionOption>{
          DarwinNotificationActionOption.foreground,
        },
      ),
      DarwinNotificationAction.plain(
        identifier: _tomorrowActionId,
        title: 'Напомнить завтра',
        options: <DarwinNotificationActionOption>{
          DarwinNotificationActionOption.foreground,
        },
      ),
    ],
  );

  static NotificationDetails _notificationDetails({
    bool includeReminderActions = false,
  }) {
    final android = AndroidNotificationDetails(
      'demo_push_channel',
      'Демо уведомления',
      channelDescription: 'Канал для тестовых push-уведомлений',
      importance: Importance.max,
      priority: Priority.high,
      actions: includeReminderActions ? _reminderAndroidActions : null,
    );

    final darwin = DarwinNotificationDetails(
      categoryIdentifier:
          includeReminderActions ? _reminderCategoryId : null,
    );

    return NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  static void setEnabled(bool value) {
    _enabled = value;
  }

  static bool get isEnabled => _enabled;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: {_darwinReminderCategory},
    );

    final settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
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
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
    _tzReady = true;
  }

  /// Немедленное уведомление (у вас уже было)
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_enabled) return;
    await ensureInitialized();
    try {
      await _plugin.show(
        id,
        title,
        body,
        _notificationDetails(),
        payload: payload,
      );
    } catch (e, s) {
      if (kDebugMode) print('Failed to show notification: $e\n$s');
    }
  }

  /// ОДИНОЧНОЕ напоминание на конкретную локальную дату/время
  static Future<void> scheduleOneTime({
    required int id,
    required DateTime whenLocal, // локальная дата/время
    required String title,
    required String body,
    bool exact = true, // для Android: точное ли срабатывание
    String? payload,
    bool reminderActions = false,
  }) async {
    if (!_enabled) return;
    await ensureInitialized();
    await _ensureTimeZone();

    final scheduled = tz.TZDateTime.from(whenLocal, tz.local);
    final details =
        _notificationDetails(includeReminderActions: reminderActions);
    final effectivePayload = reminderActions
        ? (payload ?? '$_reminderPayloadPrefix$id')
        : payload;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime, // ⬅️ ДОБАВИТЬ
      // matchDateTimeComponents не указываем — одноразовое
      payload: effectivePayload,
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
      _notificationDetails(),
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
      _notificationDetails(),
      androidScheduleMode:
      exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime, // ⬅️ ДОБАВИТЬ
    );

  }

  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    await handleNotificationResponse(response);
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    if (payload == null || !payload.startsWith(_reminderPayloadPrefix)) {
      return;
    }

    if (response.notificationResponseType !=
        NotificationResponseType.selectedNotificationAction) {
      return;
    }

    final actionId = response.actionId;
    if (actionId == null) return;

    final reminderId =
        int.tryParse(payload.substring(_reminderPayloadPrefix.length));
    if (reminderId == null) return;

    await _handleReminderAction(reminderId, actionId, response);
  }

  static Future<void> _handleReminderAction(
    int reminderId,
    String actionId,
    NotificationResponse response,
  ) async {
    if (actionId != _snoozeActionId && actionId != _tomorrowActionId) {
      return;
    }

    final reminder = await ContactDatabase.instance.reminderById(reminderId);
    if (reminder == null) return;

    final now = DateTime.now();
    late final DateTime newRemindAt;

    if (actionId == _snoozeActionId) {
      final base = reminder.remindAt.isAfter(now) ? reminder.remindAt : now;
      newRemindAt = base.add(const Duration(hours: 1));
    } else {
      final original = reminder.remindAt;
      final tomorrow = now.add(const Duration(days: 1));
      newRemindAt = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        original.hour,
        original.minute,
        original.second,
        original.millisecond,
        original.microsecond,
      );

      if (!newRemindAt.isAfter(now)) {
        newRemindAt = now.add(const Duration(days: 1));
      }
    }

    final updated = reminder.copyWith(
      remindAt: newRemindAt,
      completedAt: null,
    );

    await ContactDatabase.instance.updateReminder(updated);

    final title = response.notification?.title ?? 'Напоминание';
    await scheduleOneTime(
      id: reminderId,
      whenLocal: newRemindAt,
      title: title,
      body: reminder.text,
      payload: response.payload,
      reminderActions: true,
    );
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
