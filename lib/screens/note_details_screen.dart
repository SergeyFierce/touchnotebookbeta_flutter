import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../services/contact_database.dart';

class NoteDetailsScreen extends StatefulWidget {
  final Note note;
  const NoteDetailsScreen({super.key, required this.note});

  @override
  State<NoteDetailsScreen> createState() => _NoteDetailsScreenState();
}

class _NoteDetailsScreenState extends State<NoteDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  late Note _note;
  bool _isEditing = false;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _textController.text = _note.text;
    _date = _note.createdAt;
  }

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

  void _startEdit() => setState(() => _isEditing = true);

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _textController.text = _note.text;
      _date = _note.createdAt;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final old = _note;
    final updated = Note(
      id: _note.id,
      contactId: _note.contactId,
      text: _textController.text.trim(),
      createdAt: _date,
    );
    await ContactDatabase.instance.updateNote(updated);
    setState(() {
      _note = updated;
      _isEditing = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Заметка обновлена'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await ContactDatabase.instance.updateNote(old);
            setState(() {
              _note = old;
              _textController.text = old.text;
              _date = old.createdAt;
            });
          },
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: const Text('Действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm == true) {
      await ContactDatabase.instance.deleteNote(_note.id!);
      if (!mounted) return;
      Navigator.pop(context, {'deleted': _note});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isEditing ?
            TextButton(onPressed: _cancelEdit, child: const Text('Отмена'))
            : const BackButton(),
        title: Text(_isEditing ? 'Редактирование' : 'Детали заметки'),
        actions: [
          _isEditing
              ? TextButton(onPressed: _save, child: const Text('Сохранить'))
              : TextButton(onPressed: _startEdit, child: const Text('Редактировать')),
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
                readOnly: !_isEditing,
                decoration: const InputDecoration(labelText: 'Текст'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Введите текст' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Дата добавления'),
                subtitle: Text(DateFormat('dd.MM.yyyy').format(_date)),
                onTap: _isEditing ? _pickDate : null,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isEditing
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: _delete,
                child: const Text('Удалить заметку'),
              ),
            ),
    );
  }
}
