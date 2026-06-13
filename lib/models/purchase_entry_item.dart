class PurchaseEntryItem {
  PurchaseEntryItem({
    required this.id,
    required this.purchaseId,
    required this.itemId,
    required this.quantity,
    required this.unitCost,
    this.expiryDate,
  });

  final int id;
  final int purchaseId;
  final int itemId;
  final int quantity;
  final double unitCost;
  final DateTime? expiryDate;

  double get subtotal => quantity * unitCost;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'purchase_id': purchaseId,
      'item_id': itemId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'expiry_date': expiryDate?.toIso8601String(),
    };
  }

  factory PurchaseEntryItem.fromMap(Map<String, Object?> map) {
    final rawExpiry = map['expiry_date'] as String?;
    return PurchaseEntryItem(
      id: (map['id'] as int?) ?? 0,
      purchaseId: (map['purchase_id'] as int?) ?? 0,
      itemId: (map['item_id'] as int?) ?? 0,
      quantity: (map['quantity'] as int?) ?? 0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
      expiryDate: rawExpiry == null ? null : DateTime.tryParse(rawExpiry),
    );
  }
}
