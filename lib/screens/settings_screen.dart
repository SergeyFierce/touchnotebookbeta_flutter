import 'package:flutter/material.dart';

import '../strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settingsTitle)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Приложение работает только на русском языке.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

