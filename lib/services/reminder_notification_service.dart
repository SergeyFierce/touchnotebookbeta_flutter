import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../app.dart';
import '../models/reminder.dart';
import '../screens/contact_details_screen.dart';
import 'contact_database.dart';

const _androidChannelId = 'contact_reminders';
const _androidChannelName = 'Напоминания по контактам';
const _androidChannelDescription = 'Локальные пуш-уведомления для напоминаний о контактах.';

@pragma('vm:entry-point')
void reminderNotificationTapBackground(NotificationResponse response) {}

class ReminderNotificationService {
  ReminderNotificationService._();
  static final ReminderNotificationService instance = ReminderNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  NotificationResponse? _pendingNavigationResponse;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Если не удалось определить локальную таймзону, используем системную по умолчанию.
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    final details = await _plugin.getNotificationAppLaunchDetails();

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: reminderNotificationTapBackground,
    );

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;

    if (details?.didNotificationLaunchApp ?? false) {
      _pendingNavigationResponse = details!.notificationResponse;
    }
  }

  Future<void> requestPermissionsIfNeeded() async {
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<DarwinFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    if (reminder.id == null) {
      throw ArgumentError('Reminder id is required to schedule a notification');
    }

    await _plugin.cancel(reminder.id!);

    final scheduled = tz.TZDateTime.from(reminder.scheduledTime, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      ticker: reminder.text,
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    final notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payload = jsonEncode({
      'contactId': reminder.contactId,
      'reminderId': reminder.id,
    });

    await _plugin.zonedSchedule(
      reminder.id!,
      'Напоминание по контакту',
      reminder.text,
      scheduled,
      notificationDetails,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelReminder(int reminderId) async {
    await _plugin.cancel(reminderId);
  }

  Future<void> cancelReminders(Iterable<int> reminderIds) async {
    for (final id in reminderIds) {
      await _plugin.cancel(id);
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> handleNotificationResponse(NotificationResponse response) async {
    if (response.payload == null || response.payload!.isEmpty) {
      return;
    }
    // Если навигатор ещё не готов (например, приложение только запускается),
    // откладываем обработку.
    if (App.navigatorKey.currentState == null) {
      _pendingNavigationResponse = response;
      return;
    }

    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    final contactId = data['contactId'] as int?;
    if (contactId == null) return;

    final contact = await ContactDatabase.instance.contactById(contactId);
    if (contact == null) return;

    // Уже открытый экран контакта перезапускаем, чтобы не копить стек.
    App.navigatorKey.currentState!
      ..popUntil((route) => route.isFirst)
      ..push(MaterialPageRoute(builder: (_) => ContactDetailsScreen(contact: contact)));
  }

  Future<void> processPendingNavigation() async {
    if (_pendingNavigationResponse == null) return;
    final response = _pendingNavigationResponse!;
    _pendingNavigationResponse = null;
    await handleNotificationResponse(response);
  }
}
