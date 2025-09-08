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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ==== UI helpers ====

  InputDecoration _outlinedDec({
    required String label,
    String? hint,
    IconData? prefixIcon,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _borderedTile({required Widget child}) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }

  // ==== actions ====

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now, // не разрешаем будущие даты
      locale: const Locale('ru'),
    );
    if (picked != null) {
      // сохраняем время из _date (только день меняем)
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute, _date.second);
      });
    }
  }

  bool get _canSave => (_formKey.currentState?.validate() ?? false);

  Future<void> _save() async {
    if (!_canSave) return;
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
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(_date);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Отмена',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Добавить заметку'),
        actions: [
          if (_canSave)
            IconButton(
              tooltip: 'Сохранить',
              icon: const Icon(Icons.check),
              onPressed: _save,
            )
          else
            const SizedBox.shrink(), // невидимо вместо серой иконки
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
                children: [
                  _sectionCard(
                    title: 'Текст',
                    children: [
                      TextFormField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: _outlinedDec(
                          label: 'Текст заметки*',
                          hint: 'Введите текст',
                          prefixIcon: Icons.notes_outlined,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Введите текст' : null,
                      ),
                    ],
                  ),
                  _sectionCard(
                    title: 'Дата',
                    children: [
                      _borderedTile(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: const Icon(Icons.event_outlined),
                          title: const Text('Дата добавления'),
                          subtitle: Text(dateStr),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: _pickDate,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _canSave
              ? FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Сохранить'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )
              : const SizedBox.shrink(), // пустое место вместо кнопки
        ),
      ),

    );
  }
}
