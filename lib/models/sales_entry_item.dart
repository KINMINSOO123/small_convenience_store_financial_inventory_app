class SalesEntryItem {
  SalesEntryItem({
    required this.id,
    required this.salesId,
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.costOfGoodsSold,
  });

  final int id;
  final int salesId;
  final int itemId;
  final int quantity;
  final double unitPrice;
  final double costOfGoodsSold;

  double get subtotal => quantity * unitPrice;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'sales_id': salesId,
      'item_id': itemId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cost_of_goods_sold': costOfGoodsSold,
      'subtotal': subtotal,
    };
  }

  factory SalesEntryItem.fromMap(Map<String, Object?> map) {
    return SalesEntryItem(
      id: (map['id'] as int?) ?? 0,
      salesId: (map['sales_id'] as int?) ?? 0,
      itemId: (map['item_id'] as int?) ?? 0,
      quantity: (map['quantity'] as int?) ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      costOfGoodsSold: (map['cost_of_goods_sold'] as num?)?.toDouble() ?? 0,
    );
  }
  
}
