import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReminderDraft {
  final String text;
  final DateTime scheduledAt;

  ReminderDraft({required this.text, required this.scheduledAt});
}

Future<ReminderDraft?> showAddReminderDialog(BuildContext context) {
  return showDialog<ReminderDraft>(
    context: context,
    builder: (context) => const _ReminderDialog(),
  );
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog();

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  DateTime? get _scheduledDateTime {
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) return null;
    final scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (scheduled.isBefore(DateTime.now())) return null;
    return scheduled;
  }

  void _submit() {
    if (_submitting) return;
    final scheduled = _scheduledDateTime;
    if (!_formKey.currentState!.validate() || scheduled == null) {
      if (scheduled == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите дату и время в будущем')),
        );
      }
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context).pop(ReminderDraft(text: _textController.text.trim(), scheduledAt: scheduled));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = _selectedDate == null
        ? 'Выбрать дату'
        : DateFormat.yMMMMd('ru').format(_selectedDate!);
    final timeText = _selectedTime == null
        ? 'Выбрать время'
        : _selectedTime!.format(context);

    return AlertDialog(
      title: const Text('Добавить напоминание'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Текст напоминания',
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите текст напоминания';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(dateText, style: theme.textTheme.bodyMedium),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(timeText, style: theme.textTheme.bodyMedium),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
