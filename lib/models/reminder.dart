class Reminder {
  final int? id;
  final int contactId;
  final String text;
  final DateTime scheduledAt;
  final DateTime createdAt;

  const Reminder({
    this.id,
    required this.contactId,
    required this.text,
    required this.scheduledAt,
    required this.createdAt,
  });

  Reminder copyWith({
    int? id,
    int? contactId,
    String? text,
    DateTime? scheduledAt,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      text: text ?? this.text,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'contactId': contactId,
        'text': text,
        'scheduledAt': scheduledAt.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int?,
      contactId: map['contactId'] as int,
      text: map['text'] as String,
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(map['scheduledAt'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

class ReminderScheduleInfo {
  final Reminder reminder;
  final String contactName;

  const ReminderScheduleInfo({
    required this.reminder,
    required this.contactName,
  });
}
