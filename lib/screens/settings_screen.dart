import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/locale_notifier.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleNotifier>().locale;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          const ListTile(title: Text('Язык')),
          RadioListTile<Locale>(
            title: const Text('Русский'),
            value: const Locale('ru'),
            groupValue: locale,
            onChanged: (value) {
              if (value != null) {
                context.read<LocaleNotifier>().setLocale(value);
              }
            },
          ),
          RadioListTile<Locale>(
            title: const Text('English'),
            value: const Locale('en'),
            groupValue: locale,
            onChanged: (value) {
              if (value != null) {
                context.read<LocaleNotifier>().setLocale(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

