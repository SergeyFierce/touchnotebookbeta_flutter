import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../services/contact_database.dart';

class AddNoteScreen extends StatefulWidget {
  final int contactId;
  const AddNoteScreen({super.key, required this.contactId});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  DateTime _date = DateTime.now();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final note = Note(
      contactId: widget.contactId,
      text: _textController.text.trim(),
      createdAt: _date,
    );
    final id = await ContactDatabase.instance.insertNote(note);
    if (!mounted) return;
    Navigator.pop(context, note.copyWith(id: id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Добавить заметку'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _textController,
                maxLines: null,
                decoration: const InputDecoration(labelText: 'Текст заметки*'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Введите текст' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Дата добавления'),
                subtitle: Text(DateFormat('dd.MM.yyyy').format(_date)),
                onTap: _pickDate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
