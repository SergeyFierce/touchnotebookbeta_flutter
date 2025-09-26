class Reminder {
  final int? id;
  final int contactId;
  final String title;
  final DateTime scheduledDateTime;

  const Reminder({
    this.id,
    required this.contactId,
    required this.title,
    required this.scheduledDateTime,
  });

  Reminder copyWith({
    int? id,
    int? contactId,
    String? title,
    DateTime? scheduledDateTime,
  }) {
    return Reminder(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      title: title ?? this.title,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'contactId': contactId,
        'title': title,
        'scheduledDateTime': scheduledDateTime.millisecondsSinceEpoch,
      };

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
        id: map['id'] as int?,
        contactId: map['contactId'] as int,
        title: map['title'] as String,
        scheduledDateTime:
            DateTime.fromMillisecondsSinceEpoch(map['scheduledDateTime'] as int),
      );
}
