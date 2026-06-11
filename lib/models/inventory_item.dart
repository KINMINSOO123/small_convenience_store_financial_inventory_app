class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.sellingPrice,
    required this.lowStockThreshold,
  });

  final int id;
  final String name;
  final String category;
  final int quantity;
  final double sellingPrice;
  final int lowStockThreshold;

  double get totalValue => quantity * sellingPrice;
  bool get isLowStock => quantity <= lowStockThreshold;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'selling_price': sellingPrice,
      'low_stock_threshold': lowStockThreshold,
    };
  }

  factory InventoryItem.fromMap(Map<String, Object?> map) {
    final sellingPrice =
        (map['selling_price'] as num?)?.toDouble() ??
        (map['unit_cost'] as num?)?.toDouble() ??
        0;
    return InventoryItem(
      id: (map['id'] as int?) ?? 0,
      name: (map['name'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      quantity: (map['quantity'] as int?) ?? 0,
      sellingPrice: sellingPrice,
      lowStockThreshold: (map['low_stock_threshold'] as int?) ?? 5,
    );
  }
}
