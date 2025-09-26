import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reminder.dart';
import '../services/contact_database.dart';

class ReminderDetailsScreen extends StatefulWidget {
  final Reminder reminder;

  const ReminderDetailsScreen({super.key, required this.reminder});

  @override
  State<ReminderDetailsScreen> createState() => _ReminderDetailsScreenState();
}

class _ReminderDetailsScreenState extends State<ReminderDetailsScreen> {
  late Reminder _reminder;
  late Reminder _savedSnapshot;

  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  DateTime _dueAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _reminder = widget.reminder;
    _loadFromReminder();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _loadFromReminder() {
    _textController.text = _reminder.text ?? '';
    _dueAt = _reminder.dueAt;
    _savedSnapshot = _reminder;
    setState(() {});
  }

  bool get _isDirty {
    final textChanged = _textController.text.trim() != (_savedSnapshot.text ?? '');
    final dateChanged = !_dueAt.isAtSameMomentAs(_savedSnapshot.dueAt);
    return textChanged || dateChanged;
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

  Future<void> _save() async {
    if (!_isDirty) return;

    final updated = _reminder.copyWith(
      dueAt: _dueAt,
      text: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
    );

    await ContactDatabase.instance.updateReminder(updated);
    _reminder = updated;
    _savedSnapshot = updated;

    if (!mounted) return;
    Navigator.pop(context, {'updated': updated});
  }

  Future<void> _delete() async {
    if (_reminder.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить напоминание?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await ContactDatabase.instance.deleteReminder(_reminder.id!);
    if (!mounted) return;
    Navigator.pop(context, {'deleted': _reminder});
  }

  @override
  Widget build(BuildContext context) {
    final dueStr = DateFormat('dd.MM.yyyy HH:mm').format(_dueAt);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _isDirty ? 'Отменить изменения' : 'Назад',
          icon: Icon(_isDirty ? Icons.close : Icons.arrow_back),
          onPressed: () {
            if (_isDirty) {
              _loadFromReminder();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Напоминание'),
        actions: [
          if (_isDirty)
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
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Описание',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _textController,
                            minLines: 1,
                            maxLines: null,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              labelText: 'Текст',
                              hintText: 'Необязательное описание',
                              prefixIcon: const Icon(Icons.alarm),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Дата и время',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: const Icon(Icons.event_available_outlined),
                            title: const Text('Напомнить'),
                            subtitle: Text(dueStr),
                            trailing: const Icon(Icons.arrow_drop_down),
                            onTap: _pickDateTime,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                          ),
                        ],
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
                    child: const Text('Удалить напоминание'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
