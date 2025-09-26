import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contact.dart';
import '../models/reminder.dart';
import '../services/contact_database.dart';
import 'add_reminder_screen.dart';
import 'reminder_details_screen.dart';

class RemindersListScreen extends StatefulWidget {
  final Contact contact;
  final ValueChanged<Reminder>? onReminderChanged;

  const RemindersListScreen({super.key, required this.contact, this.onReminderChanged});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

enum SortRemindersOption { dueAsc, dueDesc }

class _RemindersListScreenState extends State<RemindersListScreen> {
  final _db = ContactDatabase.instance;
  final ScrollController _scroll = ScrollController();

  List<Reminder> _reminders = [];
  List<Reminder> _sortedReminders = [];

  static const int _pageSize = 20;
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoaded = false;

  SortRemindersOption _sort = SortRemindersOption.dueAsc;

  @override
  void initState() {
    super.initState();
    _loadReminders(reset: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadReminders({bool reset = false}) async {
    if (reset) {
      _page = 0;
      _hasMore = true;
      _reminders = [];
      _sortedReminders = [];
    }
    await _loadMoreReminders(reset: reset);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMoreReminders();
    }
  }

  Future<void> _loadMoreReminders({bool reset = false}) async {
    if (widget.contact.id == null || _isLoading) return;
    if (!reset && !_hasMore) return;

    setState(() => _isLoading = true);

    List<Reminder> pageReminders = [];
    try {
      pageReminders = await _db.remindersByContactPaged(
        widget.contact.id!,
        limit: _pageSize,
        offset: _page * _pageSize,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить напоминания: $e')),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      if (reset) {
        _reminders = [...pageReminders];
        _page = 1;
        _hasMore = pageReminders.length >= _pageSize;
      } else {
        final existingIds = _reminders.map((e) => e.id).toSet();
        final unique = pageReminders.where((n) => !existingIds.contains(n.id)).toList();
        _reminders.addAll(unique);
        _page++;
        if (pageReminders.length < _pageSize) _hasMore = false;
      }
      _isLoading = false;
      _initialLoaded = true;
      _rebuildSorted();
    });
  }

  void _rebuildSorted() {
    final list = [..._reminders];
    switch (_sort) {
      case SortRemindersOption.dueAsc:
        list.sort((a, b) => a.dueAt.compareTo(b.dueAt));
        break;
      case SortRemindersOption.dueDesc:
        list.sort((a, b) => b.dueAt.compareTo(a.dueAt));
        break;
    }
    _sortedReminders = list;
  }

  Future<void> _openSort() async {
    final result = await showModalBottomSheet<SortRemindersOption>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SortRemindersOption>(
                title: const Text('Сначала ближайшие'),
                value: SortRemindersOption.dueAsc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
              RadioListTile<SortRemindersOption>(
                title: const Text('Сначала поздние'),
                value: SortRemindersOption.dueDesc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && result != _sort) {
      setState(() {
        _sort = result;
        _rebuildSorted();
      });
    }
  }

  Future<void> _onAddReminder() async {
    if (widget.contact.id == null) return;
    final reminder = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(contactId: widget.contact.id!),
      ),
    );
    if (reminder != null) {
      setState(() {
        _reminders.add(reminder);
        _rebuildSorted();
      });
      widget.onReminderChanged?.call(reminder);
    }
  }

  Future<void> _openReminder(Reminder reminder) async {
    if (reminder.id == null) return;
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderDetailsScreen(reminder: reminder),
      ),
    );
    if (result == null) return;

    if (result['deleted'] is Reminder) {
      setState(() {
        _reminders.removeWhere((r) => r.id == reminder.id);
        _rebuildSorted();
      });
      widget.onReminderChanged?.call(reminder);
    } else if (result['updated'] is Reminder) {
      final updated = result['updated'] as Reminder;
      final index = _reminders.indexWhere((r) => r.id == updated.id);
      if (index >= 0) {
        setState(() {
          _reminders[index] = updated;
          _rebuildSorted();
        });
      }
      widget.onReminderChanged?.call(updated);
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    if (reminder.id == null) return;
    final confirm = await showDialog<bool>(
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
    if (confirm != true) return;

    await ContactDatabase.instance.deleteReminder(reminder.id!);
    if (!mounted) return;

    setState(() {
      _reminders.removeWhere((r) => r.id == reminder.id);
      _rebuildSorted();
    });
    widget.onReminderChanged?.call(reminder);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Напоминания'),
        actions: [
          IconButton(
            tooltip: 'Сортировка',
            icon: const Icon(Icons.sort),
            onPressed: _openSort,
          ),
        ],
      ),
      floatingActionButton: widget.contact.id == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _onAddReminder,
              icon: const Icon(Icons.add_alarm),
              label: const Text('Напоминание'),
            ),
      body: RefreshIndicator(
        onRefresh: () => _loadReminders(reset: true),
        child: _initialLoaded && _sortedReminders.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Напоминаний пока нет')),
                  SizedBox(height: 120),
                ],
              )
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _sortedReminders.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _sortedReminders.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final reminder = _sortedReminders[index];
                  final title = (reminder.text ?? '').trim().isEmpty
                      ? 'Без описания'
                      : reminder.text!.trim();
                  final due = df.format(reminder.dueAt);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.alarm),
                      title: Text(title),
                      subtitle: Text(due),
                      onTap: () => _openReminder(reminder),
                      trailing: IconButton(
                        tooltip: 'Удалить',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteReminder(reminder),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
