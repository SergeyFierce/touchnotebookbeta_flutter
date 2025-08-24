class Contact {
  final int? id;
  final String name;
  final DateTime? birthDate;
  final int? ageManual;
  final String? profession;
  final String? city;
  final String phone;
  final String? email;
  final String? social;
  final String category;
  final String status;
  final List<String> tags;
  final String? comment;
  final DateTime createdAt;

  const Contact({
    this.id,
    required this.name,
    this.birthDate,
    this.ageManual,
    this.profession,
    this.city,
    required this.phone,
    this.email,
    this.social,
    required this.category,
    required this.status,
    this.tags = const [],
    this.comment,
    required this.createdAt,
  });

  Contact copyWith({int? id}) => Contact(
        id: id ?? this.id,
        name: name,
        birthDate: birthDate,
        ageManual: ageManual,
        profession: profession,
        city: city,
        phone: phone,
        email: email,
        social: social,
        category: category,
        status: status,
        tags: tags,
        comment: comment,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'birthDate': birthDate?.millisecondsSinceEpoch,
        'ageManual': ageManual,
        'profession': profession,
        'city': city,
        'phone': phone,
        'email': email,
        'social': social,
        'category': category,
        'status': status,
        'tags': tags.join(','),
        'comment': comment,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
        id: map['id'] as int?,
        name: map['name'] as String,
        birthDate: map['birthDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['birthDate'] as int)
            : null,
        ageManual: map['ageManual'] as int?,
        profession: map['profession'] as String?,
        city: map['city'] as String?,
        phone: map['phone'] as String,
        email: map['email'] as String?,
        social: map['social'] as String?,
        category: map['category'] as String,
        status: map['status'] as String,
        tags: (map['tags'] as String?)?.split(',').where((e) => e.isNotEmpty).toList() ?? [],
        comment: map['comment'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );
}
