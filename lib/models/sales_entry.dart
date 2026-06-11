class SalesEntry {
  SalesEntry({
    required this.id,
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.date,
    required this.memo,
  });

  final int id;
  final int itemId;
  final int quantity;
  final double unitPrice;
  final DateTime date;
  final String memo;

  double get amount => quantity * unitPrice;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'item_id': itemId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'entry_date': date.toIso8601String(),
      'amount': amount,
      'memo': memo,
    };
  }

  factory SalesEntry.fromMap(Map<String, Object?> map) {
    return SalesEntry(
      id: (map['id'] as int?) ?? 0,
      itemId: (map['item_id'] as int?) ?? 0,
      quantity: (map['quantity'] as int?) ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ??
          (map['amount'] as num?)?.toDouble() ??
          0,
      date: DateTime.parse((map['entry_date'] as String?) ?? ''),
      memo: (map['memo'] as String?) ?? '',
    );
  }
}
