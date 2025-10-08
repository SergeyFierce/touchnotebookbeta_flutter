import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:touchnotebookbeta_flutter/services/push_notifications.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class MockAndroidFlutterLocalNotificationsPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class MockIOSFlutterLocalNotificationsPlugin extends Mock
    implements IOSFlutterLocalNotificationsPlugin {}

class MockMacOSFlutterLocalNotificationsPlugin extends Mock
    implements MacOSFlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterLocalNotificationsPlugin plugin;
  late MockAndroidFlutterLocalNotificationsPlugin androidPlugin;
  late MockIOSFlutterLocalNotificationsPlugin iosPlugin;
  late MockMacOSFlutterLocalNotificationsPlugin macPlugin;

  setUpAll(() {
    tzdata.initializeTimeZones();
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
    );
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(tz.TZDateTime.now(tz.UTC));
  });

  setUp(() {
    plugin = MockFlutterLocalNotificationsPlugin();
    androidPlugin = MockAndroidFlutterLocalNotificationsPlugin();
    iosPlugin = MockIOSFlutterLocalNotificationsPlugin();
    macPlugin = MockMacOSFlutterLocalNotificationsPlugin();

    when(
      () => plugin.initialize(
        any(),
        onDidReceiveNotificationResponse:
            any(named: 'onDidReceiveNotificationResponse'),
        onDidReceiveBackgroundNotificationResponse:
            any(named: 'onDidReceiveBackgroundNotificationResponse'),
      ),
    ).thenAnswer((_) async => true);
    when(() => plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()).thenReturn(androidPlugin);
    when(() => plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()).thenReturn(iosPlugin);
    when(() => plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>()).thenReturn(macPlugin);
    when(() => androidPlugin.requestNotificationsPermission())
        .thenAnswer((_) async => true);
    when(() => androidPlugin.requestExactAlarmsPermission())
        .thenAnswer((_) async => true);
    when(
      () => iosPlugin.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => macPlugin.requestPermissions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => plugin.zonedSchedule(
        any(),
        any(),
        any(),
        any(),
        any(),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        uiLocalNotificationDateInterpretation:
            any(named: 'uiLocalNotificationDateInterpretation'),
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ),
    ).thenAnswer((_) async {});
    when(() => plugin.show(any(), any(), any(), any()))
        .thenAnswer((_) async => true);

    PushNotifications.resetForTests(plugin: plugin);
    PushNotifications.debugOverrideTimezoneResolver(() async => 'UTC');
  });

  tearDown(() {
    PushNotifications.resetForTests();
  });

  test('scheduleOneTime schedules notification when enabled', () async {
    await PushNotifications.scheduleOneTime(
      id: 1,
      whenLocal: DateTime.now().add(const Duration(hours: 1)),
      title: 'Заголовок',
      body: 'Тело',
    );

    verify(
      () => plugin.zonedSchedule(
        1,
        'Заголовок',
        'Тело',
        any(),
        any(),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        uiLocalNotificationDateInterpretation:
            any(named: 'uiLocalNotificationDateInterpretation'),
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ),
    ).called(1);
  });

  test('scheduleOneTime does nothing when disabled', () async {
    PushNotifications.setEnabled(false);

    await PushNotifications.scheduleOneTime(
      id: 2,
      whenLocal: DateTime.now().add(const Duration(hours: 1)),
      title: 'Заголовок',
      body: 'Тело',
    );

    verifyNever(
      () => plugin.zonedSchedule(
        any(),
        any(),
        any(),
        any(),
        any(),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        uiLocalNotificationDateInterpretation:
            any(named: 'uiLocalNotificationDateInterpretation'),
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ),
    );
  });

  test('showNotification forwards to plugin when enabled', () async {
    await PushNotifications.showNotification(
      id: 7,
      title: 'Привет',
      body: 'Мир',
    );

    verify(() => plugin.show(7, 'Привет', 'Мир', any())).called(1);
  });
}
