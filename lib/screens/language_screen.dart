import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/locale_service.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final names = {
      'en': 'English',
      'zh': '中文',
      'es': 'Español',
      'fr': 'Français',
      'ar': 'العربية',
      'ru': 'Русский',
      'de': 'Deutsch',
      'pt': 'Português',
      'hi': 'हिन्दी',
      'ja': '日本語',
    };

    return Scaffold(
      appBar: AppBar(title: Text('language'.tr())),
      body: ListView(
        children: LocaleService.supportedLocales.map((locale) {
          final code = locale.languageCode;
          final selected = context.locale.languageCode == code;
          return ListTile(
            title: Text(names[code] ?? code),
            trailing: selected ? const Icon(Icons.check) : null,
            onTap: () {
              context.setLocale(locale);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}

