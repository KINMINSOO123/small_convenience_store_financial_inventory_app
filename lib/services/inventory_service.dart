import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/inventory.dart';
import '../models/inventory_item.dart';
import '../models/inventory_movement.dart';
import '../repositories/inventory_repository.dart';

class InventoryService {
  InventoryService(this._repository);

  final InventoryRepository _repository;
  final Inventory _inventory = Inventory();
  final List<String> _categories = [];

  final List<InventoryMovement> _movements = [];

  static const lowStockSettingKey = 'low_stock_threshold';
  static const _inventoryExpiryCleanupKey = 'inventory_expiry_cleanup';

  int _lowStockThreshold = 5;

  int get lowStockThreshold => _lowStockThreshold;

  List<InventoryItem> get items => List.unmodifiable(_inventory.items);

  List<String> get categories => List.unmodifiable(_categories);

  int get totalQuantity => _inventory.totalQuantity;

  double get totalValue {
    return _inventory.totalValue;
  }

  List<InventoryMovement> get movements => List.unmodifiable(_movements);

  List<InventoryMovement> movementsForItem(int itemId) {
    final list = _movements.where((m) => m.itemId == itemId).toList();
    list.sort((a, b) => b.movementDate.compareTo(a.movementDate));
    return list;
  }

  Future<void> recordMovement({
    required int itemId,
    required String movementType,
    required int quantity,
    required double unitCost,
    required DateTime movementDate,
    required String referenceType,
    required int referenceId,
  }) async {
    final movement = InventoryMovement(
      id: 0,
      itemId: itemId,
      batchId: null,
      movementType: movementType,
      quantity: quantity,
      unitCost: unitCost,
      movementDate: movementDate,
      referenceType: referenceType,
      referenceId: referenceId,
    );
    final id = await _repository.insertInventoryMovement(movement);
    _movements.add(InventoryMovement(
      id: id,
      itemId: itemId,
      batchId: null,
      movementType: movementType,
      quantity: quantity,
      unitCost: unitCost,
      movementDate: movementDate,
      referenceType: referenceType,
      referenceId: referenceId,
    ));
  }

  Future<void> deleteMovementsByReference(
    String referenceType,
    int referenceId,
  ) async {
    await _repository.deleteInventoryMovementsByReference(
      referenceType,
      referenceId,
    );
    _movements.removeWhere(
      (m) => m.referenceType == referenceType && m.referenceId == referenceId,
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
    final movementRows = await _repository.fetchInventoryMovements();

    _inventory.items
      ..clear()
      ..addAll(items);
    _categories
      ..clear()
      ..addAll(_mergedCategories(categories, items));
    _movements
      ..clear()
      ..addAll(movementRows);
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
    required double sellingPrice,
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
    await _repository.deleteItem(id);
    _inventory.items.removeWhere((item) => item.id == id);
  }

  Future<String> exportJson() async {
    final payload = {
      'categories': _categories,
      'items': _inventory.items.map((item) => item.toMap()).toList(),
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

    final inventoryCsv = const ListToCsvConverter().convert(inventoryRows);

    await File(inventoryPath).writeAsString(inventoryCsv);

    return {
      'inventory': inventoryPath,
    };
  }

  Future<void> importCsvFiles({
    required String inventoryCsv,
    required String purchasesCsv,
  }) async {
    final inventoryRows = const CsvToListConverter().convert(inventoryCsv);

    final inventoryItems = _parseInventoryCsv(inventoryRows);

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

  InventoryItem? getItemById(int id) {
    try {
      return _inventory.items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
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
}
