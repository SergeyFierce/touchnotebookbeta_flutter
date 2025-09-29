import 'package:flutter/material.dart';

import 'notifications_settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'theme_settings_screen.dart';
import 'user_agreement_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SettingsCard(
            title: 'Уведомления',
            description: 'Управление настройками уведомлений приложения.',
            destination: NotificationsSettingsScreen(),
          ),
          _SettingsCard(
            title: 'Тема',
            description: 'Выбор светлой или тёмной темы интерфейса.',
            destination: ThemeSettingsScreen(),
          ),
          _SettingsCard(
            title: 'Политика конфиденциальности',
            description: 'Ознакомьтесь с политикой обработки данных.',
            destination: PrivacyPolicyScreen(),
          ),
          _SettingsCard(
            title: 'Пользовательское соглашение',
            description: 'Основные разделы пользовательского соглашения.',
            destination: UserAgreementScreen(),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.description,
    required this.destination,
  });

  final String title;
  final String description;
  final Widget destination;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => destination),
          );
        },
      ),
    );
  }
}
