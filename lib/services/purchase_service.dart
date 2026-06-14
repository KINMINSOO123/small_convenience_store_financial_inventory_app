import '../models/inventory_item.dart';
import '../models/purchase_entry.dart';
import '../models/purchase_entry_item.dart';
import '../models/stock_batch.dart';
import '../repositories/purchase_repository.dart';
import 'inventory_service.dart';

class PurchaseService {
  PurchaseService(this._repository, this._inventoryService);

  final PurchaseRepository _repository;
  final InventoryService _inventoryService;
  final List<PurchaseEntry> _purchases = [];
  final List<StockBatch> _batches = [];
  final List<PurchaseEntryItem> _purchaseEntryItems = [];

  List<PurchaseEntry> get purchases => List.unmodifiable(_purchases);

  List<StockBatch> get batches => List.unmodifiable(_batches);

  List<PurchaseEntryItem> get purchaseEntryItems =>
      List.unmodifiable(_purchaseEntryItems);

  double get totalValue {
    return _batches.fold(
      0,
      (sum, batch) => sum + (batch.remainingQuantity * batch.unitCost),
    );
  }

  PurchaseEntry? findPurchaseByDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    for (final entry in _purchases) {
      final entryDate = DateTime(
        entry.purchaseDate.year,
        entry.purchaseDate.month,
        entry.purchaseDate.day,
      );
      if (entryDate == normalized && !entry.isCancelled) return entry;
    }
    return null;
  }

  Future<void> load() async {
    await _repository.init();
    final purchaseEntries = await _repository.fetchPurchases();
    final batchEntries = await _repository.fetchBatches();
    final itemEntries = await _repository.fetchPurchaseEntryItems();
    _purchases
      ..clear()
      ..addAll(purchaseEntries);
    _batches
      ..clear()
      ..addAll(batchEntries);
    _purchaseEntryItems
      ..clear()
      ..addAll(itemEntries);
  }

  Future<int> addPurchase({
    required DateTime purchaseDate,
    String? memo,
  }) async {
    final purchase = PurchaseEntry(
      id: 0,
      purchaseDate: purchaseDate,
      memo: memo,
      status: 'ACTIVE',
      cancelReason: null,
    );
    final purchaseId = await _repository.insertPurchase(purchase);
    final storedPurchase = PurchaseEntry(
      id: purchaseId,
      purchaseDate: purchaseDate,
      memo: memo,
      status: 'ACTIVE',
      cancelReason: null,
    );
    _purchases.insert(0, storedPurchase);
    return purchaseId;
  }

  Future<int> addPurchaseWithLineItem({
    required int itemId,
    required int quantity,
    required double unitCost,
    required DateTime purchaseDate,
    DateTime? expiryDate,
    String? memo,
  }) async {
    if (quantity <= 0) {
      throw StateError('Quantity must be greater than zero.');
    }
    final normalizedDate =
        DateTime(purchaseDate.year, purchaseDate.month, purchaseDate.day);
    final existing = findPurchaseByDate(normalizedDate);
    int purchaseId;
    if (existing != null) {
      purchaseId = existing.id;
    } else {
      purchaseId = await addPurchase(
        purchaseDate: normalizedDate,
        memo: memo,
      );
    }
    final lineItem = PurchaseEntryItem(
      id: 0,
      purchaseId: purchaseId,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    final lineItemId = await _repository.insertPurchaseEntryItem(lineItem);
    final storedLineItem = PurchaseEntryItem(
      id: lineItemId,
      purchaseId: purchaseId,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    _purchaseEntryItems.add(storedLineItem);

    final batch = StockBatch(
      id: 0,
      itemId: itemId,
      purchaseId: purchaseId,
      receivedAt: normalizedDate,
      quantity: quantity,
      remainingQuantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    final batchId = await _repository.insertBatch(batch);
    final storedBatch = StockBatch(
      id: batchId,
      itemId: itemId,
      purchaseId: purchaseId,
      receivedAt: normalizedDate,
      quantity: quantity,
      remainingQuantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    _batches.add(storedBatch);

    await _updateItemQuantity(itemId, quantityDelta: quantity);
    return purchaseId;
  }

  Future<void> updatePurchase({
    required PurchaseEntry existing,
    required int itemId,
    required int quantity,
    required double unitCost,
    required DateTime purchaseDate,
    DateTime? expiryDate,
    String? memo,
  }) async {
    if (quantity <= 0) {
      throw StateError('Quantity must be greater than zero.');
    }
    if (existing.isCancelled) {
      return;
    }

    await _repository.updatePurchase(
      PurchaseEntry(
        id: existing.id,
        purchaseDate: purchaseDate,
        memo: memo ?? existing.memo,
        status: 'ACTIVE',
        cancelReason: null,
      ),
    );

    final oldLineItems =
        _purchaseEntryItems.where((i) => i.purchaseId == existing.id).toList();

    await _repository.deletePurchaseEntryItemsByPurchase(existing.id);
    _purchaseEntryItems.removeWhere((i) => i.purchaseId == existing.id);

    await _repository.deleteBatchesByItem(existing.id);
    _batches.removeWhere((batch) => batch.purchaseId == existing.id);

    for (final oldItem in oldLineItems) {
      await _updateItemQuantity(
        oldItem.itemId,
        quantityDelta: -oldItem.quantity,
      );
    }

    final newItem = PurchaseEntryItem(
      id: 0,
      purchaseId: existing.id,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    final lineItemId = await _repository.insertPurchaseEntryItem(newItem);
    _purchaseEntryItems.add(
      PurchaseEntryItem(
        id: lineItemId,
        purchaseId: existing.id,
        itemId: itemId,
        quantity: quantity,
        unitCost: unitCost,
        expiryDate: expiryDate,
      ),
    );

    final newBatch = StockBatch(
      id: 0,
      itemId: itemId,
      purchaseId: existing.id,
      receivedAt: purchaseDate,
      quantity: quantity,
      remainingQuantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    final batchId = await _repository.insertBatch(newBatch);
    _batches.add(
      StockBatch(
        id: batchId,
        itemId: itemId,
        purchaseId: existing.id,
        receivedAt: purchaseDate,
        quantity: quantity,
        remainingQuantity: quantity,
        unitCost: unitCost,
        expiryDate: expiryDate,
      ),
    );

    await _updateItemQuantity(itemId, quantityDelta: quantity);

    final index = _purchases.indexWhere((entry) => entry.id == existing.id);
    if (index != -1) {
      _purchases[index] = PurchaseEntry(
        id: existing.id,
        purchaseDate: purchaseDate,
        memo: memo ?? existing.memo,
        status: 'ACTIVE',
        cancelReason: null,
      );
    }
  }

  Future<void> cancelPurchase(int id, {String? reason}) async {
    final index = _purchases.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return;
    }
    final purchase = _purchases[index];
    if (purchase.isCancelled) {
      return;
    }

    await _repository.updatePurchase(
      PurchaseEntry(
        id: purchase.id,
        purchaseDate: purchase.purchaseDate,
        memo: purchase.memo,
        status: 'CANCELLED',
        cancelReason: reason,
      ),
    );

    final lineItems =
        _purchaseEntryItems.where((i) => i.purchaseId == id).toList();

    await _repository.deleteBatchesByItem(purchase.id);
    _batches.removeWhere((batch) => batch.purchaseId == purchase.id);

    for (final lineItem in lineItems) {
      await _updateItemQuantity(
        lineItem.itemId,
        quantityDelta: -lineItem.quantity,
      );
    }

    _purchases[index] = PurchaseEntry(
      id: purchase.id,
      purchaseDate: purchase.purchaseDate,
      memo: purchase.memo,
      status: 'CANCELLED',
      cancelReason: reason,
    );
  }

  Future<void> deletePurchaseHard(int id) async {
    final index = _purchases.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return;
    }
    final purchase = _purchases[index];
    final lineItems =
        _purchaseEntryItems.where((i) => i.purchaseId == id).toList();
    final wasCancelled = purchase.isCancelled;

    await _repository.deletePurchaseEntryItemsByPurchase(id);
    _purchaseEntryItems.removeWhere((i) => i.purchaseId == id);

    await _repository.deleteBatchesByItem(purchase.id);
    _batches.removeWhere((batch) => batch.purchaseId == purchase.id);

    await _repository.deletePurchase(id);
    _purchases.removeAt(index);

    if (!wasCancelled) {
      for (final lineItem in lineItems) {
        await _updateItemQuantity(
          lineItem.itemId,
          quantityDelta: -lineItem.quantity,
        );
      }
    }
  }

  Future<void> consumeStock({
    required int itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return;
    }
    final available = availableQuantityForItem(itemId);
    if (available < quantity) {
      throw StateError('Not enough stock available.');
    }

    var remaining = quantity;
    final sortedBatches = stockRotationForItem(itemId);
    for (final batch in sortedBatches) {
      if (remaining <= 0) {
        break;
      }
      if (batch.remainingQuantity <= 0) {
        continue;
      }
      final deduct = remaining < batch.remainingQuantity
          ? remaining
          : batch.remainingQuantity;
      final updated = StockBatch(
        id: batch.id,
        itemId: batch.itemId,
        purchaseId: batch.purchaseId,
        receivedAt: batch.receivedAt,
        quantity: batch.quantity,
        remainingQuantity: batch.remainingQuantity - deduct,
        unitCost: batch.unitCost,
        expiryDate: batch.expiryDate,
      );
      await _repository.updateBatch(updated);
      _replaceBatch(updated);
      remaining -= deduct;
    }

    await _updateItemQuantity(itemId, quantityDelta: -quantity);
  }

  Future<void> restockFromSale({
    required int itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return;
    }
    var remaining = quantity;
    final batches = _sortedBatchesForItem(itemId, ascending: false);
    for (final batch in batches) {
      if (remaining <= 0) {
        break;
      }
      final capacity = batch.quantity - batch.remainingQuantity;
      if (capacity <= 0) {
        continue;
      }
      final add = remaining < capacity ? remaining : capacity;
      final updated = StockBatch(
        id: batch.id,
        itemId: batch.itemId,
        purchaseId: batch.purchaseId,
        receivedAt: batch.receivedAt,
        quantity: batch.quantity,
        remainingQuantity: batch.remainingQuantity + add,
        unitCost: batch.unitCost,
        expiryDate: batch.expiryDate,
      );
      await _repository.updateBatch(updated);
      _replaceBatch(updated);
      remaining -= add;
    }

    await _updateItemQuantity(itemId, quantityDelta: quantity);
  }

  double totalForPurchase(int purchaseId) {
    return _purchaseEntryItems
        .where((item) => item.purchaseId == purchaseId)
        .fold(0.0, (sum, item) => sum + item.subtotal);
  }

  List<PurchaseEntryItem> purchaseEntryItemsForPurchase(int purchaseId) {
    return _purchaseEntryItems
        .where((item) => item.purchaseId == purchaseId)
        .toList();
  }

  Future<void> addLineItemToPurchase({
    required int purchaseId,
    required int itemId,
    required int quantity,
    required double unitCost,
    DateTime? expiryDate,
  }) async {
    if (quantity <= 0) {
      throw StateError('Quantity must be greater than zero.');
    }
    final purchase = _purchases.firstWhere((p) => p.id == purchaseId);
    if (purchase.isCancelled) {
      throw StateError('Cannot add items to a cancelled purchase.');
    }

    final lineItem = PurchaseEntryItem(
      id: 0,
      purchaseId: purchaseId,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    final lineItemId = await _repository.insertPurchaseEntryItem(lineItem);
    _purchaseEntryItems.add(PurchaseEntryItem(
      id: lineItemId,
      purchaseId: purchaseId,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    ));

    final batch = StockBatch(
      id: 0,
      itemId: itemId,
      purchaseId: purchaseId,
      receivedAt: purchase.purchaseDate,
      quantity: quantity,
      remainingQuantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    final batchId = await _repository.insertBatch(batch);
    _batches.add(StockBatch(
      id: batchId,
      itemId: itemId,
      purchaseId: purchaseId,
      receivedAt: purchase.purchaseDate,
      quantity: quantity,
      remainingQuantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    ));

    await _updateItemQuantity(itemId, quantityDelta: quantity);
  }

  Future<void> updatePurchaseEntryMemo(int purchaseId, String? memo) async {
    final index = _purchases.indexWhere((p) => p.id == purchaseId);
    if (index == -1) return;
    final existing = _purchases[index];
    final updated = PurchaseEntry(
      id: existing.id,
      purchaseDate: existing.purchaseDate,
      memo: memo,
      status: existing.status,
      cancelReason: existing.cancelReason,
    );
    await _repository.updatePurchase(updated);
    _purchases[index] = updated;
  }

  int availableQuantityForItem(int itemId) {
    return _batches
        .where((batch) =>
            batch.itemId == itemId && batch.remainingQuantity > 0)
        .fold(0, (sum, batch) => sum + batch.remainingQuantity);
  }

  DateTime? nextExpiryForItem(int itemId) {
    final expiring = _batches
        .where((batch) =>
            batch.itemId == itemId &&
            batch.remainingQuantity > 0 &&
            batch.expiryDate != null)
        .map((batch) => batch.expiryDate!)
        .toList();
    if (expiring.isEmpty) {
      return null;
    }
    expiring.sort();
    return expiring.first;
  }

  bool isItemExpiringSoon(int itemId) {
    final nextExpiry = nextExpiryForItem(itemId);
    if (nextExpiry == null) {
      return false;
    }
    final now = DateTime.now();
    return nextExpiry.isAfter(now) &&
        nextExpiry.isBefore(now.add(const Duration(days: 7)));
  }

  List<StockBatch> stockRotationForItem(int itemId) {
    final list = _batches
        .where(
          (batch) =>
              batch.itemId == itemId && batch.remainingQuantity > 0,
        )
        .toList();
    list.sort(_compareRotationPriority);
    return list;
  }

  List<StockBatch> _sortedBatchesForItem(
    int itemId, {
    required bool ascending,
  }) {
    final list = _batches.where((batch) => batch.itemId == itemId).toList();
    list.sort(
      (a, b) => ascending
          ? a.receivedAt.compareTo(b.receivedAt)
          : b.receivedAt.compareTo(a.receivedAt),
    );
    return list;
  }

  int _compareRotationPriority(StockBatch a, StockBatch b) {
    final aExpiry = a.expiryDate;
    final bExpiry = b.expiryDate;
    if (aExpiry != null && bExpiry != null) {
      final byExpiry = aExpiry.compareTo(bExpiry);
      if (byExpiry != 0) {
        return byExpiry;
      }
    } else if (aExpiry != null) {
      return -1;
    } else if (bExpiry != null) {
      return 1;
    }
    return a.receivedAt.compareTo(b.receivedAt);
  }

  void _replaceBatch(StockBatch updated) {
    final index = _batches.indexWhere((batch) => batch.id == updated.id);
    if (index != -1) {
      _batches[index] = updated;
    }
  }

  Future<void> deletePurchasesByItem(int itemId) async {
    final affectedIds = _purchaseEntryItems
        .where((item) => item.itemId == itemId)
        .map((item) => item.purchaseId)
        .toSet();

    await _repository.deletePurchaseEntryItemsByItem(itemId);
    await _repository.deleteBatchesByItem(itemId);

    for (final purchaseId in affectedIds) {
      await _repository.deletePurchase(purchaseId);
    }

    _purchaseEntryItems.removeWhere((item) => item.itemId == itemId);
    _batches.removeWhere((batch) => batch.itemId == itemId);
    _purchases.removeWhere((entry) => affectedIds.contains(entry.id));
  }

  Future<void> _updateItemQuantity(
    int itemId, {
    required int quantityDelta,
  }) async {
    final current = _inventoryService.getItemById(itemId);
    if (current == null) {
      return;
    }
    final nextQuantity = current.quantity + quantityDelta;
    if (nextQuantity < 0) {
      return;
    }
    final updated = InventoryItem(
      id: current.id,
      name: current.name,
      category: current.category,
      quantity: nextQuantity,
      sellingPrice: current.sellingPrice,
      lowStockThreshold: current.lowStockThreshold,
    );
    await _inventoryService.updateItem(updated);
  }
}
