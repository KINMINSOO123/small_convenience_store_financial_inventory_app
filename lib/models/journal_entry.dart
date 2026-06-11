class JournalEntry {
  JournalEntry({
    required this.id,
    required this.date,
    required this.memo,
    required this.total,
    required this.type,
  });

  final int id;
  final DateTime date;
  final String memo;
  final double total;
  final String type;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'entry_date': date.toIso8601String(),
      'memo': memo,
      'total': total,
      'type': type,
    };
  }

  factory JournalEntry.fromMap(Map<String, Object?> map) {
    return JournalEntry(
      id: (map['id'] as int?) ?? 0,
      date: DateTime.parse((map['entry_date'] as String?) ?? ''),
      memo: (map['memo'] as String?) ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0,
      type: (map['type'] as String?) ?? 'EXPENSE',
    );
  }
}
