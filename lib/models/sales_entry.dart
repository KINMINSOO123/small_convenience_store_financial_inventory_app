class SalesEntry {
  SalesEntry({
    required this.id,
    required this.salesDate,
    required this.memo,
    required this.amount,
  });

  final int id;
  final DateTime salesDate;
  final String memo;
  final double amount;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'sales_date': salesDate.toIso8601String(),
      'memo': memo,
      'amount': amount,
    };
  }

  factory SalesEntry.fromMap(Map<String, Object?> map) {
    return SalesEntry(
      id: (map['id'] as int?) ?? 0,
      salesDate: DateTime.parse((map['sales_date'] as String?) ?? ''),
      memo: (map['memo'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
