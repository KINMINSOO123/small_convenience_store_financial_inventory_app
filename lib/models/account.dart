class Account {
  Account({
    required this.id,
    required this.name,
    required this.type,
  });

  final int id;
  final String name;
  final String type;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'name': name,
      'type': type,
    };
  }

  factory Account.fromMap(Map<String, Object?> map) {
    return Account(
      id: (map['id'] as int?) ?? 0,
      name: (map['name'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'expense',
    );
  }
}
