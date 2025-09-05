import 'package:flutter/material.dart';

import 'app.dart';
import 'services/settings_controller.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await settingsController.initialize();
  runApp(const App());

  if (!settingsController.isLocaleSet) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      App.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    });
  }
}

