import 'package:flutter/material.dart';
import 'localization_service.dart';

class SettingsController extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  Locale? locale;

  Future<void> initialize() async {
    try {
      locale = await LocalizationService.getLocaleFromLocation();
    } catch (_) {
      locale = null; // user will select manually
    }
  }

  bool get isLocaleSet => locale != null;

  void updateThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void updateLocale(Locale newLocale) {
    locale = newLocale;
    notifyListeners();
  }
}

final settingsController = SettingsController();
