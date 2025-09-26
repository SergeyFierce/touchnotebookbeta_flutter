import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PushNotifications {
  PushNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _timeZoneInitialized = false;

  static Future<void> ensureInitialized() async {
    if (!_initialized) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final settings = const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _plugin.initialize(settings);

      // Android 13+ permission request
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      // iOS/macOS permission request
      final appleImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (appleImplementation != null) {
        await appleImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final macImplementation = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macImplementation != null) {
        await macImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _initialized = true;
    }

    if (!_timeZoneInitialized) {
      tz.initializeTimeZones();
      _timeZoneInitialized = true;
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await ensureInitialized();

    const androidDetails = AndroidNotificationDetails(
      'demo_push_channel',
      'Демо уведомления',
      channelDescription: 'Канал для тестовых push-уведомлений',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    final details = const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.show(id, title, body, details);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Failed to show notification: $error\n$stackTrace');
      }
    }
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await ensureInitialized();

    const androidDetails = AndroidNotificationDetails(
      'demo_push_channel',
      'Демо уведомления',
      channelDescription: 'Канал для тестовых push-уведомлений',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    final details = const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final scheduledUtc = scheduledDate.toUtc();
    final tzDateTime = tz.TZDateTime.from(scheduledUtc, tz.UTC);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Failed to schedule notification: $error\n$stackTrace');
      }
    }
  }
}
