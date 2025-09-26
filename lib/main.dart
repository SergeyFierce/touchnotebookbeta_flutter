import 'package:flutter/material.dart';

import 'app.dart';
import 'services/reminder_notification_service.dart';
import 'services/reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderNotificationService.instance.initialize();
  await ReminderNotificationService.instance.requestPermissionsIfNeeded();
  await ReminderService.instance.rescheduleAllUpcoming();
  runApp(const App());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ReminderNotificationService.instance.processPendingNavigation();
  });
}

