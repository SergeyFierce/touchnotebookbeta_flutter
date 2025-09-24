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
  late Note _note;
  late Note _savedSnapshot;

  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _loadFromNote();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _loadFromNote() {
    _textController.text = _note.text;
    _date = _note.createdAt;
    _savedSnapshot = _note.copyWith(); // копия снапшота
    setState(() {});
  }

  bool get _isDirty =>
      _textController.text.trim() != _savedSnapshot.text ||
          !DateUtils.isSameDay(_date, _savedSnapshot.createdAt);

  bool get _canSave =>
      _isDirty && (_formKey.currentState?.validate() ?? false);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;

    final updated = _note.copyWith(
      text: _textController.text.trim(),
      createdAt: _date,
    );

    try {
      await ContactDatabase.instance.updateNote(updated);
      _note = updated;
      _savedSnapshot = updated.copyWith();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заметка сохранена')),
      );
      Navigator.pop(context, {'updated': true});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при сохранении: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteDialog(),
    );
    if (ok != true) return;

    try {
      if (_note.id != null) {
        await ContactDatabase.instance.deleteNote(_note.id!);
      }
      if (!mounted) return;
      Navigator.pop(context, {'deleted': _note});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy').format(_date);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _isDirty ? 'Отменить изменения' : 'Назад',
          icon: Icon(_isDirty ? Icons.close : Icons.arrow_back),
          onPressed: () {
            if (_isDirty) {
              _loadFromNote(); // откат изменений
            } else {
              Navigator.pop(context); // обычный выход
            }
          },
        ),
        title: const Text('Заметка'),
        actions: [
          if (_isDirty)
            IconButton(
              tooltip: 'Сохранить',
              icon: const Icon(Icons.check),
              onPressed: _canSave ? _save : null,
            ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  SectionCard(
                    title: 'Текст',
                    child: TextFormField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: AppDecorations.input(
                        'Текст заметки*',
                        hint: 'Введите текст',
                        prefixIcon: Icons.notes,
                      ),
                      validator: _validateNotEmpty,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SectionCard(
                    title: 'Дата',
                    child: BorderedTile(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Дата добавления'),
                        subtitle: Text(dateStr),
                        trailing: const Icon(Icons.arrow_drop_down),
                        onTap: _pickDate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _delete,
                    child: const Text('Удалить заметку'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateNotEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Введите текст' : null;
}

// ==== Дополнительные виджеты/утилиты ====

class AppDecorations {
  static InputDecoration input(
      String label, {
        String? hint,
        IconData? prefixIcon,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const SectionCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class BorderedTile extends StatelessWidget {
  final Widget child;
  const BorderedTile({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Удалить заметку?'),
      content: const Text('Это действие нельзя отменить.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Удалить',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
