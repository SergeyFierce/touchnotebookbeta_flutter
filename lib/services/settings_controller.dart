import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'localization_service.dart';

class SettingsController extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  Locale? locale;

  Future<void> initialize() async {
    final systemLocale = ui.PlatformDispatcher.instance.locale;
    if (LocalizationService.isSupported(systemLocale)) {
      locale = Locale(systemLocale.languageCode);
      return;
    }
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
