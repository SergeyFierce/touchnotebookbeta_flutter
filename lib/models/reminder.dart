class Reminder {
  final int? id;
  final int contactId;
  final String text;
  final DateTime remindAt;
  final DateTime createdAt;

  const Reminder({
    this.id,
    required this.contactId,
    required this.text,
    required this.remindAt,
    required this.createdAt,
  });

  Reminder copyWith({
    int? id,
    int? contactId,
    String? text,
    DateTime? remindAt,
    DateTime? createdAt,
  }) =>
      Reminder(
        id: id ?? this.id,
        contactId: contactId ?? this.contactId,
        text: text ?? this.text,
        remindAt: remindAt ?? this.remindAt,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'contactId': contactId,
        'text': text,
        'remindAt': remindAt.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Reminder.fromMap(Map<String, Object?> map) => Reminder(
        id: map['id'] as int?,
        contactId: map['contactId'] as int,
        text: map['text'] as String,
        remindAt:
            DateTime.fromMillisecondsSinceEpoch(map['remindAt'] as int),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );
}
