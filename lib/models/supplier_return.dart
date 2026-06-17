class SupplierReturn {
  SupplierReturn({
    required this.id,
    required this.returnDate,
    required this.purchaseId,
    this.memo,
    required this.totalAmount,
  });

  final int id;
  final DateTime returnDate;
  final int purchaseId;
  final String? memo;
  final double totalAmount;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'return_date': returnDate.toIso8601String(),
      'purchase_id': purchaseId,
      'memo': memo,
      'total_amount': totalAmount,
    };
  }

  factory SupplierReturn.fromMap(Map<String, Object?> map) {
    return SupplierReturn(
      id: (map['id'] as int?) ?? 0,
      returnDate: DateTime.parse((map['return_date'] as String?) ?? ''),
      purchaseId: (map['purchase_id'] as int?) ?? 0,
      memo: map['memo'] as String?,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
