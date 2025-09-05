import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocalizationService {
  // Supported languages mapped to display names
  static const Map<String, String> languageNames = {
    'en': 'Английский',
    'zh': 'Китайский (мандаринский)',
    'es': 'Испанский',
    'fr': 'Французский',
    'ar': 'Арабский',
    'ru': 'Русский',
    'de': 'Немецкий',
    'pt': 'Португальский',
    'hi': 'Хинди',
    'ja': 'Японский',
  };

  static final List<Locale> supportedLocales =
      languageNames.keys.map((code) => Locale(code)).toList();

  static bool isSupported(Locale locale) =>
      languageNames.containsKey(locale.languageCode);

  static const Map<String, String> _countryToLanguage = {
    'us': 'en',
    'gb': 'en',
    'au': 'en',
    'ca': 'en',
    'cn': 'zh',
    'ru': 'ru',
    'es': 'es',
    'mx': 'es',
    'ar': 'es',
    'fr': 'fr',
    'de': 'de',
    'at': 'de',
    'sa': 'ar',
    'ae': 'ar',
    'eg': 'ar',
    'br': 'pt',
    'pt': 'pt',
    'in': 'hi',
    'jp': 'ja',
  };

  static Future<Locale> getLocaleFromLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location disabled');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permission denied forever');
    }
    final position = await Geolocator.getCurrentPosition();
    final placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    final countryCode = placemarks.first.isoCountryCode?.toLowerCase();
    final langCode =
        countryCode != null ? _countryToLanguage[countryCode] : null;
    return Locale(langCode ?? 'en');
  }
}

