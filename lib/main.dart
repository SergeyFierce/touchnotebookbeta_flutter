import 'package:flutter/material.dart';

import 'app.dart';
import 'services/reminder_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderScheduler.instance.ensureInitialized();
  runApp(const App());
}

