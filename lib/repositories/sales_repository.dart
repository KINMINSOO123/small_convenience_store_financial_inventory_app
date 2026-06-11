import '../data/inventory_db.dart';
import '../models/sales_entry.dart';

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
}
