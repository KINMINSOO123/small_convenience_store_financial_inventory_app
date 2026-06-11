class StockBatch {
  StockBatch({
    required this.id,
    required this.itemId,
    required this.purchaseId,
    required this.receivedAt,
    required this.quantity,
    required this.remainingQuantity,
    required this.unitCost,
    this.expiryDate,
  });

  final int id;
  final int itemId;
  final int? purchaseId;
  final DateTime receivedAt;
  final int quantity;
  final int remainingQuantity;
  final double unitCost;
  final DateTime? expiryDate;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'item_id': itemId,
      'purchase_id': purchaseId,
      'received_at': receivedAt.toIso8601String(),
      'quantity': quantity,
      'remaining_qty': remainingQuantity,
      'unit_cost': unitCost,
      'expiry_date': expiryDate?.toIso8601String(),
    };
  }

  factory StockBatch.fromMap(Map<String, Object?> map) {
    final rawExpiry = map['expiry_date'] as String?;
    return StockBatch(
      id: (map['id'] as int?) ?? 0,
      itemId: (map['item_id'] as int?) ?? 0,
      purchaseId: map['purchase_id'] as int?,
      receivedAt: DateTime.parse((map['received_at'] as String?) ?? ''),
      quantity: (map['quantity'] as int?) ?? 0,
      remainingQuantity: (map['remaining_qty'] as int?) ?? 0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
      expiryDate: rawExpiry == null ? null : DateTime.tryParse(rawExpiry),
    );
  }
}
