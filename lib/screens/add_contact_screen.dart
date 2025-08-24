import 'package:flutter/material.dart';

class AddContactScreen extends StatelessWidget {
  final String? category;
  const AddContactScreen({super.key, this.category});
  const AddContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить контакт')),
      body: Center(
        child: Text(
          category != null
              ? 'Добавление контакта в категорию: ' + category!
              : 'Страница добавления контакта',
        ),
      ),
    );
  }
}
      body: const Center(
        child: Text('Страница добавления контакта'),
      ),
    );
  }
}