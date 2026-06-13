import '../data/inventory_db.dart';
import '../models/purchase_entry.dart';
import '../models/purchase_entry_item.dart';
import '../models/stock_batch.dart';

class PurchaseRepository {
  PurchaseRepository({InventoryDb? database})
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

  Future<List<PurchaseEntry>> fetchPurchases() async {
    final rows = await _database.fetchPurchases();
    return (rows.map(PurchaseEntry.fromMap)).toList();
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

  Future<void> deletePurchasesByItem(int itemId) async {
    await _database.deletePurchasesByItem(itemId);
  }

  Future<List<PurchaseEntryItem>> fetchPurchaseEntryItems() async {
    final rows = await _database.fetchPurchaseEntryItems();
    return rows.map(PurchaseEntryItem.fromMap).toList();
  }

  Future<List<PurchaseEntryItem>> fetchPurchaseEntryItemsByPurchase(
    int purchaseId,
  ) async {
    final rows = await _database.fetchPurchaseEntryItemsByPurchase(purchaseId);
    return rows.map(PurchaseEntryItem.fromMap).toList();
  }

  Future<int> insertPurchaseEntryItem(PurchaseEntryItem item) async {
    return _database.insertPurchaseEntryItem(item.toMap());
  }

  Future<void> deletePurchaseEntryItemsByPurchase(int purchaseId) async {
    await _database.deletePurchaseEntryItemsByPurchase(purchaseId);
  }

  Future<void> deletePurchaseEntryItemsByItem(int itemId) async {
    await _database.deletePurchaseEntryItemsByItem(itemId);
  }

  Future<List<StockBatch>> fetchBatches() async {
    final rows = await _database.fetchBatches();
    return rows.map(StockBatch.fromMap).toList();
  }

  Future<int> insertBatch(StockBatch batch) async {
    return _database.insertBatch(batch.toMap());
  }

  Future<void> updateBatch(StockBatch batch) async {
    await _database.updateBatch(batch.toMap(), batch.id);
  }

  Future<void> deleteBatch(int id) async {
    await _database.deleteBatch(id);
  }

  Future<void> deleteBatchesByItem(int itemId) async {
    await _database.deleteBatchesByItem(itemId);
  }

  Future<void> clearAll() async {
    await _database.clearAll();
  }
}
