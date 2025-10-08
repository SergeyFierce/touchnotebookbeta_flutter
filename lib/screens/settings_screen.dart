import 'package:flutter/material.dart';

import 'about_app_screen.dart';
import 'notifications_settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'theme_settings_screen.dart';
import 'user_agreement_screen.dart';
import '../widgets/app_version_list_tile.dart';

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
            icon: Icons.notifications_active_outlined,
            destination: NotificationsSettingsScreen(),
          ),
          _SettingsCard(
            title: 'Тема',
            icon: Icons.brightness_6_outlined,
            destination: ThemeSettingsScreen(),
          ),
          _SettingsCard(
            title: 'Политика конфиденциальности',
            icon: Icons.privacy_tip_outlined,
            destination: PrivacyPolicyScreen(),
          ),
          _SettingsCard(
            title: 'Пользовательское соглашение',
            icon: Icons.receipt_long_outlined,
            destination: UserAgreementScreen(),
          ),
          _SettingsCard(
            title: 'О приложении',
            icon: Icons.info_outline,
            destination: AboutAppScreen(),
          ),
          SizedBox(height: 12),
          Card(
            child: AppVersionListTile(icon: Icons.tag_outlined),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.destination,
  });

  final String title;
  final IconData icon;
  final Widget destination;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => destination),
          );
        },
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
