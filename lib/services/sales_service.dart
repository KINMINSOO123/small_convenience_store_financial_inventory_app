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
    required DateTime salesDate,
  }) async {
    if (quantity <= 0) {
      return;
    }
    final item = _requireItem(itemId);
    final amount = quantity * item.sellingPrice;
    final normalizedDate = _normalizeDate(salesDate);

    final entry = SalesEntry(
      id: 0,
      salesDate: normalizedDate,
      memo: memo,
      amount: amount,
      status: 'DRAFT',
    );
    final entryId = await _repository.insertSalesEntry(entry);
    final storedEntry = SalesEntry(
      id: entryId,
      salesDate: normalizedDate,
      memo: memo,
      amount: amount,
      status: 'DRAFT',
    );
    _entries.insert(0, storedEntry);

    final lineItem = SalesEntryItem(
      id: 0,
      salesId: entryId,
      itemId: itemId,
      quantity: quantity,
      unitPrice: item.sellingPrice,
      costOfGoodsSold: 0,
    );
    final lineItemId = await _repository.insertSalesEntryItem(lineItem);
    _entryItems.add(
      SalesEntryItem(
        id: lineItemId,
        salesId: entryId,
        itemId: itemId,
        quantity: quantity,
        unitPrice: item.sellingPrice,
        costOfGoodsSold: 0,
      ),
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
    final entry = _entries[index];
    if (!entry.isDraft) {
      throw StateError('Cannot edit a completed sale.');
    }
    if (quantity <= 0) {
      return;
    }

    final item = _requireItem(itemId);
    final amount = quantity * item.sellingPrice;
    final normalizedDate = _normalizeDate(salesDate);
    final updated = SalesEntry(
      id: id,
      salesDate: normalizedDate,
      memo: memo,
      amount: amount,
      status: 'DRAFT',
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
      costOfGoodsSold: 0,
    );
    final lineItemId = await _repository.insertSalesEntryItem(lineItem);
    _entryItems.add(
      SalesEntryItem(
        id: lineItemId,
        salesId: id,
        itemId: itemId,
        quantity: quantity,
        unitPrice: item.sellingPrice,
        costOfGoodsSold: 0,
      ),
    );
    _sortEntries();
  }

  Future<void> completeSale(int id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final sale = _entries[index];
    if (!sale.isDraft) return;

    final lineItems = _entryItems.where((i) => i.salesId == id).toList();

    for (final lineItem in lineItems) {
      final cogs = _computeCogs(lineItem.itemId, lineItem.quantity);
      await _purchaseService.consumeStock(
        itemId: lineItem.itemId,
        quantity: lineItem.quantity,
      );

      final updatedLineItem = SalesEntryItem(
        id: lineItem.id,
        salesId: lineItem.salesId,
        itemId: lineItem.itemId,
        quantity: lineItem.quantity,
        unitPrice: lineItem.unitPrice,
        costOfGoodsSold: cogs,
      );
      await _repository.updateSalesEntryItem(updatedLineItem);
      final liIndex =
          _entryItems.indexWhere((i) => i.id == lineItem.id);
      if (liIndex != -1) {
        _entryItems[liIndex] = updatedLineItem;
      }

      await _inventoryService.recordMovement(
        itemId: lineItem.itemId,
        movementType: 'SALE',
        quantity: -lineItem.quantity,
        unitCost: cogs / lineItem.quantity,
        movementDate: sale.salesDate,
        referenceType: 'SALE',
        referenceId: sale.id,
      );
    }

    final updated = SalesEntry(
      id: sale.id,
      salesDate: sale.salesDate,
      memo: sale.memo,
      amount: sale.amount,
      status: 'ACTIVE',
    );
    await _repository.updateSalesEntry(updated);
    _entries[index] = updated;
  }

  Future<void> voidSale(int id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final sale = _entries[index];
    if (sale.isVoid) {
      throw StateError('Sale is already voided.');
    }
    if (sale.isDraft) {
      await deleteSale(id);
      return;
    }

    final lineItems = _entryItems.where((i) => i.salesId == id).toList();
    for (final lineItem in lineItems) {
      await _purchaseService.restockFromSale(
        itemId: lineItem.itemId,
        quantity: lineItem.quantity,
      );
    }

    await _inventoryService.deleteMovementsByReference(
      'SALE',
      id,
    );

    final updated = SalesEntry(
      id: sale.id,
      salesDate: sale.salesDate,
      memo: sale.memo,
      amount: 0,
      status: 'VOID',
    );
    await _repository.updateSalesEntry(updated);
    _entries[index] = updated;
  }

  Future<void> reactivateSale(int id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final sale = _entries[index];
    if (!sale.isVoid) return;

    final lineItems = _entryItems.where((i) => i.salesId == id).toList();
    double totalAmount = 0;
    for (final lineItem in lineItems) {
      await _purchaseService.consumeStock(
        itemId: lineItem.itemId,
        quantity: lineItem.quantity,
      );
      await _inventoryService.recordMovement(
        itemId: lineItem.itemId,
        movementType: 'SALE',
        quantity: -lineItem.quantity,
        unitCost: lineItem.costOfGoodsSold / lineItem.quantity,
        movementDate: sale.salesDate,
        referenceType: 'SALE',
        referenceId: id,
      );
      totalAmount += lineItem.quantity * lineItem.unitPrice;
    }

    final updated = SalesEntry(
      id: sale.id,
      salesDate: sale.salesDate,
      memo: sale.memo,
      amount: totalAmount,
      status: 'ACTIVE',
    );
    await _repository.updateSalesEntry(updated);
    _entries[index] = updated;
  }

  Future<void> deleteSale(int id) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    final entry = _entries[index];
    if (!entry.isDraft) {
      throw StateError('Cannot delete a completed sale. Void it instead.');
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
    final sale = _entries.firstWhere((e) => e.id == saleId);
    if (!sale.isDraft) {
      throw StateError('Cannot add items to a completed sale.');
    }
    final item = _requireItem(itemId);

    final lineItem = SalesEntryItem(
      id: 0,
      salesId: saleId,
      itemId: itemId,
      quantity: quantity,
      unitPrice: item.sellingPrice,
      costOfGoodsSold: 0,
    );
    final lineItemId = await _repository.insertSalesEntryItem(lineItem);
    _entryItems.add(
      SalesEntryItem(
        id: lineItemId,
        salesId: saleId,
        itemId: itemId,
        quantity: quantity,
        unitPrice: item.sellingPrice,
        costOfGoodsSold: 0,
      ),
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
        status: entry.status,
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
    final sale = _entries.firstWhere((e) => e.id == saleId);
    if (!sale.isDraft) {
      throw StateError('Cannot delete items from a completed sale.');
    }

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
        status: entry.status,
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
    final sale = _entries.firstWhere((e) => e.id == saleId);
    if (!sale.isDraft) {
      throw StateError('Cannot edit items in a completed sale.');
    }
    final oldItem = _entryItems[oldItemIndex];

    final item = _requireItem(itemId);

    final updatedLineItem = SalesEntryItem(
      id: lineItemId,
      salesId: saleId,
      itemId: itemId,
      quantity: quantity,
      unitPrice: item.sellingPrice,
      costOfGoodsSold: 0,
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
        status: entry.status,
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
