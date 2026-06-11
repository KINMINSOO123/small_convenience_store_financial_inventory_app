class JournalLine {
  JournalLine({
    required this.id,
    required this.entryId,
    required this.accountId,
    required this.debit,
    required this.credit,
  });

  final int id;
  final int entryId;
  final int accountId;
  final double debit;
  final double credit;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'entry_id': entryId,
      'account_id': accountId,
      'debit': debit,
      'credit': credit,
    };
  }

  factory JournalLine.fromMap(Map<String, Object?> map) {
    return JournalLine(
      id: (map['id'] as int?) ?? 0,
      entryId: (map['entry_id'] as int?) ?? 0,
      accountId: (map['account_id'] as int?) ?? 0,
      debit: (map['debit'] as num?)?.toDouble() ?? 0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0,
    );
  }
}
