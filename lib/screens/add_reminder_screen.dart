import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reminder.dart';
import '../services/contact_database.dart';

class AddReminderScreen extends StatefulWidget {
  final int contactId;
  const AddReminderScreen({super.key, required this.contactId});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  DateTime _dueAt = DateTime.now().add(const Duration(hours: 1));

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  InputDecoration _inputDec({
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

  Widget _section({required String title, required List<Widget> children}) {
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

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
      locale: const Locale('ru'),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null) return;

    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  bool get _canSave => true;

  Future<void> _save() async {
    final reminder = Reminder(
      contactId: widget.contactId,
      dueAt: _dueAt,
      text: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
    );
    final id = await ContactDatabase.instance.insertReminder(reminder);
    if (!mounted) return;
    Navigator.pop(context, reminder.copyWith(id: id));
  }

  @override
  Widget build(BuildContext context) {
    final dueStr = DateFormat('dd.MM.yyyy HH:mm').format(_dueAt);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Отмена',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Добавить напоминание'),
        actions: [
          IconButton(
            tooltip: 'Сохранить',
            icon: const Icon(Icons.check),
            onPressed: _save,
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
                children: [
                  _section(
                    title: 'Описание',
                    children: [
                      TextFormField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: _inputDec(
                          label: 'Текст',
                          hint: 'Необязательное описание',
                          prefixIcon: Icons.alarm,
                        ),
                      ),
                    ],
                  ),
                  _section(
                    title: 'Дата и время',
                    children: [
                      _borderedTile(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: const Icon(Icons.event_available_outlined),
                          title: const Text('Напомнить'),
                          subtitle: Text(dueStr),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: _pickDateTime,
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Text('Сохранить'),
        ),
      ),
    );
  }
}
