import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/locale_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final startLocale = await LocaleService.detectLocale();
  runApp(
    EasyLocalization(
      supportedLocales: LocaleService.supportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: startLocale,
      child: const App(),
    ),
  );
}

