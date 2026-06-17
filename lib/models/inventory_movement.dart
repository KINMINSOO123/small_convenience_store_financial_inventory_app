class InventoryMovement {
  InventoryMovement({
    required this.id,
    required this.itemId,
    this.batchId,
    required this.movementType,
    required this.quantity,
    required this.unitCost,
    required this.movementDate,
    required this.referenceType,
    required this.referenceId,
  });

  final int id;
  final int itemId;
  final int? batchId;
  final String movementType;
  final int quantity;
  final double unitCost;
  final DateTime movementDate;
  final String referenceType;
  final int referenceId;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'item_id': itemId,
      'batch_id': batchId,
      'movement_type': movementType,
      'quantity': quantity,
      'unit_cost': unitCost,
      'movement_date': movementDate.toIso8601String(),
      'reference_type': referenceType,
      'reference_id': referenceId,
    };
  }

  factory InventoryMovement.fromMap(Map<String, Object?> map) {
    return InventoryMovement(
      id: (map['id'] as int?) ?? 0,
      itemId: (map['item_id'] as int?) ?? 0,
      batchId: map['batch_id'] as int?,
      movementType: (map['movement_type'] as String?) ?? '',
      quantity: (map['quantity'] as int?) ?? 0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
      movementDate:
          DateTime.parse((map['movement_date'] as String?) ?? ''),
      referenceType: (map['reference_type'] as String?) ?? '',
      referenceId: (map['reference_id'] as int?) ?? 0,
    );
  }
}
