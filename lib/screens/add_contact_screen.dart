import 'package:flutter/material.dart';

class AddContactScreen extends StatelessWidget {
  const AddContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить контакт')),
      body: const Center(
        child: Text('Страница добавления контакта'),
      ),
    );
  }
}

