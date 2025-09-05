import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocalizationService {
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
    final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    final code = placemarks.first.isoCountryCode?.toLowerCase() ?? 'en';
    switch (code) {
      case 'ru':
        return const Locale('ru');
      default:
        return const Locale('en');
    }
  }
}
