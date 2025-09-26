import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reminder.dart';
import '../services/contact_database.dart';

class ReminderFormScreen extends StatefulWidget {
  final int contactId;
  final String contactName;
  final Reminder? reminder;

  const ReminderFormScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    this.reminder,
  });

  bool get isEditing => reminder != null;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textController;
  late DateTime _scheduledAt;

  @override
  void initState() {
    super.initState();
    final initialReminder = widget.reminder;
    _textController = TextEditingController(text: initialReminder?.text ?? '');
    _scheduledAt = initialReminder?.scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({required String label, IconData? icon}) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        _scheduledAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _scheduledAt.hour,
          _scheduledAt.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (picked != null) {
      setState(() {
        _scheduledAt = DateTime(
          _scheduledAt.year,
          _scheduledAt.month,
          _scheduledAt.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  bool get _canSave => (_formKey.currentState?.validate() ?? false) && _textController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;

    final trimmed = _textController.text.trim();
    final now = DateTime.now();

    final reminder = (widget.reminder ?? Reminder(
          contactId: widget.contactId,
          text: trimmed,
          scheduledAt: _scheduledAt,
          createdAt: now,
        ))
        .copyWith(
          text: trimmed,
          scheduledAt: _scheduledAt,
        );

    if (reminder.id == null) {
      final id = await ContactDatabase.instance.insertReminder(
        reminder,
        contactName: widget.contactName,
      );
      if (!mounted) return;
      Navigator.pop(context, reminder.copyWith(id: id));
    } else {
      await ContactDatabase.instance.updateReminder(
        reminder,
        contactName: widget.contactName,
      );
      if (!mounted) return;
      Navigator.pop(context, reminder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = DateFormat('dd.MM.yyyy').format(_scheduledAt);
    final timeText = DateFormat('HH:mm').format(_scheduledAt);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Отмена',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.isEditing ? 'Редактировать напоминание' : 'Новое напоминание'),
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
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Текст напоминания',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _textController,
                            maxLines: null,
                            textInputAction: TextInputAction.newline,
                            decoration: _fieldDecoration(label: 'Напоминание*', icon: Icons.alarm_outlined),
                            onChanged: (_) => setState(() {}),
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Введите текст напоминания' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Когда напомнить',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _pickDate,
                              child: ListTile(
                                leading: const Icon(Icons.event_outlined),
                                title: const Text('Дата'),
                                subtitle: Text(dateText),
                                trailing: const Icon(Icons.arrow_drop_down),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Material(
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _pickTime,
                              child: ListTile(
                                leading: const Icon(Icons.schedule_outlined),
                                title: const Text('Время'),
                                subtitle: Text(timeText),
                                trailing: const Icon(Icons.arrow_drop_down),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _canSave
            ? FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(widget.isEditing ? 'Сохранить' : 'Создать'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
