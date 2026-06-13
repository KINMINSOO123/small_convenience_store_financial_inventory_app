import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/inventory.dart';
import '../models/inventory_item.dart';
import '../models/purchase_entry.dart';
import '../models/stock_batch.dart';
import '../repositories/inventory_repository.dart';

class InventoryService {
  InventoryService(this._repository);

  final InventoryRepository _repository;
  final Inventory _inventory = Inventory();
  final List<String> _categories = [];
  final List<PurchaseEntry> _purchases = [];
  final List<StockBatch> _batches = [];

  static const lowStockSettingKey = 'low_stock_threshold';
  static const _inventoryExpiryCleanupKey = 'inventory_expiry_cleanup';

  int _lowStockThreshold = 5;

  int get lowStockThreshold => _lowStockThreshold;

  List<InventoryItem> get items => List.unmodifiable(_inventory.items);

  List<String> get categories => List.unmodifiable(_categories);

  List<PurchaseEntry> get purchases => List.unmodifiable(_purchases);

  List<StockBatch> get batches => List.unmodifiable(_batches);

  int get totalQuantity => _inventory.totalQuantity;

  double get totalValue {
    return _batches.fold(
      0,
      (sum, batch) => sum + (batch.remainingQuantity * batch.unitCost),
    );
  }

  Future<void> load() async {
    await _repository.init();
    await _runInventoryExpiryCleanup();
    final storedThreshold =
        await _repository.fetchSetting(lowStockSettingKey);
    final parsedThreshold = int.tryParse(storedThreshold ?? '');
    _lowStockThreshold = parsedThreshold ?? _lowStockThreshold;

    final items = await _repository.fetchItems();
    final categories = await _repository.fetchCategories();
    final purchaseEntries = await _repository.fetchPurchases();
    final batchEntries = await _repository.fetchBatches();

    _inventory.items
      ..clear()
      ..addAll(items);
    _categories
      ..clear()
      ..addAll(_mergedCategories(categories, items));
    _purchases
      ..clear()
      ..addAll(purchaseEntries);
    _batches
      ..clear()
      ..addAll(batchEntries);
  }

  Future<void> setLowStockThreshold(int value) async {
    if (value <= 0) {
      return;
    }
    _lowStockThreshold = value;
    await _repository.upsertSetting(lowStockSettingKey, value.toString());
  }

  Future<InventoryItem> addItem({
    required String name,
    required String category,
    required int quantity,
    required double sellingPrice,
    required double initialUnitCost,
    required int lowStockThreshold,
  }) async {
    final normalizedName = name.trim();
    final normalizedCategory = category.trim();
    final item = InventoryItem(
      id: 0,
      name: normalizedName,
      category: normalizedCategory,
      quantity: 0,
      sellingPrice: sellingPrice,
      lowStockThreshold: lowStockThreshold,
    );
    final id = await _repository.insertItem(item);
    _addCategoryIfMissing(normalizedCategory);
    final stored = InventoryItem(
      id: id,
      name: normalizedName,
      category: normalizedCategory,
      quantity: 0,
      sellingPrice: sellingPrice,
      lowStockThreshold: lowStockThreshold,
    );
    _inventory.items.add(stored);
    if (quantity > 0) {
      await addPurchase(
        itemId: id,
        quantity: quantity,
        unitCost: initialUnitCost,
        purchasedAt: DateTime.now(),
      );
    }
    return getItemById(id) ?? stored;
  }

