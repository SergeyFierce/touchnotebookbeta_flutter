import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reminder.dart';
import '../services/contact_database.dart';
import '../services/reminder_scheduler.dart';

class AddReminderScreen extends StatefulWidget {
  final int contactId;
  final Reminder? initial;

  const AddReminderScreen({super.key, required this.contactId, this.initial});

  bool get isEditing => initial != null;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  late DateTime _remindAt;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _titleController.text = initial.title;
      _remindAt = initial.remindAt;
      _isCompleted = initial.isCompleted;
    } else {
      final now = DateTime.now();
      _remindAt = now.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

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
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
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
      initialDate: _remindAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ru'),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_remindAt),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (time == null) return;

    setState(() {
      _remindAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  bool get _canSave => (_formKey.currentState?.validate() ?? false);

  Future<void> _save() async {
    if (!_canSave) return;

    final reminder = Reminder(
      id: widget.initial?.id,
      contactId: widget.contactId,
      title: _titleController.text.trim(),
      remindAt: _remindAt,
      isCompleted: _isCompleted,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
    );

    if (widget.isEditing) {
      await ContactDatabase.instance.updateReminder(reminder);
      await ReminderScheduler.instance.scheduleReminder(reminder);
      if (!mounted) return;
      Navigator.pop(context, reminder);
    } else {
      final id = await ContactDatabase.instance.insertReminder(reminder);
      final saved = reminder.copyWith(id: id);
      await ReminderScheduler.instance.scheduleReminder(saved);
      if (!mounted) return;
      Navigator.pop(context, saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Изменить напоминание' : 'Добавить напоминание';
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(_remindAt);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Отмена',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title),
        actions: [
          if (_canSave)
            IconButton(
              tooltip: 'Сохранить',
              icon: const Icon(Icons.check),
              onPressed: _save,
            )
          else
            const SizedBox.shrink(),
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
                    title: 'Описание',
                    children: [
                      TextFormField(
                        controller: _titleController,
                        minLines: 1,
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                        decoration: _outlinedDec(
                          label: 'Текст напоминания',
                          hint: 'О чём нужно напомнить',
                          prefixIcon: Icons.alarm,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите текст напоминания';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  _sectionCard(
                    title: 'Когда напомнить',
                    children: [
                      _borderedTile(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: const Icon(Icons.event_available),
                          title: Text(dateStr),
                          subtitle: const Text('Нажмите, чтобы выбрать дату и время'),
                          onTap: _pickDateTime,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _borderedTile(
                        child: SwitchListTile(
                          title: const Text('Пометка выполнено'),
                          value: _isCompleted,
                          onChanged: (value) => setState(() => _isCompleted = value),
                          secondary: const Icon(Icons.check_circle_outline),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _canSave ? _save : null,
        icon: const Icon(Icons.check),
        label: const Text('Сохранить'),
      ),
    );
  }
}
