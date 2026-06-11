import '../data/inventory_db.dart';
import '../models/inventory_item.dart';
import '../models/purchase_entry.dart';
import '../models/stock_batch.dart';

class InventoryRepository {
  InventoryRepository({InventoryDb? database})
    : _database = database ?? InventoryDb();

  final InventoryDb _database;

  Future<void> init() async {
    await _database.init();
  }

  Future<String?> fetchSetting(String key) async {
    return _database.fetchSetting(key);
  }

  Future<void> upsertSetting(String key, String value) async {
    await _database.upsertSetting(key, value);
  }

  Future<List<InventoryItem>> fetchItems() async {
    return _database.fetchItems();
  }

  Future<List<String>> fetchCategories() async {
    return _database.fetchCategories();
  }

  Future<void> insertCategory(String name) async {
    await _database.insertCategory(name);
  }

  Future<void> renameCategory(String oldName, String newName) async {
    await _database.renameCategory(oldName, newName);
  }

  Future<void> deleteCategory(String name) async {
    await _database.deleteCategory(name);
  }

  Future<List<PurchaseEntry>> fetchPurchases() async {
    final rows = await _database.fetchPurchases();
    return rows.map(PurchaseEntry.fromMap).toList();
  }

  Future<List<StockBatch>> fetchBatches() async {
    final rows = await _database.fetchBatches();
    return rows.map(StockBatch.fromMap).toList();
  }

  Future<int> insertItem(InventoryItem item) async {
    return _database.insertItem(item);
  }

  Future<int> insertItemWithId(Map<String, Object?> values) async {
    return _database.insertItemWithId(values);
  }

  Future<void> updateItem(InventoryItem item) async {
    await _database.updateItem(item);
  }

  Future<void> deleteItem(int id) async {
    await _database.deleteItem(id);
  }

  Future<void> deletePurchasesByItem(int itemId) async {
    await _database.deletePurchasesByItem(itemId);
  }

  Future<void> deleteBatchesByItem(int itemId) async {
    await _database.deleteBatchesByItem(itemId);
  }

  Future<int> insertPurchase(PurchaseEntry entry) async {
    return _database.insertPurchase(entry.toMap());
  }

  Future<void> updatePurchase(PurchaseEntry entry) async {
    await _database.updatePurchase(entry.toMap(), entry.id);
  }

  Future<void> deletePurchase(int id) async {
    await _database.deletePurchase(id);
  }

  Future<int> insertBatch(StockBatch batch) async {
    return _database.insertBatch(batch.toMap());
  }

  Future<void> deleteBatchesByPurchaseId(int purchaseId) async {
    await _database.deleteBatchesByPurchaseId(purchaseId);
  }

  Future<void> deleteBatch(int id) async {
    await _database.deleteBatch(id);
  }

  Future<void> updateBatch(StockBatch batch) async {
    await _database.updateBatch(batch.toMap(), batch.id);
  }

  Future<void> clearInventoryExpiry() async {
    await _database.clearInventoryExpiry();
  }

  Future<void> clearAll() async {
    await _database.clearAll();
  }
}
