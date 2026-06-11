import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/inventory_item.dart';

class InventoryDb {
  static const _dbName = 'inventory.db';
  static const _dbVersion = 11;
  static const _tableItems = 'inventory_items';
  static const _tableCategories = 'inventory_categories';
  static const _tableSettings = 'app_settings';
  static const _tablePurchases = 'purchase_entries';
  static const _tableBatches = 'stock_batches';
  static const _tableAccounts = 'accounts';
  static const _tableJournalEntries = 'journal_entries';
  static const _tableJournalLines = 'journal_lines';
  static const _tableSalesEntries = 'sales_entries';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _openDatabase();
    return _database!;
  }

  Future<void> init() async {
    await database;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final filePath = path.join(dbPath, _dbName);
    return openDatabase(
      filePath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $_tableItems('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'name TEXT NOT NULL,'
          'category TEXT NOT NULL,'
          'quantity INTEGER NOT NULL,'
          'selling_price REAL NOT NULL,'
          'low_stock_threshold INTEGER NOT NULL DEFAULT 5,'
          'expiry_date TEXT'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableCategories('
          'name TEXT PRIMARY KEY'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableSettings('
          'key TEXT PRIMARY KEY,'
          'value TEXT NOT NULL'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tablePurchases('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'item_id INTEGER NOT NULL,'
          'quantity INTEGER NOT NULL,'
          'unit_cost REAL NOT NULL,'
          'purchased_at TEXT NOT NULL,'
          'status TEXT NOT NULL DEFAULT "ACTIVE",'
          'cancel_reason TEXT,'
          'expiry_date TEXT,'
          'FOREIGN KEY(item_id) REFERENCES $_tableItems(id)'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableBatches('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'item_id INTEGER NOT NULL,'
          'purchase_id INTEGER,'
          'received_at TEXT NOT NULL,'
          'quantity INTEGER NOT NULL,'
          'remaining_qty INTEGER NOT NULL,'
          'unit_cost REAL NOT NULL,'
          'expiry_date TEXT,'
          'FOREIGN KEY(item_id) REFERENCES $_tableItems(id)'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableAccounts('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'name TEXT NOT NULL,'
          'type TEXT NOT NULL'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableJournalEntries('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'entry_date TEXT NOT NULL,'
          'memo TEXT,'
          'total REAL NOT NULL,'
          'type TEXT NOT NULL'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableJournalLines('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'entry_id INTEGER NOT NULL,'
          'account_id INTEGER NOT NULL,'
          'debit REAL NOT NULL,'
          'credit REAL NOT NULL,'
          'FOREIGN KEY(entry_id) REFERENCES $_tableJournalEntries(id),'
          'FOREIGN KEY(account_id) REFERENCES $_tableAccounts(id)'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableSalesEntries('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'item_id INTEGER NOT NULL,'
          'quantity INTEGER NOT NULL,'
          'unit_price REAL NOT NULL,'
          'entry_date TEXT NOT NULL,'
          'amount REAL NOT NULL,'
          'memo TEXT,'
          'FOREIGN KEY(item_id) REFERENCES $_tableItems(id)'
          ')',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE $_tableSettings('
            'key TEXT PRIMARY KEY,'
            'value TEXT NOT NULL'
            ')',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE $_tablePurchases('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'item_id INTEGER NOT NULL,'
            'quantity INTEGER NOT NULL,'
            'unit_cost REAL NOT NULL,'
            'purchased_at TEXT NOT NULL,'
            'status TEXT NOT NULL DEFAULT "ACTIVE",'
            'cancel_reason TEXT,'
            'expiry_date TEXT,'
            'FOREIGN KEY(item_id) REFERENCES $_tableItems(id)'
            ')',
          );
          await db.execute(
            'CREATE TABLE $_tableBatches('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'item_id INTEGER NOT NULL,'
            'purchase_id INTEGER,'
            'received_at TEXT NOT NULL,'
            'quantity INTEGER NOT NULL,'
            'remaining_qty INTEGER NOT NULL,'
            'unit_cost REAL NOT NULL,'
            'expiry_date TEXT,'
            'FOREIGN KEY(item_id) REFERENCES $_tableItems(id)'
            ')',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE $_tablePurchases '
            'ADD COLUMN status TEXT NOT NULL DEFAULT "ACTIVE"',
          );
          await db.execute(
            'ALTER TABLE $_tableBatches '
            'ADD COLUMN purchase_id INTEGER',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE $_tablePurchases '
            'ADD COLUMN cancel_reason TEXT',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'CREATE TABLE $_tableAccounts('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'name TEXT NOT NULL,'
            'type TEXT NOT NULL'
            ')',
          );
          await db.execute(
            'CREATE TABLE $_tableJournalEntries('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'entry_date TEXT NOT NULL,'
            'memo TEXT,'
            'total REAL NOT NULL,'
            'type TEXT NOT NULL'
            ')',
          );
          await db.execute(
            'CREATE TABLE $_tableJournalLines('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'entry_id INTEGER NOT NULL,'
            'account_id INTEGER NOT NULL,'
            'debit REAL NOT NULL,'
            'credit REAL NOT NULL,'
            'FOREIGN KEY(entry_id) REFERENCES $_tableJournalEntries(id),'
            'FOREIGN KEY(account_id) REFERENCES $_tableAccounts(id)'
            ')',
          );
        }
        if (oldVersion < 7) {
          await db.execute(
            'CREATE TABLE $_tableSalesEntries('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'entry_date TEXT NOT NULL,'
            'amount REAL NOT NULL,'
            'memo TEXT'
            ')',
          );
        }
        if (oldVersion < 8) {
          await db.execute(
            'ALTER TABLE $_tableSalesEntries ADD COLUMN item_id INTEGER',
          );
          await db.execute(
            'ALTER TABLE $_tableSalesEntries ADD COLUMN quantity INTEGER',
          );
          await db.execute(
            'ALTER TABLE $_tableSalesEntries ADD COLUMN unit_price REAL',
          );
        }
        if (oldVersion < 9) {
          await db.execute(
            'ALTER TABLE $_tableItems '
            'ADD COLUMN low_stock_threshold INTEGER NOT NULL DEFAULT 5',
          );
        }
        if (oldVersion < 10) {
          await db.execute(
            'CREATE TABLE $_tableCategories('
            'name TEXT PRIMARY KEY'
            ')',
          );
          await db.execute(
            'INSERT OR IGNORE INTO $_tableCategories(name) '
            'SELECT DISTINCT category FROM $_tableItems',
          );
        }
        if (oldVersion < 11) {
          await db.execute(
            'ALTER TABLE $_tableItems '
            'ADD COLUMN selling_price REAL NOT NULL DEFAULT 0',
          );
          // This is a bit of a hack, but it's the best we can do
          // if the unit_cost column exists.
          try {
            await db.execute(
              'UPDATE $_tableItems '
              'SET selling_price = unit_cost '
              'WHERE selling_price = 0',
            );
            // Now drop the unit_cost column as it is obsolete
            await db.execute('ALTER TABLE $_tableItems DROP COLUMN unit_cost');
          } catch (e) {
            // Ignore if unit_cost does not exist
          }
        }
      },
    );
  }

  Future<List<String>> fetchCategories() async {
    final db = await database;
    final rows = await db.query(
      _tableCategories,
      columns: ['name'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((row) => row['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<void> insertCategory(String name) async {
    final db = await database;
    await db.insert(_tableCategories, {
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> renameCategory(String oldName, String newName) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(_tableCategories, {
        'name': newName,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        _tableItems,
        {'category': newName},
        where: 'category = ?',
        whereArgs: [oldName],
      );
      await txn.delete(
        _tableCategories,
        where: 'name = ?',
        whereArgs: [oldName],
      );
    });
  }

  Future<void> deleteCategory(String name) async {
    final db = await database;
    await db.delete(_tableCategories, where: 'name = ?', whereArgs: [name]);
  }

  Future<List<InventoryItem>> fetchItems() async {
    final db = await database;
    final rows = await db.query(
      _tableItems,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<int> insertItem(InventoryItem item) async {
    final db = await database;
    await insertCategory(item.category);
    return db.insert(_tableItems, item.toMap());
  }

  Future<int> insertItemWithId(Map<String, Object?> values) async {
    final db = await database;
    final category = values['category'] as String?;
    if (category != null && category.isNotEmpty) {
      await insertCategory(category);
    }
    return db.insert(
      _tableItems,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateItem(InventoryItem item) async {
    final db = await database;
    await insertCategory(item.category);
    await db.update(
      _tableItems,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete(_tableItems, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePurchasesByItem(int itemId) async {
    final db = await database;
    await db.delete(_tablePurchases, where: 'item_id = ?', whereArgs: [itemId]);
  }

  Future<void> deleteBatchesByItem(int itemId) async {
    final db = await database;
    await db.delete(_tableBatches, where: 'item_id = ?', whereArgs: [itemId]);
  }

  Future<List<Map<String, Object?>>> fetchPurchases() async {
    final db = await database;
    return db.query(_tablePurchases, orderBy: 'purchased_at DESC');
  }

  Future<int> insertPurchase(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tablePurchases, values);
  }

  Future<void> updatePurchase(Map<String, Object?> values, int id) async {
    final db = await database;
    await db.update(_tablePurchases, values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePurchase(int id) async {
    final db = await database;
    await db.delete(_tablePurchases, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> fetchBatches() async {
    final db = await database;
    return db.query(_tableBatches, orderBy: 'received_at ASC');
  }

  Future<int> insertBatch(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tableBatches, values);
  }

  Future<void> deleteBatchesByPurchaseId(int purchaseId) async {
    final db = await database;
    await db.delete(
      _tableBatches,
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
  }

  Future<void> deleteBatch(int id) async {
    final db = await database;
    await db.delete(_tableBatches, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateBatch(Map<String, Object?> values, int id) async {
    final db = await database;
    await db.update(_tableBatches, values, where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> fetchSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      _tableSettings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> upsertSetting(String key, String value) async {
    final db = await database;
    await db.insert(_tableSettings, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearInventoryExpiry() async {
    final db = await database;
    await db.execute('UPDATE $_tableItems SET expiry_date = NULL');
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tableBatches);
    await db.delete(_tablePurchases);
    await db.delete(_tableJournalLines);
    await db.delete(_tableJournalEntries);
    await db.delete(_tableSalesEntries);
    await db.delete(_tableAccounts);
    await db.delete(_tableItems);
    await db.delete(_tableCategories);
    await db.delete(_tableSettings);
  }

  Future<List<Map<String, Object?>>> fetchAccounts() async {
    final db = await database;
    return db.query(_tableAccounts, orderBy: 'name COLLATE NOCASE ASC');
  }

  Future<int> insertAccount(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tableAccounts, values);
  }

  Future<List<Map<String, Object?>>> fetchJournalEntries() async {
    final db = await database;
    return db.query(_tableJournalEntries, orderBy: 'entry_date DESC');
  }

  Future<int> insertJournalEntry(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tableJournalEntries, values);
  }

  Future<void> updateJournalEntry(Map<String, Object?> values, int id) async {
    final db = await database;
    await db.update(
      _tableJournalEntries,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteJournalEntry(int id) async {
    final db = await database;
    await db.delete(_tableJournalEntries, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertJournalLine(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tableJournalLines, values);
  }

  Future<void> updateJournalLine(Map<String, Object?> values, int id) async {
    final db = await database;
    await db.update(
      _tableJournalLines,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteJournalLinesByEntryId(int entryId) async {
    final db = await database;
    await db.delete(
      _tableJournalLines,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
  }

  Future<List<Map<String, Object?>>> fetchSalesEntries() async {
    final db = await database;
    return db.query(_tableSalesEntries, orderBy: 'entry_date DESC');
  }

  Future<int> insertSalesEntry(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tableSalesEntries, values);
  }

  Future<void> updateSalesEntry(Map<String, Object?> values, int id) async {
    final db = await database;
    await db.update(
      _tableSalesEntries,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSalesEntry(int id) async {
    final db = await database;
    await db.delete(_tableSalesEntries, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> fetchJournalLines() async {
    final db = await database;
    return db.query(_tableJournalLines, orderBy: 'entry_id ASC');
  }
}
