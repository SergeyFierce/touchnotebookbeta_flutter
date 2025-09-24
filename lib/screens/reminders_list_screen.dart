import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contact.dart';
import '../models/reminder.dart';
import '../services/contact_database.dart';
import '../services/reminder_scheduler.dart';
import 'add_reminder_screen.dart';
import '../widgets/system_notifications.dart';

class RemindersListScreen extends StatefulWidget {
  final Contact contact;
  final Future<void> Function()? onRemindersChanged;

  const RemindersListScreen({
    super.key,
    required this.contact,
    this.onRemindersChanged,
  });

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  final _db = ContactDatabase.instance;
  List<Reminder> _reminders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    if (widget.contact.id == null) return;
    setState(() => _isLoading = true);
    try {
      final list = await _db.remindersByContact(widget.contact.id!);
      await ReminderScheduler.instance.scheduleMany(
        list.where((r) => !r.isCompleted),
        contactName: widget.contact.name,
      );
      if (!mounted) return;
      setState(() {
        _reminders = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorBanner('Не удалось загрузить напоминания');
    }
  }

  Future<void> _notifyParent() async {
    final callback = widget.onRemindersChanged;
    if (callback != null) {
      await callback();
    }
  }

  Future<void> _addReminder() async {
    if (widget.contact.id == null) return;
    final reminder = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(contactId: widget.contact.id!),
      ),
    );
    if (reminder != null) {
      await _loadReminders();
      await _notifyParent();
      showSuccessBanner('Напоминание добавлено');
    }
  }

  Future<void> _editReminder(Reminder reminder) async {
    if (widget.contact.id == null || reminder.id == null) return;
    final updated = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(
          contactId: widget.contact.id!,
          initial: reminder,
        ),
      ),
    );
    if (updated != null) {
      await _loadReminders();
      await _notifyParent();
      showSuccessBanner('Напоминание обновлено');
    }
  }

  Future<void> _toggleCompleted(Reminder reminder) async {
    final updated = reminder.copyWith(isCompleted: !reminder.isCompleted);
    try {
      await _db.updateReminder(updated);
      await ReminderScheduler.instance.scheduleReminder(
        updated,
        contactName: widget.contact.name,
      );
      if (!mounted) return;
      setState(() {
        final index = _reminders.indexWhere((r) => r.id == updated.id);
        if (index != -1) {
          _reminders[index] = updated;
        }
      });
      await _notifyParent();
    } catch (e) {
      showErrorBanner('Не удалось обновить напоминание');
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить напоминание?'),
        content: Text(reminder.title),
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
    if (confirmed == true && reminder.id != null) {
      try {
        await _db.deleteReminder(reminder.id!);
        await ReminderScheduler.instance.cancelReminder(reminder.id!);
        if (!mounted) return;
        setState(() => _reminders.removeWhere((r) => r.id == reminder.id));
        await _notifyParent();
        showSuccessBanner('Напоминание удалено');
      } catch (e) {
        showErrorBanner('Не удалось удалить напоминание');
      }
    }
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _reminderTile(Reminder reminder) {
    final theme = Theme.of(context);
    final dateText = DateFormat('dd.MM.yyyy HH:mm').format(reminder.remindAt);
    final isCompleted = reminder.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: isCompleted,
          onChanged: (_) => _toggleCompleted(reminder),
        ),
        title: Text(
          reminder.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? theme.hintColor : null,
          ),
        ),
        subtitle: Text(dateText),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editReminder(reminder);
                break;
              case 'delete':
                _deleteReminder(reminder);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit),
                title: Text('Редактировать'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline),
                title: Text('Удалить'),
              ),
            ),
          ],
        ),
        onTap: () => _toggleCompleted(reminder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _reminders
        .where((r) => !r.isCompleted)
        .toList()
      ..sort((a, b) => a.remindAt.compareTo(b.remindAt));
    final completed = _reminders
        .where((r) => r.isCompleted)
        .toList()
      ..sort((a, b) => b.remindAt.compareTo(a.remindAt));

    final showEmpty = !_isLoading && upcoming.isEmpty && completed.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Напоминания'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminder,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Новое напоминание'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: showEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.alarm_off, size: 48),
                            SizedBox(height: 12),
                            Text('Напоминаний пока нет'),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          if (upcoming.isNotEmpty) ...[
                            _sectionHeader('Активные'),
                            ...upcoming.map(_reminderTile),
                          ],
                          if (completed.isNotEmpty) ...[
                            if (upcoming.isNotEmpty) const SizedBox(height: 8),
                            _sectionHeader('Выполненные'),
                            ...completed.map(_reminderTile),
                          ],
                        ],
                      ),
              ),
      ),
    );
  }
}
