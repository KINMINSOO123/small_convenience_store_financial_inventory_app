import '../models/inventory_item.dart';
import '../models/sales_entry.dart';
import '../repositories/sales_repository.dart';
import 'inventory_service.dart';

class SalesService {
  SalesService(this._repository, this._inventoryService);

  final SalesRepository _repository;
  final InventoryService _inventoryService;
  final List<SalesEntry> _entries = [];

  List<SalesEntry> get salesEntries => List.unmodifiable(_entries);

  Future<void> load() async {
    await _repository.init();
    final rows = await _repository.fetchSalesEntries();
    _entries
      ..clear()
      ..addAll(rows.where((entry) => entry.itemId > 0 && entry.quantity > 0));
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
    await _inventoryService.consumeStock(
      itemId: itemId,
      quantity: quantity,
    );

    final entry = SalesEntry(
      id: 0,
      itemId: itemId,
      quantity: quantity,
      unitPrice: item.sellingPrice,
      date: _normalizeDate(entryDate),
      memo: memo,
    );
    final entryId = await _repository.insertSalesEntry(entry);
    _entries.insert(
      0,
      SalesEntry(
        id: entryId,
        itemId: itemId,
        quantity: quantity,
        unitPrice: item.sellingPrice,
        date: _normalizeDate(entryDate),
        memo: memo,
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

    final existing = _entries[index];
    await _inventoryService.restockFromSale(
      itemId: existing.itemId,
      quantity: existing.quantity,
    );

    try {
      final item = _requireItem(itemId);
      await _inventoryService.consumeStock(
        itemId: itemId,
        quantity: quantity,
      );
      final updated = SalesEntry(
        id: id,
        itemId: itemId,
        quantity: quantity,
        unitPrice: item.sellingPrice,
        date: _normalizeDate(entryDate),
        memo: memo,
      );
      await _repository.updateSalesEntry(updated);
      _entries[index] = updated;
      _sortEntries();
    } catch (error) {
      await _inventoryService.consumeStock(
        itemId: existing.itemId,
        quantity: existing.quantity,
      );
      rethrow;
    }
  }

  Future<void> deleteSale(int id) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return;
    }
    final entry = _entries[index];
    await _inventoryService.restockFromSale(
      itemId: entry.itemId,
      quantity: entry.quantity,
    );
    await _repository.deleteSalesEntry(id);
    _entries.removeAt(index);
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _sortEntries() {
    _entries.sort((a, b) => b.date.compareTo(a.date));
  }

  InventoryItem _requireItem(int itemId) {
    final item = _inventoryService.getItemById(itemId);
    if (item == null) {
      throw StateError('Item not found.');
    }
    return item;
  }
}
