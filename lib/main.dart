import 'package:flutter/material.dart';

import 'app.dart';
import 'services/contact_database.dart';
import 'services/reminder_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderNotifications.instance.init();
  await ContactDatabase.instance.reschedulePendingReminders();
  runApp(const App());
}

