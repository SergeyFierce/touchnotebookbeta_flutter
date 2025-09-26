import 'package:flutter/material.dart';

import 'app.dart';
import 'services/reminder_database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderDatabaseService.instance.initialize();
  runApp(const App());
}

