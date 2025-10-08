import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  static const _shareMessage =
      'Попробуй приложение Touch NoteBook от Topskiy Vision Works!';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Touch NoteBook',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Разработчик: Topskiy Vision Works',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Touch NoteBook помогает управлять контактами, '
                    'заметками и напоминаниями в едином приложении.',
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Поделиться приложением'),
              onTap: () {
                Share.share(_shareMessage);
              },
            ),
          ),
        ],
      ),
    );
  }
}
