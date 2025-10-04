import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder_with_contact_info.dart';
import 'contact_database.dart';
import 'push_notifications.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._(
    this._themeMode,
    this._notificationsEnabled,
    this._policiesAccepted,
  );

  static const _themeKey = 'app_theme_mode';
  static const _notificationsKey = 'app_notifications_enabled';
  static const _policiesAcceptedKey = 'app_policies_accepted';

  ThemeMode _themeMode;
  bool _notificationsEnabled;
  bool _policiesAccepted;

  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get policiesAccepted => _policiesAccepted;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedTheme = prefs.getString(_themeKey);
    final themeMode = switch (storedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
    final notificationsEnabled =
        prefs.getBool(_notificationsKey) ?? true;
    final policiesAccepted =
        prefs.getBool(_policiesAcceptedKey) ?? false;

    final settings = AppSettings._(
      themeMode,
      notificationsEnabled,
      policiesAccepted,
    );
    PushNotifications.setEnabled(notificationsEnabled);
    return settings;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeKey, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);

    PushNotifications.setEnabled(value);
    if (!value) {
      await PushNotifications.cancelAll();
      return;
    }

    unawaited(_rescheduleActiveReminders());
  }

  Future<void> setPoliciesAccepted(bool value) async {
    if (_policiesAccepted == value) return;
    _policiesAccepted = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_policiesAcceptedKey, value);
  }

  Future<void> _rescheduleActiveReminders() async {
    final reminders = await ContactDatabase.instance.remindersWithContactInfo();
    final now = DateTime.now();
    final active = reminders.where((entry) {
      final reminder = entry.reminder;
      final isCompleted = reminder.completedAt != null;
      final isFuture = !reminder.remindAt.isBefore(now);
      return !isCompleted && isFuture;
    });

    for (final ReminderWithContactInfo entry in active) {
      final reminder = entry.reminder;
      if (reminder.id == null) continue;
      await PushNotifications.scheduleOneTime(
        id: reminder.id!,
        whenLocal: reminder.remindAt,
        title: 'Напоминание: ${entry.contactName}',
        body: reminder.text,
        reminderActions: true,
      );
    }
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope not found in widget tree');
    return scope!.notifier!;
  }
}
