import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/locale_notifier.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = context.watch<LocaleNotifier>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(title: Text(l10n.settingsLanguage)),
          RadioListTile<Locale>(
            title: Text(l10n.languageRussian),
            value: const Locale('ru'),
            groupValue: locale,
            onChanged: (value) {
              if (value != null) {
                context.read<LocaleNotifier>().setLocale(value);
              }
            },
          ),
          RadioListTile<Locale>(
            title: Text(l10n.languageEnglish),
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

