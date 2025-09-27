import 'package:intl/intl.dart';

import '../models/contact.dart';
import '../models/reminder.dart';
import 'push_notifications.dart';

class ReminderNotifications {
  ReminderNotifications._();

  static String _defaultBody(Reminder reminder, Contact contact) {
    final formatter = DateFormat('d MMMM, HH:mm', 'ru');
    final when = formatter.format(reminder.remindAt);
    return 'Свяжитесь с ${contact.name} ($when)';
  }

  static Future<void> schedule(Reminder reminder, Contact contact) async {
    if (reminder.id == null) return;
    final body = (reminder.note != null && reminder.note!.trim().isNotEmpty)
        ? reminder.note!.trim()
        : _defaultBody(reminder, contact);

    await PushNotifications.scheduleOneTime(
      id: Reminder.notificationId(reminder.id!),
      whenLocal: reminder.remindAt,
      title: 'Напоминание: ${contact.name}',
      body: body,
      exact: true,
    );
  }

  static Future<void> cancel(Reminder reminder) async {
    if (reminder.id == null) return;
    await PushNotifications.cancel(Reminder.notificationId(reminder.id!));
  }
}
