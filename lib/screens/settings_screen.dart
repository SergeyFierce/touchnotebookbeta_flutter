import 'package:flutter/material.dart';
import '../services/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Настройки')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Тема'),
                DropdownButton<ThemeMode>(
                  value: settingsController.themeMode,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Как в системе'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Светлая'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Тёмная'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      settingsController.updateThemeMode(mode);
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Text('Страна'),
                DropdownButton<Locale>(
                  value: settingsController.locale,
                  hint: const Text('Выберите страну'),
                  items: const [
                    DropdownMenuItem(
                      value: Locale('ru'),
                      child: Text('Россия'),
                    ),
                    DropdownMenuItem(
                      value: Locale('en'),
                      child: Text('США'),
                    ),
                  ],
                  onChanged: (loc) {
                    if (loc != null) {
                      settingsController.updateLocale(loc);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

