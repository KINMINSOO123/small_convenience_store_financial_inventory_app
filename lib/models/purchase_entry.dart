class PurchaseEntry {
  PurchaseEntry({
    required this.id,
    required this.itemId,
    required this.quantity,
    required this.unitCost,
    required this.purchasedAt,
    required this.status,
    this.expiryDate,
    this.cancelReason,
  });

  final int id;
  final int itemId;
  final int quantity;
  final double unitCost;
  final DateTime purchasedAt;
  final String status;
  final DateTime? expiryDate;
  final String? cancelReason;

  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'item_id': itemId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'purchased_at': purchasedAt.toIso8601String(),
      'status': status,
      'expiry_date': expiryDate?.toIso8601String(),
      'cancel_reason': cancelReason,
    };
  }

  factory PurchaseEntry.fromMap(Map<String, Object?> map) {
    final rawExpiry = map['expiry_date'] as String?;
    return PurchaseEntry(
      id: (map['id'] as int?) ?? 0,
      itemId: (map['item_id'] as int?) ?? 0,
      quantity: (map['quantity'] as int?) ?? 0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
      purchasedAt: DateTime.parse((map['purchased_at'] as String?) ?? ''),
      status: (map['status'] as String?) ?? 'ACTIVE',
      expiryDate: rawExpiry == null ? null : DateTime.tryParse(rawExpiry),
      cancelReason: map['cancel_reason'] as String?,
    );
  }
}