  Future<bool> addCategory(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty || _containsCategory(normalized)) {
      return false;
    }
    await _repository.insertCategory(normalized);
    _addCategoryIfMissing(normalized);
    return true;
  }

  Future<bool> renameCategory(String oldName, String newName) async {
    final normalized = newName.trim();
    if (normalized.isEmpty ||
        oldName == normalized ||
        _containsCategory(normalized)) {
      return false;
    }
    await _repository.renameCategory(oldName, normalized);
    for (var i = 0; i < _inventory.items.length; i++) {
      final item = _inventory.items[i];
      if (item.category != oldName) {
        continue;
      }
      _inventory.items[i] = InventoryItem(
        id: item.id,
        name: item.name,
        category: normalized,
        quantity: item.quantity,
        sellingPrice: item.sellingPrice,
        lowStockThreshold: item.lowStockThreshold,
      );
    }
    _categories
      ..removeWhere((category) => category == oldName)
      ..add(normalized)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return true;
  }

  Future<bool> deleteCategory(String name) async {
    if (_inventory.items.any((item) => item.category == name)) {
      return false;
    }
    await _repository.deleteCategory(name);
    _categories.removeWhere((category) => category == name);
    return true;
  }

  Future<void> addPurchase({
    required int itemId,
    required int quantity,
    required double unitCost,
    required DateTime purchasedAt,
    DateTime? expiryDate,
  }) async {
    if (quantity <= 0) {
      throw StateError('Quantity must be greater than zero.');
    }
    final purchase = PurchaseEntry(
      id: 0,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      purchasedAt: purchasedAt,
      status: 'ACTIVE',
      expiryDate: expiryDate,
      cancelReason: null,
    );
    final purchaseId = await _repository.insertPurchase(purchase);
    final storedPurchase = PurchaseEntry(
      id: purchaseId,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      purchasedAt: purchasedAt,
      status: 'ACTIVE',
      expiryDate: expiryDate,
      cancelReason: null,
    );
    final batch = StockBatch(
      id: 0,
      itemId: itemId,
      purchaseId: purchaseId,
      receivedAt: purchasedAt,
      quantity: quantity,
      remainingQuantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    final batchId = await _repository.insertBatch(batch);
    final storedBatch = StockBatch(
      id: batchId,
      itemId: itemId,
      purchaseId: purchaseId,
      receivedAt: purchasedAt,
      quantity: quantity,
      remainingQuantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    _purchases.insert(0, storedPurchase);
    _batches.add(storedBatch);
    await _updateItemQuantity(itemId, quantityDelta: quantity);
  }

  Future<void> addPurchaseForNewItem({
    required String name,
    required String category,
    required int quantity,
    required double unitCost,
    required double sellingPrice,
    required DateTime purchasedAt,
    DateTime? expiryDate,
    int? lowStockThreshold,
  }) async {
    final item = await addItem(
      name: name,
      category: category,
      quantity: 0,
      sellingPrice: sellingPrice,
      initialUnitCost: unitCost,
      lowStockThreshold: lowStockThreshold ?? _lowStockThreshold,
    );
    await addPurchase(
      itemId: item.id,
      quantity: quantity,
      unitCost: unitCost,
      purchasedAt: purchasedAt,
      expiryDate: expiryDate,
    );
  }

  Future<void> updatePurchase({
    required PurchaseEntry existing,
    required int itemId,
    required int quantity,
    required double unitCost,
    required DateTime purchasedAt,
    DateTime? expiryDate,
  }) async {
    if (quantity <= 0) {
      throw StateError('Quantity must be greater than zero.');
    }
    if (existing.isCancelled) {
      return;
    }
    await _repository.updatePurchase(
      PurchaseEntry(
        id: existing.id,
        itemId: itemId,
        quantity: quantity,
        unitCost: unitCost,
        purchasedAt: purchasedAt,
        status: 'ACTIVE',
        expiryDate: expiryDate,
        cancelReason: null,
      ),
    );

    await _repository.deleteBatchesByPurchaseId(existing.id);
    _batches.removeWhere((batch) => batch.purchaseId == existing.id);

    if (existing.itemId != itemId) {
      await _updateItemQuantity(
        existing.itemId,
        quantityDelta: -existing.quantity,
      );
      await _updateItemQuantity(
        itemId,
        quantityDelta: quantity,
      );
    } else {
      await _updateItemQuantity(
        existing.itemId,
        quantityDelta: quantity - existing.quantity,
      );
    }

    final newBatch = StockBatch(
      id: 0,
      itemId: itemId,
      purchaseId: existing.id,
      receivedAt: purchasedAt,
      quantity: quantity,
      remainingQuantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    final batchId = await _repository.insertBatch(newBatch);
    _batches.add(
      StockBatch(
        id: batchId,
        itemId: itemId,
        purchaseId: existing.id,
        receivedAt: purchasedAt,
        quantity: quantity,
        remainingQuantity: quantity,
        unitCost: unitCost,
        expiryDate: expiryDate,
      ),
    );

    final index = _purchases.indexWhere((entry) => entry.id == existing.id);
    if (index != -1) {
      _purchases[index] = PurchaseEntry(
        id: existing.id,
        itemId: itemId,
        quantity: quantity,
        unitCost: unitCost,
        purchasedAt: purchasedAt,
        status: 'ACTIVE',
        expiryDate: expiryDate,
        cancelReason: null,
      );
    }
  }

  Future<void> cancelPurchase(int id, {String? reason}) async {
    final index = _purchases.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return;
    }
    final purchase = _purchases[index];
    if (purchase.isCancelled) {
      return;
    }
    await _repository.updatePurchase(
      PurchaseEntry(
        id: purchase.id,
        itemId: purchase.itemId,
        quantity: purchase.quantity,
        unitCost: purchase.unitCost,
        purchasedAt: purchase.purchasedAt,
        status: 'CANCELLED',
        expiryDate: purchase.expiryDate,
        cancelReason: reason,
      ),
    );
    await _repository.deleteBatchesByPurchaseId(purchase.id);
    _batches.removeWhere((batch) => batch.purchaseId == purchase.id);
    await _updateItemQuantity(
      purchase.itemId,
      quantityDelta: -purchase.quantity,
    );
    _purchases[index] = PurchaseEntry(
      id: purchase.id,
      itemId: purchase.itemId,
      quantity: purchase.quantity,
      unitCost: purchase.unitCost,
      purchasedAt: purchase.purchasedAt,
      status: 'CANCELLED',
      expiryDate: purchase.expiryDate,
      cancelReason: reason,
    );
  }

  Future<void> deletePurchaseHard(int id) async {
    final index = _purchases.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return;
    }
    final purchase = _purchases[index];
    await _repository.deleteBatchesByPurchaseId(purchase.id);
    await _repository.deletePurchase(purchase.id);
    _batches.removeWhere((batch) => batch.purchaseId == purchase.id);
    _purchases.removeAt(index);
    if (!purchase.isCancelled) {
      await _updateItemQuantity(
        purchase.itemId,
        quantityDelta: -purchase.quantity,
      );
    }
  }

  Future<void> updateItem(InventoryItem updated) async {
    final index = _inventory.items.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      return;
    }
    if (updated.quantity < 0) {
      return;
    }
    await _repository.updateItem(updated);
    _addCategoryIfMissing(updated.category);
    _inventory.items[index] = updated;
  }

  Future<void> removeItem(int id) async {
    await _repository.deletePurchasesByItem(id);
    await _repository.deleteBatchesByItem(id);
    await _repository.deleteItem(id);
    _inventory.items.removeWhere((item) => item.id == id);
    _purchases.removeWhere((entry) => entry.itemId == id);
    _batches.removeWhere((batch) => batch.itemId == id);
  }

  Future<String> exportJson() async {
    final payload = {
      'categories': _categories,
      'items': _inventory.items.map((item) => item.toMap()).toList(),
      'purchases': _purchases.map((entry) => entry.toMap()).toList(),
      'batches': _batches.map((batch) => batch.toMap()).toList(),
      'settings': {
        lowStockSettingKey: _lowStockThreshold,
      },
    };
    return jsonEncode(payload);
  }

  Future<void> importJson(String input) async {
    final decoded = jsonDecode(input);
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    final items = (decoded['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((map) => InventoryItem.fromMap(map))
        .toList();
    final purchases = (decoded['purchases'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((map) => PurchaseEntry.fromMap(map))
        .toList();
    final batches = (decoded['batches'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((map) => StockBatch.fromMap(map))
        .toList();
    final settings = decoded['settings'] as Map<String, dynamic>? ?? {};
    final categories = (decoded['categories'] as List<dynamic>? ?? [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();

    await _repository.clearAll();
    for (final category in categories) {
      await _repository.insertCategory(category);
    }
    for (final item in items) {
      await _repository.insertItem(item);
    }
    for (final entry in purchases) {
      await _repository.insertPurchase(entry);
    }
    for (final batch in batches) {
      await _repository.insertBatch(batch);
    }
    if (settings.containsKey(lowStockSettingKey)) {
      final value = settings[lowStockSettingKey];
      if (value is int) {
        await _repository.upsertSetting(lowStockSettingKey, value.toString());
      }
    }
    await load();
  }

  Future<Map<String, String>> exportCsvFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final stamp = _fileTimestamp();
    final inventoryPath = path.join(directory.path, 'inventory_$stamp.csv');
    final purchasesPath = path.join(directory.path, 'purchases_$stamp.csv');

    final inventoryRows = <List<dynamic>>[
      [
        'id',
        'name',
        'category',
        'quantity',
        'selling_price',
        'low_stock_threshold',
      ],
      ..._inventory.items.map(
        (item) => [
          item.id,
          item.name,
          item.category,
          item.quantity,
          item.sellingPrice,
          item.lowStockThreshold,
        ],
      ),
    ];
    final purchaseRows = <List<dynamic>>[
      [
        'id',
        'item_id',
        'quantity',
        'unit_cost',
        'purchased_at',
        'status',
        'cancel_reason',
        'expiry_date',
      ],
      ..._purchases.map(
        (entry) => [
          entry.id,
          entry.itemId,
          entry.quantity,
          entry.unitCost,
          entry.purchasedAt.toIso8601String(),
          entry.status,
          entry.cancelReason ?? '',
          entry.expiryDate?.toIso8601String() ?? '',
        ],
      ),
    ];

    final inventoryCsv = const ListToCsvConverter().convert(inventoryRows);
    final purchasesCsv = const ListToCsvConverter().convert(purchaseRows);

    await File(inventoryPath).writeAsString(inventoryCsv);
    await File(purchasesPath).writeAsString(purchasesCsv);

    return {
      'inventory': inventoryPath,
      'purchases': purchasesPath,
    };
  }

  Future<void> importCsvFiles({
    required String inventoryCsv,
    required String purchasesCsv,
  }) async {
    final inventoryRows = const CsvToListConverter().convert(inventoryCsv);
    final purchaseRows = const CsvToListConverter().convert(purchasesCsv);

    final inventoryItems = _parseInventoryCsv(inventoryRows);
    final purchaseEntries = _parsePurchaseCsv(purchaseRows);

    await _repository.clearAll();
    for (final item in inventoryItems) {
      await _repository.insertItemWithId({
        'id': item.id,
        'name': item.name,
        'category': item.category,
        'quantity': item.quantity,
        'selling_price': item.sellingPrice,
        'low_stock_threshold': item.lowStockThreshold,
      });
    }

    for (final entry in purchaseEntries) {
      await _repository.insertPurchase(entry);
      if (!entry.isCancelled) {
        await _repository.insertBatch(
          StockBatch(
            id: 0,
            itemId: entry.itemId,
            purchaseId: entry.id,
            receivedAt: entry.purchasedAt,
            quantity: entry.quantity,
            remainingQuantity: entry.quantity,
            unitCost: entry.unitCost,
            expiryDate: entry.expiryDate,
          ),
        );
      }
    }

    if (purchaseEntries.isNotEmpty) {
      final totals = <int, int>{};
      for (final entry in purchaseEntries) {
        if (entry.isCancelled) {
          continue;
        }
        totals.update(entry.itemId, (value) => value + entry.quantity,
            ifAbsent: () => entry.quantity);
      }
      for (final item in inventoryItems) {
        final total = totals[item.id];
        if (total != null) {
          await _repository.updateItem(
            InventoryItem(
              id: item.id,
              name: item.name,
              category: item.category,
              quantity: total,
              sellingPrice: item.sellingPrice,
              lowStockThreshold: item.lowStockThreshold,
            ),
          );
        }
      }
    }

    await load();
  }

  List<InventoryItem> _parseInventoryCsv(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return [];
    }
    final headers = _normalizeHeaders(rows.first);
    return rows.skip(1).where((row) => row.isNotEmpty).map((row) {
      final values = _rowToMap(headers, row);
      return InventoryItem(
        id: _parseInt(values['id']) ?? 0,
        name: values['name'] ?? '',
        category: values['category'] ?? '',
        quantity: _parseInt(values['quantity']) ?? 0,
        sellingPrice: _parseDouble(values['selling_price']) ??
            _parseDouble(values['unit_cost']) ??
            0,
        lowStockThreshold:
            _parseInt(values['low_stock_threshold']) ?? _lowStockThreshold,
      );
    }).toList();
  }

  List<PurchaseEntry> _parsePurchaseCsv(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return [];
    }
    final headers = _normalizeHeaders(rows.first);
    return rows.skip(1).where((row) => row.isNotEmpty).map((row) {
      final values = _rowToMap(headers, row);
      return PurchaseEntry(
        id: _parseInt(values['id']) ?? 0,
        itemId: _parseInt(values['item_id']) ?? 0,
        quantity: _parseInt(values['quantity']) ?? 0,
        unitCost: _parseDouble(values['unit_cost']) ?? 0,
        purchasedAt: _parseDate(values['purchased_at']) ?? DateTime.now(),
        status: values['status']?.isEmpty ?? true
            ? 'ACTIVE'
            : (values['status'] ?? 'ACTIVE'),
        expiryDate: _parseDate(values['expiry_date']),
        cancelReason: values['cancel_reason'],
      );
    }).toList();
  }

  List<String> _normalizeHeaders(List<dynamic> headerRow) {
    return headerRow
        .map((value) => value.toString().trim().toLowerCase())
        .toList();
  }

  Map<String, String?> _rowToMap(List<String> headers, List<dynamic> row) {
    final map = <String, String?>{};
    for (var i = 0; i < headers.length; i++) {
      final header = headers[i];
      final value = i < row.length ? row[i] : null;
      map[header] = value?.toString().trim();
    }
    return map;
  }

  int? _parseInt(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  String _fileTimestamp() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '${year}${month}${day}_$hour$minute';
  }

  Future<void> _runInventoryExpiryCleanup() async {
    final done = await _repository.fetchSetting(_inventoryExpiryCleanupKey);
    if (done == 'done') {
      return;
    }
    await _repository.clearInventoryExpiry();
    await _repository.upsertSetting(_inventoryExpiryCleanupKey, 'done');
  }

  Future<void> _updateItemQuantity(
    int itemId, {
    required int quantityDelta,
  }) async {
    final index = _inventory.items.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return;
    }
    final current = _inventory.items[index];
    final nextQuantity = current.quantity + quantityDelta;
    if (nextQuantity < 0) {
      return;
    }
    final updated = InventoryItem(
      id: current.id,
      name: current.name,
      category: current.category,
      quantity: nextQuantity,
      sellingPrice: current.sellingPrice,
      lowStockThreshold: current.lowStockThreshold,
    );
    await _repository.updateItem(updated);
    _inventory.items[index] = updated;
  }

  InventoryItem? getItemById(int id) {
    try {
      return _inventory.items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  DateTime? nextExpiryForItem(int itemId) {
    final expiring = _batches
        .where((batch) =>
            batch.itemId == itemId &&
            batch.remainingQuantity > 0 &&
            batch.expiryDate != null)
        .map((batch) => batch.expiryDate!)
        .toList();
    if (expiring.isEmpty) {
      return null;
    }
    expiring.sort();
    return expiring.first;
  }

  bool isItemExpiringSoon(int itemId) {
    final nextExpiry = nextExpiryForItem(itemId);
    if (nextExpiry == null) {
      return false;
    }
    final now = DateTime.now();
    return nextExpiry.isAfter(now) &&
        nextExpiry.isBefore(now.add(const Duration(days: 7)));
  }

  int availableQuantityForItem(int itemId) {
    return getItemById(itemId)?.quantity ?? 0;
  }

  Future<void> consumeStock({
    required int itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return;
    }
    final available = availableQuantityForItem(itemId);
    if (available < quantity) {
      throw StateError('Not enough stock available.');
    }

    var remaining = quantity;
    final batches = stockRotationForItem(itemId);
    for (final batch in batches) {
      if (remaining <= 0) {
        break;
      }
      if (batch.remainingQuantity <= 0) {
        continue;
      }
      final deduct = remaining < batch.remainingQuantity
          ? remaining
          : batch.remainingQuantity;
      final updated = StockBatch(
        id: batch.id,
        itemId: batch.itemId,
        purchaseId: batch.purchaseId,
        receivedAt: batch.receivedAt,
        quantity: batch.quantity,
        remainingQuantity: batch.remainingQuantity - deduct,
        unitCost: batch.unitCost,
        expiryDate: batch.expiryDate,
      );
      await _repository.updateBatch(updated);
      _replaceBatch(updated);
      remaining -= deduct;
    }

    await _updateItemQuantity(itemId, quantityDelta: -quantity);
  }

  Future<void> restockFromSale({
    required int itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return;
    }
    var remaining = quantity;
    final batches = _sortedBatchesForItem(itemId, ascending: false);
    for (final batch in batches) {
      if (remaining <= 0) {
        break;
      }
      final capacity = batch.quantity - batch.remainingQuantity;
      if (capacity <= 0) {
        continue;
      }
      final add = remaining < capacity ? remaining : capacity;
      final updated = StockBatch(
        id: batch.id,
        itemId: batch.itemId,
        purchaseId: batch.purchaseId,
        receivedAt: batch.receivedAt,
        quantity: batch.quantity,
        remainingQuantity: batch.remainingQuantity + add,
        unitCost: batch.unitCost,
        expiryDate: batch.expiryDate,
      );
      await _repository.updateBatch(updated);
      _replaceBatch(updated);
      remaining -= add;
    }

    await _updateItemQuantity(itemId, quantityDelta: quantity);
  }

  List<StockBatch> _sortedBatchesForItem(
    int itemId, {
    required bool ascending,
  }) {
    final list = _batches.where((batch) => batch.itemId == itemId).toList();
    list.sort((a, b) => ascending
        ? a.receivedAt.compareTo(b.receivedAt)
        : b.receivedAt.compareTo(a.receivedAt));
    return list;
  }

  List<StockBatch> stockRotationForItem(int itemId) {
    final list = _batches
        .where((batch) => batch.itemId == itemId && batch.remainingQuantity > 0)
        .toList();
    list.sort(_compareRotationPriority);
    return list;
  }

  int _compareRotationPriority(StockBatch a, StockBatch b) {
    final aExpiry = a.expiryDate;
    final bExpiry = b.expiryDate;
    if (aExpiry != null && bExpiry != null) {
      final byExpiry = aExpiry.compareTo(bExpiry);
      if (byExpiry != 0) {
        return byExpiry;
      }
    } else if (aExpiry != null) {
      return -1;
    } else if (bExpiry != null) {
      return 1;
    }
    return a.receivedAt.compareTo(b.receivedAt);
  }

  List<String> _mergedCategories(
    List<String> stored,
    List<InventoryItem> items,
  ) {
    final values = {
      ...stored
          .map((category) => category.trim())
          .where((category) => category.isNotEmpty),
      ...items
          .map((item) => item.category.trim())
          .where((name) => name.isNotEmpty),
    }.toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  bool _containsCategory(String name) {
    final normalized = name.trim().toLowerCase();
    return _categories.any(
      (category) => category.trim().toLowerCase() == normalized,
    );
  }

  void _addCategoryIfMissing(String name) {
    final normalized = name.trim();
    if (_containsCategory(normalized)) {
      return;
    }
    _categories
      ..add(normalized)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void _replaceBatch(StockBatch updated) {
    final index = _batches.indexWhere((batch) => batch.id == updated.id);
    if (index != -1) {
      _batches[index] = updated;
    }
  }
}
