import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Политика конфиденциальности')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionPlaceholder(title: '1. Общие положения'),
          _SectionPlaceholder(title: '2. Сбор и использование данных'),
          _SectionPlaceholder(title: '3. Хранение данных'),
          _SectionPlaceholder(title: '4. Контактная информация'),
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
