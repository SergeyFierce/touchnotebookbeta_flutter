import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ChangeNotifier] that stores the selected [Locale] in [SharedPreferences].
class LocaleNotifier extends ChangeNotifier {
  static const _storageKey = 'localeCode';

  Locale _locale = const Locale('ru');

  /// Current locale of the application.
  Locale get locale => _locale;

  /// Loads the saved locale from [SharedPreferences].
  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_storageKey);
    if (code != null) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  /// Updates the locale and persists it in [SharedPreferences].
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, locale.languageCode);
  }
}

