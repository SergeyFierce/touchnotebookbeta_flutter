class Reminder {
  final int? id;
  final int contactId;
  final String title;
  final DateTime remindAt;
  final bool isCompleted;
  final DateTime createdAt;

  const Reminder({
    this.id,
    required this.contactId,
    required this.title,
    required this.remindAt,
    this.isCompleted = false,
    required this.createdAt,
  });

  Reminder copyWith({
    int? id,
    int? contactId,
    String? title,
    DateTime? remindAt,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      title: title ?? this.title,
      remindAt: remindAt ?? this.remindAt,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'contactId': contactId,
        'title': title,
        'remindAt': remindAt.millisecondsSinceEpoch,
        'isCompleted': isCompleted ? 1 : 0,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
        id: map['id'] as int?,
        contactId: map['contactId'] as int,
        title: map['title'] as String,
        remindAt: DateTime.fromMillisecondsSinceEpoch(map['remindAt'] as int),
        isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );
}
