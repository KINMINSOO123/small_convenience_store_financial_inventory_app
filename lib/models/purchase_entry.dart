class PurchaseEntry {
  PurchaseEntry({
    required this.id,
    required this.purchasedAt,
    required this.status,
    this.memo,
    this.cancelReason,
  });

  final int id;
  final DateTime purchasedAt;
  final String? memo;
  final String status;
  final String? cancelReason;

  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'purchased_at': purchasedAt.toIso8601String(),
      'memo': memo,
      'status': status,
      'cancel_reason': cancelReason,
    };
  }

  factory PurchaseEntry.fromMap(Map<String, Object?> map) {
    return PurchaseEntry(
      id: (map['id'] as int?) ?? 0,
      purchasedAt: DateTime.parse((map['purchased_at'] as String?) ?? ''),
      memo: map['memo'] as String?,
      status: (map['status'] as String?) ?? 'ACTIVE',
      cancelReason: map['cancel_reason'] as String?,
    );
  }
}
