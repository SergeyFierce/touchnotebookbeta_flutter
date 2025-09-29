import 'reminder.dart';

class ReminderWithContactInfo {
  final Reminder reminder;
  final String contactName;
  final String contactCategory;

  const ReminderWithContactInfo({
    required this.reminder,
    required this.contactName,
    required this.contactCategory,
  });
}
