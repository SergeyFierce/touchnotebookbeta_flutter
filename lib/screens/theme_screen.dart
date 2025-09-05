import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final current = app?.themeMode ?? ThemeMode.system;

    return Scaffold(
      appBar: AppBar(title: Text('theme'.tr())),
      body: ListView(
        children: [
          ListTile(
            title: Text('light'.tr()),
            trailing:
                current == ThemeMode.light ? const Icon(Icons.check) : null,
            onTap: () {
              app?.setThemeMode(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('dark'.tr()),
            trailing:
                current == ThemeMode.dark ? const Icon(Icons.check) : null,
            onTap: () {
              app?.setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('system'.tr()),
            trailing:
                current == ThemeMode.system ? const Icon(Icons.check) : null,
            onTap: () {
              app?.setThemeMode(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

