import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contact.dart';
import '../models/reminder.dart';
import '../services/contact_database.dart';
import '../services/push_notifications.dart';

class RemindersListScreen extends StatefulWidget {
  final Contact contact;

  const RemindersListScreen({super.key, required this.contact});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  final _db = ContactDatabase.instance;
  final _formatter = DateFormat('dd.MM.yyyy HH:mm');

  List<Reminder> _active = const [];
  List<Reminder> _completed = const [];
  bool _loading = false;

  late final VoidCallback _revisionListener;

  @override
  void initState() {
    super.initState();
    _revisionListener = _loadReminders;
    _db.revision.addListener(_revisionListener);
    _loadReminders();
  }

  @override
  void dispose() {
    _db.revision.removeListener(_revisionListener);
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final contactId = widget.contact.id;
    if (contactId == null) return;
    setState(() => _loading = true);

    final active =
        await _db.remindersByContact(contactId, onlyActive: true);
    final completed =
        await _db.remindersByContact(contactId, onlyCompleted: true);

    if (!mounted) return;
    setState(() {
      _active = active;
      _completed = completed;
      _loading = false;
    });
  }

  Future<void> _setCompleted(Reminder reminder, bool completed) async {
    if (reminder.id == null) return;

    if (!completed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Завершённое напоминание нельзя вернуть в активное'),
        ),
      );
      return;
    }

    final updated = reminder.copyWith(completedAt: DateTime.now());

    try {
      await _db.updateReminder(updated);
      await PushNotifications.cancel(reminder.id!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Напоминание отмечено как завершённое'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось обновить напоминание: $e'),
        ),
      );
    }
  }

  Future<void> _editReminder(Reminder reminder) async {
    if (reminder.id == null) return;

    final result = await _showReminderDialog(initial: reminder);
    if (result == null) return;

    final text = result.text.trim();
    final when = result.when;
    final isCompleted = reminder.completedAt != null;
    if (!isCompleted && when.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите время в будущем')),
      );
      return;
    }

    final updated = reminder.copyWith(text: text, remindAt: when);

    try {
      await _db.updateReminder(updated);
      if (!isCompleted) {
        await PushNotifications.cancel(reminder.id!);
        await PushNotifications.scheduleOneTime(
          id: updated.id!,
          whenLocal: updated.remindAt,
          title: 'Напоминание: ${widget.contact.name}',
          body: updated.text,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напоминание обновлено')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить напоминание: $e')),
      );
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final id = reminder.id;
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить напоминание?'),
        content: const Text('Напоминание будет удалено и уведомление отменено.'),
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

    try {
      await _db.deleteReminder(id);
      await PushNotifications.cancel(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напоминание удалено')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить напоминание: $e')),
      );
    }
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildReminderTile(Reminder reminder, {required bool completed}) {
    final theme = Theme.of(context);
    final subtitle = completed
        ? reminder.completedAt != null
            ? 'Завершено: ${_formatter.format(reminder.completedAt!)}'
            : 'Завершено'
        : 'Запланировано на ${_formatter.format(reminder.remindAt)}';

    return ListTile(
      leading: Checkbox.adaptive(
        value: completed,
        onChanged: completed
            ? null
            : (value) {
                if (value == true) {
                  _setCompleted(reminder, true);
                }
              },
      ),
      title: Text(
        reminder.text,
        style: completed
            ? theme.textTheme.titleMedium?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.hintColor,
              )
            : theme.textTheme.titleMedium,
      ),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Редактировать напоминание',
            onPressed: () => _editReminder(reminder),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Удалить напоминание',
            onPressed: () => _deleteReminder(reminder),
          ),
        ],
      ),
      onTap: completed ? null : () => _setCompleted(reminder, true),
    );
  }

  Future<({String text, DateTime when})?> _showReminderDialog({Reminder? initial}) async {
    final controller = TextEditingController(text: initial?.text ?? '');
    var selected = initial?.remindAt ?? DateTime.now().add(const Duration(minutes: 5));
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<({String text, DateTime when})>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dateLabel = DateFormat('dd.MM.yyyy HH:mm').format(selected);

            return AlertDialog(
              title: Text(initial == null ? 'Новое напоминание' : 'Редактирование напоминания'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: null,
                    autofocus: true,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Текст напоминания',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(dateLabel),
                    subtitle: const Text('Дата и время'),
                    onTap: () async {
                      final picked = await _pickReminderDateTime(selected);
                      if (picked != null) {
                        setState(() => selected = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Введите текст напоминания')),
                      );
                      return;
                    }
                    Navigator.pop(context, (text: text, when: selected));
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<DateTime?> _pickReminderDateTime(DateTime initial) async {
    final now = DateTime.now();
    final minimumDate = initial.isBefore(now) ? initial : now;
    var temp = initial;

    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext, temp),
                        child: const Text('Готово'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 0),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.dateAndTime,
                    use24hFormat: true,
                    initialDateTime: initial,
                    minimumDate: minimumDate,
                    maximumDate: now.add(const Duration(days: 365 * 5)),
                    onDateTimeChanged: (value) => temp = value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _active.isNotEmpty || _completed.isNotEmpty;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Напоминания — ${widget.contact.name}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Активные'),
              Tab(text: 'Завершённые'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _active.isEmpty
                      ? _buildEmptyState('Нет активных напоминаний')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemBuilder: (context, index) => _buildReminderTile(
                                _active[index],
                                completed: false,
                              ),
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemCount: _active.length,
                        ),
                  _completed.isEmpty
                      ? _buildEmptyState(hasData
                          ? 'Завершённых напоминаний нет'
                          : 'Нет завершённых напоминаний')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemBuilder: (context, index) => _buildReminderTile(
                                _completed[index],
                                completed: true,
                              ),
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemCount: _completed.length,
                        ),
                ],
              ),
      ),
    );
  }
}
