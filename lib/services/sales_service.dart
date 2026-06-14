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
    required DateTime entryDate,
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
    final normalizedDate = _normalizeDate(entryDate);
    final entry = SalesEntry(
      id: 0,
      entryDate: normalizedDate,
      memo: memo,
      amount: amount,
    );
    final entryId = await _repository.insertSalesEntry(entry);
    final storedEntry = SalesEntry(
      id: entryId,
      entryDate: normalizedDate,
      memo: memo,
      amount: amount,
    );
    _entries.insert(0, storedEntry);

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
    _sortEntries();
  }

  Future<void> updateSale({
    required int id,
    required int itemId,
    required int quantity,
    required String memo,
    required DateTime entryDate,
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
    }

    try {
      final item = _requireItem(itemId);
      final cogs = _computeCogs(itemId, quantity);
      await _purchaseService.consumeStock(
        itemId: itemId,
        quantity: quantity,
      );

      final amount = quantity * item.sellingPrice;
      final normalizedDate = _normalizeDate(entryDate);
      final updated = SalesEntry(
        id: id,
        entryDate: normalizedDate,
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
    _entries.sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }

  InventoryItem _requireItem(int itemId) {
    final item = _inventoryService.getItemById(itemId);
    if (item == null) {
      throw StateError('Item not found.');
    }
    return item;
  }
}
