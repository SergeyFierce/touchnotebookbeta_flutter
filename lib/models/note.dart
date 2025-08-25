class Note {
  final int? id;
  final int contactId;
  final String text;
  final DateTime createdAt;

  Note({this.id, required this.contactId, required this.text, required this.createdAt});

  Note copyWith({int? id}) => Note(
        id: id ?? this.id,
        contactId: contactId,
        text: text,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'contactId': contactId,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as int?,
        contactId: map['contactId'] as int,
        text: map['text'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );
}
