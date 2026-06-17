import '../data/inventory_db.dart';
import '../models/supplier_return.dart';
import '../models/supplier_return_item.dart';

class SupplierReturnRepository {
  SupplierReturnRepository({InventoryDb? database})
    : _database = database ?? InventoryDb();

  final InventoryDb _database;

  Future<void> init() async {
    await _database.init();
  }

  Future<List<SupplierReturn>> fetchSupplierReturns() async {
    final rows = await _database.fetchSupplierReturns();
    return rows.map(SupplierReturn.fromMap).toList();
  }

  Future<int> insertSupplierReturn(SupplierReturn entry) async {
    return _database.insertSupplierReturn(entry.toMap());
  }

  Future<void> updateSupplierReturn(SupplierReturn entry) async {
    await _database.updateSupplierReturn(entry.toMap(), entry.id);
  }

  Future<void> deleteSupplierReturn(int id) async {
    await _database.deleteSupplierReturn(id);
  }

  Future<List<SupplierReturn>> fetchSupplierReturnsByPurchase(
    int purchaseId,
  ) async {
    final rows = await _database.fetchSupplierReturnsByPurchase(purchaseId);
    return rows.map(SupplierReturn.fromMap).toList();
  }

  Future<List<SupplierReturnItem>> fetchSupplierReturnItems() async {
    final rows = await _database.fetchSupplierReturnItems();
    return rows.map(SupplierReturnItem.fromMap).toList();
  }

  Future<int> insertSupplierReturnItem(SupplierReturnItem item) async {
    return _database.insertSupplierReturnItem(item.toMap());
  }

  Future<void> deleteSupplierReturnItemsByReturn(int returnId) async {
    await _database.deleteSupplierReturnItemsByReturn(returnId);
  }

  Future<void> deleteSupplierReturnItem(int id) async {
    await _database.deleteSupplierReturnItem(id);
  }
}
