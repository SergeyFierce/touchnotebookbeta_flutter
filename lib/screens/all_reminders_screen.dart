import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reminder.dart';
import '../models/reminder_with_contact_info.dart';
import '../services/contact_database.dart';

class AllRemindersScreen extends StatefulWidget {
  const AllRemindersScreen({super.key});

  @override
  State<AllRemindersScreen> createState() => _AllRemindersScreenState();
}

class _AllRemindersScreenState extends State<AllRemindersScreen> {
  final _db = ContactDatabase.instance;
  late final VoidCallback _revisionListener;
  Timer? _timeTicker;

  bool _loading = true;
  Object? _error;
  List<_ReminderGroup> _groups = const [];

  @override
  void initState() {
    super.initState();
    _revisionListener = () => _load(showSpinner: false);
    _db.revision.addListener(_revisionListener);
    _scheduleTick();
    _load();
  }

  @override
  void dispose() {
    _db.revision.removeListener(_revisionListener);
    _timeTicker?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final reminders = await _db.remindersWithContactInfo();
      final now = DateTime.now();
      final activeReminders = reminders.where((entry) {
        final reminder = entry.reminder;
        final isCompleted = reminder.completedAt != null;
        final isInFuture = !reminder.remindAt.isBefore(now);
        return !isCompleted && isInFuture;
      }).toList(growable: false);
      final groups = _groupByDate(activeReminders);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load reminders: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<_ReminderGroup> _groupByDate(List<ReminderWithContactInfo> reminders) {
    if (reminders.isEmpty) return const [];

    final sorted = reminders.toList()
      ..sort((a, b) {
        final dateA = DateUtils.dateOnly(a.reminder.remindAt);
        final dateB = DateUtils.dateOnly(b.reminder.remindAt);
        final cmp = dateA.compareTo(dateB);
        if (cmp != 0) return cmp;
        return a.reminder.remindAt.compareTo(b.reminder.remindAt);
      });

    final groups = <_ReminderGroup>[];
    DateTime? currentDate;
    var bucket = <ReminderWithContactInfo>[];

    for (final entry in sorted) {
      final date = DateUtils.dateOnly(entry.reminder.remindAt);
      if (currentDate == null || date != currentDate) {
        if (currentDate != null && bucket.isNotEmpty) {
          groups.add(
            _ReminderGroup(date: currentDate, reminders: List.unmodifiable(bucket)),
          );
          bucket = <ReminderWithContactInfo>[];
        }
        currentDate = date;
      }
      bucket.add(entry);
    }

    if (currentDate != null && bucket.isNotEmpty) {
      groups.add(
        _ReminderGroup(date: currentDate, reminders: List.unmodifiable(bucket)),
      );
    }

    return List.unmodifiable(groups);
  }

  Future<void> _onRefresh() => _load(showSpinner: false);

  void _scheduleTick() {
    _timeTicker?.cancel();
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    final delay = nextMinute.difference(now);
    _timeTicker = Timer(delay, () {
      if (!mounted) return;
      unawaited(
        _load(showSpinner: false).whenComplete(() {
          if (!mounted) return;
          _scheduleTick();
        }),
      );
    });
  }

  String _formatGroupLabel(DateTime date, DateFormat formatter) {
    final today = DateUtils.dateOnly(DateTime.now());
    final normalized = DateUtils.dateOnly(date);
    final tomorrow = DateUtils.addDaysToDate(today, 1);
    final formatted = formatter.format(normalized);

    if (normalized == today) {
      return 'Сегодня, $formatted';
    }
    if (normalized == tomorrow) {
      return 'Завтра, $formatted';
    }
    return toBeginningOfSentenceCase(formatted) ?? formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Все напоминания'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Не удалось загрузить напоминания',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 120),
          children: const [
            Center(child: Icon(Icons.notifications_off_outlined, size: 40)),
            SizedBox(height: 12),
            Center(child: Text('Напоминаний пока нет')),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final dateFormatter = DateFormat.yMMMMd('ru');
    final timeFormatter = DateFormat('HH:mm', 'ru');
    final completedFormatter = DateFormat('d MMMM, HH:mm', 'ru');

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final group in _groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                _formatGroupLabel(group.date, dateFormatter),
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final item in group.reminders)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  child: ListTile(
                    leading: _ReminderStatusIcon(reminder: item.reminder),
                    title: Text(item.reminder.text),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.contactName),
                        const SizedBox(height: 4),
                        Text(
                          '${timeFormatter.format(item.reminder.remindAt)} • ${item.contactCategory}',
                        ),
                        if (item.reminder.completedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Завершено: ${completedFormatter.format(item.reminder.completedAt!)}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ReminderGroup {
  final DateTime date;
  final List<ReminderWithContactInfo> reminders;

  const _ReminderGroup({required this.date, required this.reminders});
}

class _ReminderStatusIcon extends StatelessWidget {
  const _ReminderStatusIcon({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCompleted = reminder.completedAt != null;
    final now = DateTime.now();
    final isOverdue = !isCompleted && reminder.remindAt.isBefore(now);

    late final IconData icon;
    late final Color color;

    if (isCompleted) {
      icon = Icons.check_circle;
      color = scheme.secondary;
    } else if (isOverdue) {
      icon = Icons.notification_important_outlined;
      color = scheme.error;
    } else {
      icon = Icons.notifications_active_outlined;
      color = scheme.primary;
    }

    return Icon(icon, color: color);
  }
}
