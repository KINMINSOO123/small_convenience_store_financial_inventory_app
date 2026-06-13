import '../data/inventory_db.dart';
import '../models/sales_entry.dart';
import '../models/sales_entry_item.dart';

class SalesRepository {
  SalesRepository({InventoryDb? database})
      : _database = database ?? InventoryDb();

  final InventoryDb _database;

  Future<void> init() async {
    await _database.init();
  }

  Future<List<SalesEntry>> fetchSalesEntries() async {
    final rows = await _database.fetchSalesEntries();
    return rows.map(SalesEntry.fromMap).toList();
  }

  Future<int> insertSalesEntry(SalesEntry entry) async {
    return _database.insertSalesEntry(entry.toMap());
  }

  Future<void> updateSalesEntry(SalesEntry entry) async {
    await _database.updateSalesEntry(entry.toMap(), entry.id);
  }

  Future<void> deleteSalesEntry(int id) async {
    await _database.deleteSalesEntry(id);
  }

  Future<List<SalesEntryItem>> fetchSalesEntryItems() async {
    final rows = await _database.fetchSalesEntryItems();
    return rows.map(SalesEntryItem.fromMap).toList();
  }

  Future<List<SalesEntryItem>> fetchSalesEntryItemsBySales(
    int salesId,
  ) async {
    final rows = await _database.fetchSalesEntryItemsBySales(salesId);
    return rows.map(SalesEntryItem.fromMap).toList();
  }

  Future<int> insertSalesEntryItem(SalesEntryItem item) async {
    return _database.insertSalesEntryItem(item.toMap());
  }

  Future<void> deleteSalesEntryItemsBySales(int salesId) async {
    await _database.deleteSalesEntryItemsBySales(salesId);
  }

  Future<void> deleteSalesEntryItemsByItem(int itemId) async {
    await _database.deleteSalesEntryItemsByItem(itemId);
  }
}
