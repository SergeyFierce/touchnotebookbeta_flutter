import '../models/reminder.dart';
import 'contact_database.dart';
import 'reminder_notification_service.dart';

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final ContactDatabase _db = ContactDatabase.instance;
  final ReminderNotificationService _notifications = ReminderNotificationService.instance;

  Future<Reminder> createReminder({
    required int contactId,
    required String text,
    required DateTime scheduledTime,
  }) async {
    final reminder = Reminder(contactId: contactId, text: text.trim(), scheduledTime: scheduledTime);
    final id = await _db.insertReminder(reminder);
    final saved = reminder.copyWith(id: id);
    await _notifications.scheduleReminder(saved);
    return saved;
  }

  Future<List<Reminder>> remindersByContact(int contactId) {
    return _db.remindersByContact(contactId);
  }

  Future<void> deleteReminder(Reminder reminder) async {
    if (reminder.id != null) {
      await _notifications.cancelReminder(reminder.id!);
      await _db.deleteReminder(reminder.id!);
    }
  }

  Future<void> deleteRemindersByContact(int contactId) async {
    final reminders = await _db.remindersByContact(contactId);
    final ids = reminders.map((r) => r.id).whereType<int>().toList();
    if (ids.isNotEmpty) {
      await _notifications.cancelReminders(ids);
    }
    // Удалять вручную не нужно — каскад сделает это сам, но вызовем для верности.
    for (final id in ids) {
      await _db.deleteReminder(id);
    }
  }

  Future<List<Reminder>> snapshotAndCancelByContact(int contactId) async {
    final reminders = await _db.remindersByContact(contactId);
    final ids = reminders.map((r) => r.id).whereType<int>().toList();
    if (ids.isNotEmpty) {
      await _notifications.cancelReminders(ids);
    }
    return reminders;
  }

  Future<void> rescheduleAllUpcoming() async {
    final reminders = await _db.remindersScheduledAfter(DateTime.now());
    for (final reminder in reminders) {
      await _notifications.scheduleReminder(reminder);
    }
  }

  Future<void> restoreReminders(int newContactId, List<Reminder> reminders) async {
    for (final reminder in reminders) {
      final restored = reminder.copyWith(id: null, contactId: newContactId);
      await createReminder(
        contactId: restored.contactId,
        text: restored.text,
        scheduledTime: restored.scheduledTime,
      );
    }
  }
}
