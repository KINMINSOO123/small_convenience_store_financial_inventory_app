class PurchaseEntry {
  PurchaseEntry({
    required this.id,
    required this.purchaseDate,
    required this.status,
    this.memo,
    this.cancelReason,
  });

  final int id;
  final DateTime purchaseDate;
  final String? memo;
  final String status;
  final String? cancelReason;

  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'purchase_date': purchaseDate.toIso8601String(),
      'memo': memo,
      'status': status,
      'cancel_reason': cancelReason,
    };
  }

  factory PurchaseEntry.fromMap(Map<String, Object?> map) {
    return PurchaseEntry(
      id: (map['id'] as int?) ?? 0,
      purchaseDate: DateTime.parse((map['purchase_date'] as String?) ?? ''),
      memo: map['memo'] as String?,
      status: (map['status'] as String?) ?? 'ACTIVE',
      cancelReason: map['cancel_reason'] as String?,
    );
  }
}
