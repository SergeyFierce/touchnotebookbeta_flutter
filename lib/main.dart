import 'package:flutter/material.dart';

import 'app.dart';
import 'services/app_settings.dart';
import 'services/push_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  await PushNotifications.ensureInitialized();
  runApp(App(settings: settings));
}

