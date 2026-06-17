import '../data/inventory_db.dart';
import '../models/inventory_item.dart';
import '../models/inventory_movement.dart';

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

  Future<void> clearInventoryExpiry() async {
    await _database.clearInventoryExpiry();
  }

  Future<List<InventoryMovement>> fetchInventoryMovements() async {
    final rows = await _database.fetchInventoryMovements();
    return rows.map(InventoryMovement.fromMap).toList();
  }

  Future<int> insertInventoryMovement(InventoryMovement movement) async {
    return _database.insertInventoryMovement(movement.toMap());
  }

  Future<void> deleteInventoryMovementsByReference(
    String referenceType,
    int referenceId,
  ) async {
    await _database.deleteInventoryMovementsByReference(
      referenceType,
      referenceId,
    );
  }

  Future<void> clearAll() async {
    await _database.clearAll();
  }
}
