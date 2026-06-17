class SupplierReturnItem {
  SupplierReturnItem({
    required this.id,
    required this.returnId,
    required this.itemId,
    required this.purchaseItemId,
    required this.quantity,
    required this.unitCost,
  });

  final int id;
  final int returnId;
  final int itemId;
  final int purchaseItemId;
  final int quantity;
  final double unitCost;

  double get subtotal => quantity * unitCost;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'return_id': returnId,
      'item_id': itemId,
      'purchase_item_id': purchaseItemId,
      'quantity': quantity,
      'unit_cost': unitCost,
    };
  }

  factory SupplierReturnItem.fromMap(Map<String, Object?> map) {
    return SupplierReturnItem(
      id: (map['id'] as int?) ?? 0,
      returnId: (map['return_id'] as int?) ?? 0,
      itemId: (map['item_id'] as int?) ?? 0,
      purchaseItemId: (map['purchase_item_id'] as int?) ?? 0,
      quantity: (map['quantity'] as int?) ?? 0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
    );
  }
}
