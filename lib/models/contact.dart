class Contact {
  final String name;
  final String status;
  final List<String> tags;
  final DateTime createdAt;

  const Contact({
    required this.name,
    required this.status,
    this.tags = const [],
    required this.createdAt,
  });
}
