import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Service to determine the start locale for the application.
class LocaleService {
  /// List of locales supported by the application.
  static const supportedLocales = [
    Locale('en'),
    Locale('zh'),
    Locale('es'),
    Locale('fr'),
    Locale('ar'),
    Locale('ru'),
    Locale('de'),
    Locale('pt'),
    Locale('hi'),
    Locale('ja'),
  ];

  /// Returns locale based on device settings and region.
  static Future<Locale> detectLocale() async {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    if (_isSupported(deviceLocale)) return deviceLocale;

    // Try to determine locale from region using IP API.
    try {
      final response = await http.get(Uri.parse('http://ip-api.com/json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final country = data['countryCode'] as String?;
        final locale = _localeFromCountry(country);
        if (locale != null) return locale;
      }
    } catch (_) {
      // ignore errors and fallback to English
    }

    return const Locale('en');
  }

  static bool _isSupported(Locale? locale) {
    if (locale == null) return false;
    return supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
  }

  static Locale? _localeFromCountry(String? code) {
    switch (code) {
      case 'CN':
      case 'TW':
      case 'SG':
        return const Locale('zh');
      case 'ES':
      case 'MX':
      case 'AR':
      case 'CO':
      case 'CL':
      case 'PE':
        return const Locale('es');
      case 'FR':
      case 'CA':
      case 'BE':
        return const Locale('fr');
      case 'SA':
      case 'AE':
      case 'EG':
      case 'DZ':
        return const Locale('ar');
      case 'RU':
      case 'BY':
      case 'KZ':
        return const Locale('ru');
      case 'DE':
      case 'AT':
      case 'CH':
        return const Locale('de');
      case 'PT':
      case 'BR':
        return const Locale('pt');
      case 'IN':
        return const Locale('hi');
      case 'JP':
        return const Locale('ja');
      default:
        return null;
    }
  }
}

