import 'package:flutter/material.dart';

import 'app.dart';
import 'services/push_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotifications.ensureInitialized();
  runApp(const App());
}

