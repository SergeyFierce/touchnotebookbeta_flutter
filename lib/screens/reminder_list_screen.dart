import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contact.dart';
import '../models/reminder.dart';
import '../services/reminder_database_service.dart';
import '../widgets/system_notifications.dart';

class ReminderListScreen extends StatefulWidget {
  final Contact contact;

  const ReminderListScreen({super.key, required this.contact});

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  final _service = ReminderDatabaseService.instance;

  List<Reminder> _reminders = const [];
  bool _isLoading = false;
  bool _fetchInProgress = false;

  late final VoidCallback _revisionListener;

  @override
  void initState() {
    super.initState();
    _revisionListener = () => _loadReminders(silent: true);
    _service.revision.addListener(_revisionListener);
    _loadReminders();
  }

  @override
  void dispose() {
    _service.revision.removeListener(_revisionListener);
    super.dispose();
  }

  Future<void> _loadReminders({bool silent = false}) async {
    if (widget.contact.id == null) return;
    if (_fetchInProgress) return;
    _fetchInProgress = true;
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final reminders = await _service.remindersByContact(widget.contact.id!);
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
      });
    } catch (_) {
      if (mounted) {
        showErrorBanner('Не удалось загрузить напоминания');
      }
    } finally {
      _fetchInProgress = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addReminder() async {
    if (widget.contact.id == null) return;
    final created = await _openReminderEditor();
    if (created == null) return;

    try {
      await _service.insertReminder(created);
      if (!mounted) return;
      showSuccessBanner('Напоминание создано');
      await _loadReminders(silent: true);
    } catch (_) {
      if (mounted) {
        showErrorBanner('Не удалось сохранить напоминание');
      }
    }
  }

  Future<void> _editReminder(Reminder reminder) async {
    final edited = await _openReminderEditor(reminder: reminder);
    if (edited == null) return;

    try {
      await _service.updateReminder(edited);
      if (!mounted) return;
      showSuccessBanner('Напоминание обновлено');
      await _loadReminders(silent: true);
    } catch (_) {
      if (mounted) {
        showErrorBanner('Не удалось обновить напоминание');
      }
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    if (reminder.id == null) return;
    final confirmed = await showDialog<bool>(
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

    if (confirmed != true) return;

    try {
      await _service.deleteReminder(reminder.id!);
      if (!mounted) return;
      showSuccessBanner('Напоминание удалено');
      await _loadReminders(silent: true);
    } catch (_) {
      if (mounted) {
        showErrorBanner('Не удалось удалить напоминание');
      }
    }
  }

  Future<Reminder?> _openReminderEditor({Reminder? reminder}) async {
    if (widget.contact.id == null) return null;

    final controller = TextEditingController(text: reminder?.title ?? '');
    DateTime scheduled = reminder?.scheduledDateTime ??
        DateTime.now().add(const Duration(hours: 1));
    bool showTitleError = false;

    final result = await showDialog<Reminder>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickDate() async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: scheduled,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                scheduled = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  scheduled.hour,
                  scheduled.minute,
                );
                setState(() {});
              }
            }

            Future<void> pickTime() async {
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(scheduled),
              );
              if (pickedTime != null) {
                scheduled = DateTime(
                  scheduled.year,
                  scheduled.month,
                  scheduled.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
                setState(() {});
              }
            }

            final formattedDate = DateFormat('dd.MM.yyyy').format(scheduled);
            final formattedTime = DateFormat('HH:mm').format(scheduled);

            return AlertDialog(
              title: Text(reminder == null ? 'Новое напоминание' : 'Редактирование'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Текст напоминания',
                        errorText: showTitleError ? 'Введите текст' : null,
                      ),
                      autofocus: true,
                      onChanged: (value) {
                        if (showTitleError && value.trim().isNotEmpty) {
                          setState(() => showTitleError = false);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Дата', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: pickDate,
                      child: Text(formattedDate),
                    ),
                    const SizedBox(height: 16),
                    Text('Время', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: pickTime,
                      child: Text(formattedTime),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    final title = controller.text.trim();
                    if (title.isEmpty) {
                      setState(() => showTitleError = true);
                      return;
                    }
                    Navigator.pop(
                      context,
                      Reminder(
                        id: reminder?.id,
                        contactId: widget.contact.id!,
                        title: title,
                        scheduledDateTime: scheduled,
                      ),
                    );
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  String _formatDateTime(DateTime dateTime) {
    final date = DateFormat('dd MMMM yyyy', 'ru').format(dateTime);
    final time = DateFormat('HH:mm').format(dateTime);
    return '$date в $time';
  }

  Widget _buildPlaceholder({required Widget child}) {
    return RefreshIndicator(
      onRefresh: () => _loadReminders(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Center(child: child),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: () => _loadReminders(silent: true),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _reminders.length,
        itemBuilder: (context, index) {
          final reminder = _reminders[index];
          return ListTile(
            leading: const Icon(Icons.alarm),
            title: Text(reminder.title),
            subtitle: Text(_formatDateTime(reminder.scheduledDateTime)),
            trailing: Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'Редактировать',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editReminder(reminder),
                ),
                IconButton(
                  tooltip: 'Удалить',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteReminder(reminder),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (context, index) => const Divider(height: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContactId = widget.contact.id != null;

    Widget body;
    if (!hasContactId) {
      body = _buildPlaceholder(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.info_outline, size: 48),
            SizedBox(height: 16),
            Text(
              'Сохраните контакт, чтобы добавлять напоминания',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (_isLoading && _reminders.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_reminders.isEmpty) {
      body = _buildPlaceholder(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.alarm_add_outlined, size: 48),
            SizedBox(height: 16),
            Text(
              'Напоминаний пока нет',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      body = _buildList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Напоминания'),
      ),
      body: SafeArea(child: body),
      floatingActionButton: hasContactId
          ? FloatingActionButton.extended(
              onPressed: _addReminder,
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            )
          : null,
    );
  }
}
