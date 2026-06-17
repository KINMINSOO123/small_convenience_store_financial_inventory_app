import '../models/inventory_item.dart';
import '../models/sales_entry.dart';
import '../models/sales_entry_item.dart';
import '../repositories/sales_repository.dart';
import 'inventory_service.dart';
import 'purchase_service.dart';

class SalesService {
  SalesService(
    this._repository,
    this._inventoryService,
    this._purchaseService,
  );

  final SalesRepository _repository;
  final InventoryService _inventoryService;
  final PurchaseService _purchaseService;
  final List<SalesEntry> _entries = [];
  final List<SalesEntryItem> _entryItems = [];

  List<SalesEntry> get salesEntries => List.unmodifiable(_entries);

  List<SalesEntryItem> get salesEntryItems => List.unmodifiable(_entryItems);

  SalesEntry? findSaleByDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    for (final entry in _entries) {
      final entryDate = DateTime(
        entry.salesDate.year,
        entry.salesDate.month,
        entry.salesDate.day,
      );
      if (entryDate == normalized) return entry;
    }
    return null;
  }

  Future<void> load() async {
    await _repository.init();
    final rows = await _repository.fetchSalesEntries();
    final items = await _repository.fetchSalesEntryItems();
    _entries
      ..clear()
      ..addAll(rows);
    _entryItems
      ..clear()
      ..addAll(items);
    _sortEntries();
  }

  Future<void> addSale({
    required int itemId,
    required int quantity,
    required String memo,
    required DateTime salesDate,
  }) async {
    if (quantity <= 0) {
      return;
    }
    final item = _requireItem(itemId);
    final cogs = _computeCogs(itemId, quantity);
    await _purchaseService.consumeStock(
      itemId: itemId,
      quantity: quantity,
    );

    final amount = quantity * item.sellingPrice;
    final normalizedDate = _normalizeDate(salesDate);
    final existing = findSaleByDate(normalizedDate);
    int entryId;
    double newAmount;
    if (existing != null) {
      entryId = existing.id;
      newAmount = existing.amount + amount;
      final updatedEntry = SalesEntry(
        id: existing.id,
        salesDate: existing.salesDate,
        memo: existing.memo,
        amount: newAmount,
      );
      await _repository.updateSalesEntry(updatedEntry);
      final entryIndex = _entries.indexWhere((e) => e.id == existing.id);
      if (entryIndex != -1) {
        _entries[entryIndex] = updatedEntry;
      }
    } else {
      newAmount = amount;
      final entry = SalesEntry(
        id: 0,
        salesDate: normalizedDate,
        memo: memo,
        amount: newAmount,
      );
      entryId = await _repository.insertSalesEntry(entry);
      final storedEntry = SalesEntry(
        id: entryId,
        salesDate: normalizedDate,
        memo: memo,
        amount: newAmount,
      );
      _entries.insert(0, storedEntry);
    }

    final lineItem = SalesEntryItem(
      id: 0,
      salesId: entryId,
      itemId: itemId,
      quantity: quantity,
      unitPrice: item.sellingPrice,
      costOfGoodsSold: cogs,
    );
    final lineItemId = await _repository.insertSalesEntryItem(lineItem);
    _entryItems.add(
      SalesEntryItem(
        id: lineItemId,
        salesId: entryId,
        itemId: itemId,
        quantity: quantity,
        unitPrice: item.sellingPrice,
        costOfGoodsSold: cogs,
      ),
    );
    await _inventoryService.recordMovement(
      itemId: itemId,
      movementType: 'SALE',
      quantity: -quantity,
      unitCost: cogs / quantity,
      movementDate: normalizedDate,
      referenceType: 'SALE',
      referenceId: entryId,
    );
    _sortEntries();
  }

  Future<void> updateSale({
    required int id,
    required int itemId,
    required int quantity,
    required String memo,
    required DateTime salesDate,
  }) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return;
    }
    if (quantity <= 0) {
      return;
    }

    final existingItems =
        _entryItems.where((item) => item.salesId == id).toList();
    for (final item in existingItems) {
      await _purchaseService.restockFromSale(
        itemId: item.itemId,
        quantity: item.quantity,
      );
      await _inventoryService.recordMovement(
        itemId: item.itemId,
        movementType: 'SALE',
        quantity: item.quantity,
        unitCost: item.costOfGoodsSold / item.quantity,
        movementDate: _normalizeDate(salesDate),
        referenceType: 'SALE',
        referenceId: id,
      );
    }

    try {
      final item = _requireItem(itemId);
      final cogs = _computeCogs(itemId, quantity);
      await _purchaseService.consumeStock(
        itemId: itemId,
        quantity: quantity,
      );

      final amount = quantity * item.sellingPrice;
      final normalizedDate = _normalizeDate(salesDate);
      final updated = SalesEntry(
        id: id,
        salesDate: normalizedDate,
        memo: memo,
        amount: amount,
      );
      await _repository.updateSalesEntry(updated);
      _entries[index] = updated;

      await _repository.deleteSalesEntryItemsBySales(id);
      _entryItems.removeWhere((item) => item.salesId == id);

      final lineItem = SalesEntryItem(
        id: 0,
        salesId: id,
        itemId: itemId,
        quantity: quantity,
        unitPrice: item.sellingPrice,
        costOfGoodsSold: cogs,
      );
      final lineItemId = await _repository.insertSalesEntryItem(lineItem);
      _entryItems.add(
        SalesEntryItem(
          id: lineItemId,
          salesId: id,
          itemId: itemId,
          quantity: quantity,
          unitPrice: item.sellingPrice,
          costOfGoodsSold: cogs,
        ),
      );
      await _inventoryService.recordMovement(
        itemId: itemId,
        movementType: 'SALE',
        quantity: -quantity,
        unitCost: cogs / quantity,
        movementDate: _normalizeDate(salesDate),
        referenceType: 'SALE',
        referenceId: id,
      );
      _sortEntries();
    } catch (error) {
      await _purchaseService.consumeStock(
        itemId: itemId,
        quantity: quantity,
      );
      rethrow;
    }
  }

  Future<void> deleteSale(int id) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return;
    }
    final existingItems =
        _entryItems.where((item) => item.salesId == id).toList();
    for (final item in existingItems) {
      await _purchaseService.restockFromSale(
        itemId: item.itemId,
        quantity: item.quantity,
      );
    }
    await _repository.deleteSalesEntryItemsBySales(id);
    await _repository.deleteSalesEntry(id);
    _entries.removeAt(index);
    _entryItems.removeWhere((item) => item.salesId == id);
  }

  double totalForSale(int salesId) {
    return _entryItems
        .where((item) => item.salesId == salesId)
        .fold(0.0, (sum, item) => sum + item.subtotal);
  }

  List<SalesEntryItem> salesEntryItemsForSale(int salesId) {
    return _entryItems
        .where((item) => item.salesId == salesId)
        .toList();
  }

  Future<void> addLineItemToSale({
    required int saleId,
    required int itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) return;
    final item = _requireItem(itemId);
    final cogs = _computeCogs(itemId, quantity);
    await _purchaseService.consumeStock(
      itemId: itemId,
      quantity: quantity,
    );

    final lineItem = SalesEntryItem(
      id: 0,
      salesId: saleId,
      itemId: itemId,
      quantity: quantity,
      unitPrice: item.sellingPrice,
      costOfGoodsSold: cogs,
    );
    final lineItemId = await _repository.insertSalesEntryItem(lineItem);
    _entryItems.add(
      SalesEntryItem(
        id: lineItemId,
        salesId: saleId,
        itemId: itemId,
        quantity: quantity,
        unitPrice: item.sellingPrice,
        costOfGoodsSold: cogs,
      ),
    );
    await _inventoryService.recordMovement(
      itemId: itemId,
      movementType: 'SALE',
      quantity: -quantity,
      unitCost: cogs / quantity,
      movementDate: DateTime.now(),
      referenceType: 'SALE',
      referenceId: saleId,
    );

    final index = _entries.indexWhere((e) => e.id == saleId);
    if (index != -1) {
      final entry = _entries[index];
      final newAmount = entry.amount + (quantity * item.sellingPrice);
      final updatedEntry = SalesEntry(
        id: entry.id,
        salesDate: entry.salesDate,
        memo: entry.memo,
        amount: newAmount,
      );
      await _repository.updateSalesEntry(updatedEntry);
      _entries[index] = updatedEntry;
      _sortEntries();
    }
  }

  Future<void> updateSalesEntryMemo(int saleId, String memo) async {
    final index = _entries.indexWhere((e) => e.id == saleId);
    if (index == -1) return;
    final existing = _entries[index];
    final updated = SalesEntry(
      id: existing.id,
      salesDate: existing.salesDate,
      memo: memo,
      amount: existing.amount,
    );
    await _repository.updateSalesEntry(updated);
    _entries[index] = updated;
  }

  Future<void> deleteLineItemFromSale(int saleId, int lineItemId) async {
    final lineItemIndex = _entryItems.indexWhere((i) => i.id == lineItemId);
    if (lineItemIndex == -1) return;
    final lineItem = _entryItems[lineItemIndex];

    await _purchaseService.restockFromSale(
      itemId: lineItem.itemId,
      quantity: lineItem.quantity,
    );

    await _repository.deleteSalesEntryItem(lineItemId);
    _entryItems.removeAt(lineItemIndex);

    final entryIndex = _entries.indexWhere((e) => e.id == saleId);
    if (entryIndex != -1) {
      final entry = _entries[entryIndex];
      final newAmount = entry.amount - lineItem.subtotal;
      final updated = SalesEntry(
        id: entry.id,
        salesDate: entry.salesDate,
        memo: entry.memo,
        amount: newAmount,
      );
      await _repository.updateSalesEntry(updated);
      _entries[entryIndex] = updated;
    }
    _sortEntries();
  }

  Future<void> updateLineItemInSale({
    required int saleId,
    required int lineItemId,
    required int itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) return;
    final oldItemIndex = _entryItems.indexWhere((i) => i.id == lineItemId);
    if (oldItemIndex == -1) return;
    final oldItem = _entryItems[oldItemIndex];

    await _purchaseService.restockFromSale(
      itemId: oldItem.itemId,
      quantity: oldItem.quantity,
    );

    final item = _requireItem(itemId);
    final cogs = _computeCogs(itemId, quantity);
    await _purchaseService.consumeStock(
      itemId: itemId,
      quantity: quantity,
    );

    final updatedLineItem = SalesEntryItem(
      id: lineItemId,
      salesId: saleId,
      itemId: itemId,
      quantity: quantity,
      unitPrice: item.sellingPrice,
      costOfGoodsSold: cogs,
    );
    await _repository.updateSalesEntryItem(updatedLineItem);
    _entryItems[oldItemIndex] = updatedLineItem;

    final entryIndex = _entries.indexWhere((e) => e.id == saleId);
    if (entryIndex != -1) {
      final entry = _entries[entryIndex];
      final newAmount =
          entry.amount - oldItem.subtotal + updatedLineItem.subtotal;
      final updatedEntry = SalesEntry(
        id: entry.id,
        salesDate: entry.salesDate,
        memo: entry.memo,
        amount: newAmount,
      );
      await _repository.updateSalesEntry(updatedEntry);
      _entries[entryIndex] = updatedEntry;
    }
    _sortEntries();
  }

  double _computeCogs(int itemId, int quantity) {
    var remaining = quantity;
    double total = 0;
    final batches = _purchaseService.stockRotationForItem(itemId);
    for (final batch in batches) {
      if (remaining <= 0) {
        break;
      }
      final deduct = remaining < batch.remainingQuantity
          ? remaining
          : batch.remainingQuantity;
      total += deduct * batch.unitCost;
      remaining -= deduct;
    }
    return total;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _sortEntries() {
    _entries.sort((a, b) => b.salesDate.compareTo(a.salesDate));
  }

  InventoryItem _requireItem(int itemId) {
    final item = _inventoryService.getItemById(itemId);
    if (item == null) {
      throw StateError('Item not found.');
    }
    return item;
  }
}
