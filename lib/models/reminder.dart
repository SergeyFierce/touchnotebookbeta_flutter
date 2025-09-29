class Reminder {
  final int? id;
  final int contactId;
  final String text;
  final DateTime remindAt;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Reminder({
    this.id,
    required this.contactId,
    required this.text,
    required this.remindAt,
    required this.createdAt,
    this.completedAt,
  });

  Reminder copyWith({
    int? id,
    int? contactId,
    String? text,
    DateTime? remindAt,
    DateTime? createdAt,
    Object? completedAt = _sentinel,
  }) =>
      Reminder(
        id: id ?? this.id,
        contactId: contactId ?? this.contactId,
        text: text ?? this.text,
        remindAt: remindAt ?? this.remindAt,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt == _sentinel
            ? this.completedAt
            : completedAt as DateTime?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'contactId': contactId,
        'text': text,
        'remindAt': remindAt.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'completedAt': completedAt?.millisecondsSinceEpoch,
      };

  factory Reminder.fromMap(Map<String, Object?> map) => Reminder(
        id: map['id'] as int?,
        contactId: map['contactId'] as int,
        text: map['text'] as String,
        remindAt:
            DateTime.fromMillisecondsSinceEpoch(map['remindAt'] as int),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        completedAt: map['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
            : null,
      );
}

const _sentinel = Object();
