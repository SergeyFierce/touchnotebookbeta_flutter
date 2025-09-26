import 'package:flutter/foundation.dart';

@immutable
class Reminder {
  final int? id;
  final int contactId;
  final String text;
  final DateTime scheduledTime;

  const Reminder({
    this.id,
    required this.contactId,
    required this.text,
    required this.scheduledTime,
  });

  Reminder copyWith({
    int? id,
    int? contactId,
    String? text,
    DateTime? scheduledTime,
  }) {
    return Reminder(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      text: text ?? this.text,
      scheduledTime: scheduledTime ?? this.scheduledTime,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'contactId': contactId,
        'text': text,
        'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      };

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
        id: map['id'] as int?,
        contactId: map['contactId'] as int,
        text: map['text'] as String,
        scheduledTime: DateTime.fromMillisecondsSinceEpoch(map['scheduledTime'] as int),
      );
}
