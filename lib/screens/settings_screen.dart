import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: const SafeArea(
        child: Center(
          child: Text('Страница в разработке'),
        ),
      ),
    );
  }
}

