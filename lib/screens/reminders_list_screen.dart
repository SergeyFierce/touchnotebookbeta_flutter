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

    final updated = reminder.copyWith(
      completedAt: completed ? DateTime.now() : null,
    );

    try {
      await _db.updateReminder(updated);
      if (completed) {
        await PushNotifications.cancel(reminder.id!);
      } else if (updated.remindAt.isAfter(DateTime.now())) {
        await PushNotifications.scheduleOneTime(
          id: updated.id!,
          whenLocal: updated.remindAt,
          title: 'Напоминание: ${widget.contact.name}',
          body: updated.text,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            completed
                ? 'Напоминание отмечено как завершённое'
                : 'Напоминание вновь активное',
          ),
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
        onChanged: (value) => _setCompleted(reminder, value ?? false),
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
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Удалить напоминание',
        onPressed: () => _deleteReminder(reminder),
      ),
      onTap: () => _setCompleted(reminder, !completed),
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
