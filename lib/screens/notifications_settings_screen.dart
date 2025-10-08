import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/contact_database.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  final _db = ContactDatabase.instance;
  late final VoidCallback _revisionListener;

  int? _activeCount;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _revisionListener = _loadActiveReminders;
    _db.revision.addListener(_revisionListener);
    _loadActiveReminders();
  }

  @override
  void dispose() {
    _db.revision.removeListener(_revisionListener);
    super.dispose();
  }

  Future<void> _loadActiveReminders() async {
    try {
      final count = await _db.activeReminderCount();
      if (!mounted) return;
      setState(() {
        _activeCount = count;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _activeCount = null;
        _loading = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (_updating) return;
    setState(() {
      _updating = true;
    });

    final settings = AppSettingsScope.of(context);
    try {
      await settings.setNotificationsEnabled(value);
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
        unawaited(_loadActiveReminders());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          final enabled = settings.notificationsEnabled;
          final count = _activeCount ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile.adaptive(
                  value: enabled,
                  onChanged: _updating ? null : _toggleNotifications,
                  title: const Text('Пуш-уведомления'),
                  subtitle: Text(
                    enabled
                        ? 'Уведомления включены'
                        : 'Уведомления выключены',
                  ),
                  secondary: Icon(
                    enabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                    color: enabled ? colorScheme.primary : colorScheme.outline,
                  ),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                const SizedBox(height: 16),
                Card(
                  color: !enabled && count > 0
                      ? colorScheme.errorContainer
                      : colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              !enabled && count > 0
                                  ? Icons.notification_important
                                  : enabled
                                      ? Icons.notifications
                                      : Icons.notifications_paused_outlined,
                              color: !enabled && count > 0
                                  ? colorScheme.onErrorContainer
                                  : colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _buildHeadline(enabled, count),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: !enabled && count > 0
                                      ? colorScheme.onErrorContainer
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _buildDescription(enabled, count),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: !enabled && count > 0
                                ? colorScheme.onErrorContainer
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_updating)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: LinearProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  String _buildHeadline(bool enabled, int count) {
    if (enabled && count > 0) {
      return 'Активных напоминаний: $count';
    }
    if (!enabled && count > 0) {
      return 'Напоминания не будут срабатывать';
    }
    return 'Активных напоминаний нет';
  }

  String _buildDescription(bool enabled, int count) {
    if (!enabled && count > 0) {
      return 'У вас запланировано $count напоминаний. Они останутся в списке, но уведомления не придут, пока вы не включите опцию.';
    }
    if (enabled && count > 0) {
      return 'Мы напомним вам о каждом событии вовремя. При необходимости вы можете управлять напоминаниями в карточках контактов.';
    }
    return 'Создавайте напоминания у контактов, чтобы приложение подсказывало о важных событиях.';
  }
}
