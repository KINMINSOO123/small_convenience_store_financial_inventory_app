import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/inventory_item.dart';

class InventoryDb {
  static const _dbName = 'inventory.db';
  static const _dbVersion = 19;
  static const _tableItems = 'inventory_items';
  static const _tableCategories = 'inventory_categories';
  static const _tableSettings = 'app_settings';
  static const _tablePurchases = 'purchase_entries';
  static const _tablePurchaseItems = 'purchase_entry_items';
  static const _tableBatches = 'stock_batches';
  static const _tableAccounts = 'accounts';
  static const _tableJournalEntries = 'journal_entries';
  static const _tableJournalLines = 'journal_lines';
  static const _tableSalesEntries = 'sales_entries';
  static const _tableSalesItems = 'sales_entry_items';
  static const _tableSupplierReturns = 'supplier_returns';
  static const _tableSupplierReturnItems = 'supplier_return_items';
  static const _tableInventoryMovements = 'inventory_movements';

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
          'purchase_date TEXT NOT NULL UNIQUE,'
          'memo TEXT,'
          'status TEXT NOT NULL DEFAULT "ACTIVE",'
          'cancel_reason TEXT'
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
          'CREATE TABLE $_tablePurchaseItems('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'purchase_id INTEGER NOT NULL,'
          'item_id INTEGER NOT NULL,'
          'quantity INTEGER NOT NULL,'
          'unit_cost REAL NOT NULL,'
          'expiry_date TEXT,'
          'FOREIGN KEY(purchase_id) REFERENCES $_tablePurchases(id),'
          'FOREIGN KEY(item_id) REFERENCES $_tableItems(id)'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableSalesItems('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'sales_id INTEGER NOT NULL,'
          'item_id INTEGER NOT NULL,'
          'quantity INTEGER NOT NULL,'
          'unit_price REAL NOT NULL,'
          'cost_of_goods_sold REAL NOT NULL DEFAULT 0,'
          'subtotal REAL NOT NULL DEFAULT 0,'
          'FOREIGN KEY(sales_id) REFERENCES $_tableSalesEntries(id),'
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
          'sales_date TEXT NOT NULL UNIQUE,'
          'memo TEXT,'
          'amount REAL NOT NULL DEFAULT 0'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableSupplierReturns('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'return_date TEXT NOT NULL,'
          'purchase_id INTEGER NOT NULL,'
          'memo TEXT,'
          'total_amount REAL NOT NULL DEFAULT 0'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableSupplierReturnItems('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'return_id INTEGER NOT NULL,'
          'item_id INTEGER NOT NULL,'
          'purchase_item_id INTEGER NOT NULL,'
          'quantity INTEGER NOT NULL,'
          'unit_cost REAL NOT NULL'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableInventoryMovements('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'item_id INTEGER NOT NULL,'
          'batch_id INTEGER,'
          'movement_type TEXT NOT NULL,'
          'quantity INTEGER NOT NULL,'
          'unit_cost REAL NOT NULL,'
          'movement_date TEXT NOT NULL,'
          'reference_type TEXT NOT NULL,'
          'reference_id INTEGER NOT NULL'
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
            'purchase_date TEXT NOT NULL,'
            'memo TEXT,'
            'status TEXT NOT NULL DEFAULT "ACTIVE",'
            'cancel_reason TEXT'
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
          'sales_date TEXT NOT NULL,'
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
          // Copy unit_cost to selling_price if the column exists
          try {
            await db.execute(
              'UPDATE $_tableItems '
              'SET selling_price = unit_cost '
              'WHERE selling_price = 0',
            );
          } catch (e) {
            // Ignore if unit_cost column does not exist
          }
        }
        if (oldVersion < 12) {
          // Recreate inventory_items without the unit_cost column.
          // ALTER TABLE DROP COLUMN requires SQLite >= 3.35.0, so we use the
          // table-recreation technique instead.
          await db.execute(
            'CREATE TABLE ${_tableItems}_new('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'name TEXT NOT NULL,'
            'category TEXT NOT NULL,'
            'quantity INTEGER NOT NULL,'
            'selling_price REAL NOT NULL DEFAULT 0,'
            'low_stock_threshold INTEGER NOT NULL DEFAULT 5,'
            'expiry_date TEXT'
            ')',
          );
          await db.execute(
            'INSERT INTO ${_tableItems}_new '
            '(id, name, category, quantity, selling_price, low_stock_threshold, expiry_date) '
            'SELECT id, name, category, quantity, selling_price, low_stock_threshold, expiry_date '
            'FROM $_tableItems',
          );
          await db.execute('DROP TABLE $_tableItems');
          await db.execute(
            'ALTER TABLE ${_tableItems}_new RENAME TO $_tableItems',
          );
        }
        if (oldVersion < 13) {
          await db.execute(
            'CREATE TABLE $_tablePurchaseItems('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'purchase_id INTEGER NOT NULL,'
            'item_id INTEGER NOT NULL,'
            'quantity INTEGER NOT NULL,'
            'unit_cost REAL NOT NULL,'
            'expiry_date TEXT,'
            'FOREIGN KEY(purchase_id) REFERENCES $_tablePurchases(id),'
            'FOREIGN KEY(item_id) REFERENCES $_tableItems(id)'
            ')',
          );
          await db.execute(
            'CREATE TABLE $_tableSalesItems('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'sales_id INTEGER NOT NULL,'
            'item_id INTEGER NOT NULL,'
            'quantity INTEGER NOT NULL,'
            'unit_price REAL NOT NULL,'
            'cost_of_goods_sold REAL NOT NULL DEFAULT 0,'
            'subtotal REAL NOT NULL DEFAULT 0,'
            'FOREIGN KEY(sales_id) REFERENCES $_tableSalesEntries(id),'
            'FOREIGN KEY(item_id) REFERENCES $_tableItems(id)'
            ')',
          );
          try {
            await db.execute(
              'ALTER TABLE $_tableBatches ADD COLUMN purchase_item_id INTEGER',
            );
          } catch (e) {
            // Ignore if column already exists
          }
          await db.execute(
            'INSERT INTO $_tablePurchaseItems '
            '(purchase_id, item_id, quantity, unit_cost, expiry_date) '
            'SELECT id, item_id, quantity, unit_cost, expiry_date '
            'FROM $_tablePurchases',
          );
          await db.execute(
            'UPDATE $_tableBatches '
            'SET purchase_item_id = ('
            'SELECT $_tablePurchaseItems.id '
            'FROM $_tablePurchaseItems '
            'WHERE $_tablePurchaseItems.purchase_id = $_tableBatches.purchase_id'
            ')',
          );
          await db.execute(
            'INSERT INTO $_tableSalesItems '
            '(sales_id, item_id, quantity, unit_price, cost_of_goods_sold, subtotal) '
            'SELECT id, item_id, quantity, unit_price, 0, quantity * unit_price '
            'FROM $_tableSalesEntries '
            'WHERE item_id IS NOT NULL',
          );
        }
        if (oldVersion < 14) {
          await db.execute(
          'CREATE TABLE ${_tableSalesEntries}_new('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'sales_date TEXT NOT NULL,'
          'memo TEXT,'
          'amount REAL NOT NULL DEFAULT 0'
          ')',
        );
        await db.execute(
          'INSERT INTO ${_tableSalesEntries}_new '
          '(id, sales_date, memo, amount) '
          'SELECT id, entry_date, memo, amount '
          'FROM $_tableSalesEntries',
          );
          await db.execute('DROP TABLE $_tableSalesEntries');
          await db.execute(
            'ALTER TABLE ${_tableSalesEntries}_new RENAME TO $_tableSalesEntries',
          );
        }
        if (oldVersion < 15) {
          // Restructure purchase_entries to a pure header table:
          // drop item_id, quantity, unit_cost, expiry_date; add memo.
          await db.execute(
          'CREATE TABLE ${_tablePurchases}_new('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'purchase_date TEXT NOT NULL,'
          'memo TEXT,'
          'status TEXT NOT NULL DEFAULT "ACTIVE",'
          'cancel_reason TEXT'
          ')',
        );
        await db.execute(
          'INSERT INTO ${_tablePurchases}_new '
          '(id, purchase_date, memo, status, cancel_reason) '
          'SELECT id, purchased_at, NULL, status, cancel_reason '
          'FROM $_tablePurchases',
          );
          // Migrate flat item data from old purchase_entries into
          // purchase_entry_items for rows that don't already have a line item.
          await db.execute(
            'INSERT OR IGNORE INTO $_tablePurchaseItems '
            '(purchase_id, item_id, quantity, unit_cost, expiry_date) '
            'SELECT p.id, p.item_id, p.quantity, p.unit_cost, p.expiry_date '
            'FROM $_tablePurchases p '
            'WHERE p.item_id IS NOT NULL',
          );
          await db.execute('DROP TABLE $_tablePurchases');
          await db.execute(
            'ALTER TABLE ${_tablePurchases}_new RENAME TO $_tablePurchases',
          );
        }
        if (oldVersion < 16) {
          // v16 was a duplicate rename — now handled by v15/v14.
          // Kept as no-op to avoid renumbering migrations.
        }
        if (oldVersion < 17) {
          // Detect actual column names (may be pre-rename if v15/v14 did not run)
          final purchaseCols = await db.rawQuery(
            'PRAGMA table_info($_tablePurchases)',
          );
          final purchaseDateCol = purchaseCols.any(
            (c) => c['name'] == 'purchase_date',
          )
              ? 'purchase_date'
              : 'purchased_at';

          final salesCols = await db.rawQuery(
            'PRAGMA table_info($_tableSalesEntries)',
          );
          final salesDateCol = salesCols.any((c) => c['name'] == 'sales_date')
              ? 'sales_date'
              : 'entry_date';

          // --- Purchase entries: deduplicate by date ---
          final oldPurchases = await db.rawQuery(
            'SELECT id, $purchaseDateCol AS date_col, memo, status, '
            'cancel_reason '
            'FROM $_tablePurchases ORDER BY id',
          );
          final purchaseGroups = <String, List<Map<String, Object?>>>{};
          for (final row in oldPurchases) {
            final date = row['date_col'] as String;
            purchaseGroups.putIfAbsent(date, () => []).add(row);
          }

          await db.execute(
            'CREATE TABLE ${_tablePurchases}_new('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'purchase_date TEXT NOT NULL UNIQUE,'
            'memo TEXT,'
            'status TEXT NOT NULL DEFAULT "ACTIVE",'
            'cancel_reason TEXT'
            ')',
          );
          for (final group in purchaseGroups.values) {
            final first = group.first;
            final survivingId = first['id'] as int;
            for (int i = 1; i < group.length; i++) {
              final dupId = group[i]['id'] as int;
              await db.update(
                _tablePurchaseItems,
                {'purchase_id': survivingId},
                where: 'purchase_id = ?',
                whereArgs: [dupId],
              );
              await db.update(
                _tableBatches,
                {'purchase_id': survivingId},
                where: 'purchase_id = ?',
                whereArgs: [dupId],
              );
            }
            await db.insert('${_tablePurchases}_new', {
              'id': survivingId,
              'purchase_date': first['date_col'],
              'memo': first['memo'],
              'status': first['status'] ?? 'ACTIVE',
              'cancel_reason': first['cancel_reason'],
            });
          }
          await db.execute('DROP TABLE $_tablePurchases');
          await db.execute(
            'ALTER TABLE ${_tablePurchases}_new RENAME TO $_tablePurchases',
          );

          // --- Sales entries: deduplicate by date ---
          final oldSales = await db.rawQuery(
            'SELECT id, $salesDateCol AS date_col, memo, amount '
            'FROM $_tableSalesEntries ORDER BY id',
          );
          final salesGroups = <String, List<Map<String, Object?>>>{};
          for (final row in oldSales) {
            final date = row['date_col'] as String;
            salesGroups.putIfAbsent(date, () => []).add(row);
          }

          await db.execute(
            'CREATE TABLE ${_tableSalesEntries}_new('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'sales_date TEXT NOT NULL UNIQUE,'
            'memo TEXT,'
            'amount REAL NOT NULL DEFAULT 0'
            ')',
          );
          for (final group in salesGroups.values) {
            final first = group.first;
            final survivingId = first['id'] as int;
            double totalAmount = (first['amount'] as num).toDouble();
            String? memo = first['memo'] as String?;
            for (int i = 1; i < group.length; i++) {
              final dupId = group[i]['id'] as int;
              totalAmount += (group[i]['amount'] as num).toDouble();
              if (memo == null || memo.isEmpty) {
                final m = group[i]['memo'] as String?;
                if (m != null && m.isNotEmpty) {
                  memo = m;
                }
              }
              await db.update(
                _tableSalesItems,
                {'sales_id': survivingId},
                where: 'sales_id = ?',
                whereArgs: [dupId],
              );
            }
            await db.insert('${_tableSalesEntries}_new', {
              'id': survivingId,
              'sales_date': first['date_col'],
              'memo': memo,
              'amount': totalAmount,
            });
          }
          await db.execute('DROP TABLE $_tableSalesEntries');
          await db.execute(
            'ALTER TABLE ${_tableSalesEntries}_new RENAME TO $_tableSalesEntries',
          );
        }
        if (oldVersion < 18) {
          // Ensure stock_batches has purchase_id column (fresh installs had
          // purchase_item_id instead due to a bug).
          try {
            await db.execute(
              'ALTER TABLE $_tableBatches ADD COLUMN purchase_id INTEGER',
            );
          } catch (_) {
            // Column already exists — ignore.
          }
        }
        if (oldVersion < 19) {
          await db.execute(
            'CREATE TABLE $_tableSupplierReturns('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'return_date TEXT NOT NULL,'
            'purchase_id INTEGER NOT NULL,'
            'memo TEXT,'
            'total_amount REAL NOT NULL DEFAULT 0'
            ')',
          );
          await db.execute(
            'CREATE TABLE $_tableSupplierReturnItems('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'return_id INTEGER NOT NULL,'
            'item_id INTEGER NOT NULL,'
            'purchase_item_id INTEGER NOT NULL,'
            'quantity INTEGER NOT NULL,'
            'unit_cost REAL NOT NULL'
            ')',
          );
          await db.execute(
            'CREATE TABLE $_tableInventoryMovements('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'item_id INTEGER NOT NULL,'
            'batch_id INTEGER,'
            'movement_type TEXT NOT NULL,'
            'quantity INTEGER NOT NULL,'
            'unit_cost REAL NOT NULL,'
            'movement_date TEXT NOT NULL,'
            'reference_type TEXT NOT NULL,'
            'reference_id INTEGER NOT NULL'
            ')',
          );
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
        .map((row) => (row['name'] as String? ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<void> insertCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final db = await database;
    await db.insert(_tableCategories, {
      'name': trimmed,
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
    await db.rawDelete(
      'DELETE FROM $_tablePurchases WHERE id IN ('
      'SELECT purchase_id FROM $_tablePurchaseItems WHERE item_id = ?'
      ')',
      [itemId],
    );
  }

  Future<void> deleteBatchesByItem(int itemId) async {
    final db = await database;
    await db.delete(_tableBatches, where: 'item_id = ?', whereArgs: [itemId]);
  }

  Future<List<Map<String, Object?>>> fetchPurchases() async {
    final db = await database;
    return db.query(_tablePurchases, orderBy: 'purchase_date DESC');
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

  Future<List<Map<String, Object?>>> fetchPurchaseEntryItems() async {
    final db = await database;
    return db.query(_tablePurchaseItems, orderBy: 'id ASC');
  }

  Future<List<Map<String, Object?>>> fetchPurchaseEntryItemsByPurchase(
    int purchaseId,
  ) async {
    final db = await database;
    return db.query(
      _tablePurchaseItems,
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
  }

  Future<int> insertPurchaseEntryItem(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tablePurchaseItems, values);
  }

  Future<void> deletePurchaseEntryItemsByPurchase(int purchaseId) async {
    final db = await database;
    await db.delete(
      _tablePurchaseItems,
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
  }

  Future<void> deletePurchaseEntryItemsByItem(int itemId) async {
    final db = await database;
    await db.delete(
      _tablePurchaseItems,
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deletePurchaseEntryItem(int id) async {
    final db = await database;
    await db.delete(_tablePurchaseItems, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePurchaseEntryItem(
    Map<String, Object?> values,
    int id,
  ) async {
    final db = await database;
    await db.update(_tablePurchaseItems, values, where: 'id = ?', whereArgs: [id]);
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
    await db.delete(_tablePurchaseItems);
    await db.delete(_tablePurchases);
    await db.delete(_tableSalesItems);
    await db.delete(_tableSalesEntries);
    await db.delete(_tableInventoryMovements);
    await db.delete(_tableSupplierReturnItems);
    await db.delete(_tableSupplierReturns);
    await db.delete(_tableJournalLines);
    await db.delete(_tableJournalEntries);
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
    return db.query(_tableSalesEntries, orderBy: 'sales_date DESC');
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

  Future<List<Map<String, Object?>>> fetchSalesEntryItems() async {
    final db = await database;
    return db.query(_tableSalesItems, orderBy: 'id ASC');
  }

  Future<List<Map<String, Object?>>> fetchSalesEntryItemsBySales(
    int salesId,
  ) async {
    final db = await database;
    return db.query(
      _tableSalesItems,
      where: 'sales_id = ?',
      whereArgs: [salesId],
    );
  }

  Future<int> insertSalesEntryItem(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tableSalesItems, values);
  }

  Future<void> deleteSalesEntryItemsBySales(int salesId) async {
    final db = await database;
    await db.delete(
      _tableSalesItems,
      where: 'sales_id = ?',
      whereArgs: [salesId],
    );
  }

  Future<void> deleteSalesEntryItemsByItem(int itemId) async {
    final db = await database;
    await db.delete(
      _tableSalesItems,
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteSalesEntryItem(int id) async {
    final db = await database;
    await db.delete(_tableSalesItems, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSalesEntryItem(
    Map<String, Object?> values,
    int id,
  ) async {
    final db = await database;
    await db.update(_tableSalesItems, values, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> fetchJournalLines() async {
    final db = await database;
    return db.query(_tableJournalLines, orderBy: 'entry_id ASC');
  }

  // --- Supplier Returns ---

  Future<List<Map<String, Object?>>> fetchSupplierReturns() async {
    final db = await database;
    return db.query(_tableSupplierReturns, orderBy: 'return_date DESC');
  }

  Future<int> insertSupplierReturn(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tableSupplierReturns, values);
  }

  Future<void> updateSupplierReturn(Map<String, Object?> values, int id) async {
    final db = await database;
    await db.update(
      _tableSupplierReturns,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSupplierReturn(int id) async {
    final db = await database;
    await db.delete(_tableSupplierReturns, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> fetchSupplierReturnsByPurchase(
    int purchaseId,
  ) async {
    final db = await database;
    return db.query(
      _tableSupplierReturns,
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
      orderBy: 'return_date DESC',
    );
  }

  // --- Supplier Return Items ---

  Future<List<Map<String, Object?>>> fetchSupplierReturnItems() async {
    final db = await database;
    return db.query(_tableSupplierReturnItems, orderBy: 'id ASC');
  }

  Future<int> insertSupplierReturnItem(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tableSupplierReturnItems, values);
  }

  Future<void> deleteSupplierReturnItemsByReturn(int returnId) async {
    final db = await database;
    await db.delete(
      _tableSupplierReturnItems,
      where: 'return_id = ?',
      whereArgs: [returnId],
    );
  }

  Future<void> deleteSupplierReturnItem(int id) async {
    final db = await database;
    await db.delete(
      _tableSupplierReturnItems,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Inventory Movements ---

  Future<List<Map<String, Object?>>> fetchInventoryMovements() async {
    final db = await database;
    return db.query(_tableInventoryMovements, orderBy: 'movement_date DESC');
  }

  Future<int> insertInventoryMovement(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tableInventoryMovements, values);
  }

  Future<void> deleteInventoryMovementsByReference(
    String referenceType,
    int referenceId,
  ) async {
    final db = await database;
    await db.delete(
      _tableInventoryMovements,
      where: 'reference_type = ? AND reference_id = ?',
      whereArgs: [referenceType, referenceId],
    );
  }
}
