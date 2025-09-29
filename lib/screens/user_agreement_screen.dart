import 'package:flutter/material.dart';

class UserAgreementScreen extends StatelessWidget {
  const UserAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пользовательское соглашение')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Раздел пользовательского соглашения находится в разработке.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
