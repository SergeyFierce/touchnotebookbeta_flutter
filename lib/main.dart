import 'package:flutter/material.dart';

import 'app.dart';
import 'services/locale_notifier.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeNotifier = LocaleNotifier();
  await localeNotifier.loadLocale();
  runApp(
    ChangeNotifierProvider<LocaleNotifier>.value(
      value: localeNotifier,
      child: const App(),
    ),
  );
}

