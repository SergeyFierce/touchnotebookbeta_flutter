import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';              // NEW
import 'package:timezone/data/latest_all.dart' as tz;               // NEW
import 'package:timezone/timezone.dart' as tz;                      // NEW
import 'package:flutter/material.dart' show TimeOfDay;
class PushNotifications {
  PushNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _tzReady = false;

  static const AndroidNotificationDetails _androidDetails =
  AndroidNotificationDetails(
    'demo_push_channel',
    'Демо уведомления',
    channelDescription: 'Канал для тестовых push-уведомлений',
    importance: Importance.max,
    priority: Priority.high,
  );

  static const DarwinNotificationDetails _darwinDetails =
  DarwinNotificationDetails();

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: _darwinDetails,
    macOS: _darwinDetails,
  );

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

    await _plugin.initialize(settings);

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
  }) async {
    await ensureInitialized();
    try {
      await _plugin.show(id, title, body, _details);
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
  }) async {
    await ensureInitialized();
    await _ensureTimeZone();

    final scheduled = tz.TZDateTime.from(whenLocal, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime, // ⬅️ ДОБАВИТЬ
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
      _details,
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
      _details,
      androidScheduleMode:
      exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime, // ⬅️ ДОБАВИТЬ
    );

  }

  static Future<void> cancel(int id) async {
    await ensureInitialized();
    try {
      await _plugin.cancel(id);
    } catch (e, s) {
      if (kDebugMode) print('Failed to cancel notification: $e\n$s');
    }
  }

  static Future<void> cancelAll() => _plugin.cancelAll();

  static Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();
}
