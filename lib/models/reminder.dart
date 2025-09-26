class Reminder {
  final int? id;
  final int contactId;
  final DateTime dueAt;
  final String? text;

  const Reminder({
    this.id,
    required this.contactId,
    required this.dueAt,
    this.text,
  });

  Reminder copyWith({
    int? id,
    int? contactId,
    DateTime? dueAt,
    String? text,
  }) {
    return Reminder(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      dueAt: dueAt ?? this.dueAt,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'contactId': contactId,
        'dueAt': dueAt.millisecondsSinceEpoch,
        'text': text,
      };

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
        id: map['id'] as int?,
        contactId: map['contactId'] as int,
        dueAt: DateTime.fromMillisecondsSinceEpoch(map['dueAt'] as int),
        text: map['text'] as String?,
      );
}
