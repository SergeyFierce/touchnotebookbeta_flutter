class Reminder {
  final int? id;
  final int contactId;
  final DateTime remindAt;
  final String? note;
  final DateTime createdAt;

  const Reminder({
    this.id,
    required this.contactId,
    required this.remindAt,
    this.note,
    required this.createdAt,
  });

  Reminder copyWith({
    int? id,
    int? contactId,
    DateTime? remindAt,
    String? note,
    DateTime? createdAt,
  }) =>
      Reminder(
        id: id ?? this.id,
        contactId: contactId ?? this.contactId,
        remindAt: remindAt ?? this.remindAt,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'contactId': contactId,
        'remindAt': remindAt.millisecondsSinceEpoch,
        'note': note,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
        id: map['id'] as int?,
        contactId: map['contactId'] as int,
        remindAt: DateTime.fromMillisecondsSinceEpoch(map['remindAt'] as int),
        note: map['note'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );

  static int notificationId(int reminderId) => 200000 + reminderId;
}
