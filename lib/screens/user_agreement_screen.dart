import 'package:flutter/material.dart';

class UserAgreementScreen extends StatelessWidget {
  const UserAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пользовательское соглашение')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionPlaceholder(title: '1. Предмет соглашения'),
          _SectionPlaceholder(title: '2. Права и обязанности сторон'),
          _SectionPlaceholder(title: '3. Ограничения и ответственность'),
          _SectionPlaceholder(title: '4. Заключительные положения'),
        ],
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: const Text('Содержимое раздела будет добавлено позже.'),
      ),
    );
  }
}
