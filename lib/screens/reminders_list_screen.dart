import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contact.dart';
import '../models/reminder.dart';
import '../services/contact_database.dart';
import '../widgets/system_notifications.dart';
import 'reminder_form_screen.dart';

class RemindersListScreen extends StatefulWidget {
  final Contact contact;

  const RemindersListScreen({super.key, required this.contact});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  final ContactDatabase _db = ContactDatabase.instance;
  List<Reminder> _reminders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _db.revision.addListener(_onDbRevision);
  }

  @override
  void dispose() {
    _db.revision.removeListener(_onDbRevision);
    super.dispose();
  }

  void _onDbRevision() {
    if (!mounted) return;
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    if (widget.contact.id == null) return;
    setState(() => _isLoading = true);
    final list = await _db.remindersByContact(widget.contact.id!);
    if (!mounted) return;
    setState(() {
      _reminders = list;
      _isLoading = false;
    });
  }

  Future<void> _addReminder() async {
    final contactId = widget.contact.id;
    if (contactId == null) return;
    final result = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderFormScreen(
          contactId: contactId,
          contactName: widget.contact.name,
        ),
      ),
    );
    if (result != null && mounted) {
      await _loadReminders();
      showSuccessBanner('Напоминание добавлено');
    }
  }

  Future<void> _editReminder(Reminder reminder) async {
    final contactId = widget.contact.id;
    if (contactId == null) return;
    final updated = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderFormScreen(
          contactId: contactId,
          contactName: widget.contact.name,
          reminder: reminder,
        ),
      ),
    );
    if (updated != null && mounted) {
      await _loadReminders();
      showSuccessBanner('Изменения сохранены');
    }
  }

  Future<bool> _confirmDelete(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить напоминание?'),
        content: const Text('Напоминание также будет удалено из расписания уведомлений.'),
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
    return confirmed ?? false;
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    if (reminder.id == null) return;
    await _db.deleteReminder(reminder.id!);
    if (!mounted) return;
    setState(() {
      _reminders.removeWhere((r) => r.id == reminder.id);
    });
    showSuccessBanner('Напоминание удалено');
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reminders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alarm_off_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Пока нет напоминаний',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text('Добавьте напоминание, чтобы не забыть о важном событии.'),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _reminders.length,
        itemBuilder: (context, index) {
          final reminder = _reminders[index];
          return _ReminderTile(
            reminder: reminder,
            onTap: () => _editReminder(reminder),
            onDelete: () => _deleteReminder(reminder),
            confirmDelete: () => _confirmDelete(reminder),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Напоминания'),
      ),
      body: SafeArea(child: _buildBody()),
      floatingActionButton: widget.contact.id == null
          ? null
          : FloatingActionButton(
              onPressed: _addReminder,
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final Future<bool> Function() confirmDelete;

  const _ReminderTile({
    required this.reminder,
    required this.onTap,
    required this.onDelete,
    required this.confirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPast = reminder.scheduledAt.isBefore(DateTime.now());
    final icon = isPast ? Icons.history : Icons.alarm;
    final color = isPast ? theme.colorScheme.outline : theme.colorScheme.primary;
    final date = DateFormat('dd.MM.yyyy HH:mm').format(reminder.scheduledAt);

    return Dismissible(
      key: ValueKey(reminder.id ?? reminder.hashCode),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete(),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: color),
          title: Text(reminder.text),
          subtitle: Text(date),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
