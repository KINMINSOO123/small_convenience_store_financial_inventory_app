import 'package:flutter/foundation.dart';

import '../models/inventory_item.dart';
import '../models/purchase_entry.dart';
import '../models/stock_batch.dart';
import '../repositories/inventory_repository.dart';
import '../services/inventory_service.dart';

class InventoryController extends ChangeNotifier {
  InventoryController({InventoryService? inventoryService})
    : _service = inventoryService ?? InventoryService(InventoryRepository());

  final InventoryService _service;

  bool _isLoading = false;
  String _searchQuery = '';
  String? _categoryFilter;
  PurchaseFilter _purchaseFilter = PurchaseFilter.all;

  bool get isLoading => _isLoading;

  String? get categoryFilter => _categoryFilter;

  int get lowStockThreshold => _service.lowStockThreshold;

  PurchaseFilter get purchaseFilter => _purchaseFilter;

  List<InventoryItem> get items {
    final query = _searchQuery.trim().toLowerCase();
    return List.unmodifiable(
      _service.items.where((item) {
        final matchesQuery =
            query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query);
        final matchesCategory =
            _categoryFilter == null || item.category == _categoryFilter;
        return matchesQuery && matchesCategory;
      }),
    );
  }

  List<InventoryItem> get allItems => List.unmodifiable(_service.items);

  List<PurchaseEntry> get purchases {
    final list = _service.purchases.toList();
    switch (_purchaseFilter) {
      case PurchaseFilter.active:
        return List.unmodifiable(list.where((entry) => !entry.isCancelled));
      case PurchaseFilter.cancelled:
        return List.unmodifiable(list.where((entry) => entry.isCancelled));
      case PurchaseFilter.all:
        return List.unmodifiable(list);
    }
  }

  List<PurchaseEntry> get allPurchases => List.unmodifiable(_service.purchases);

  List<StockBatch> get batches => List.unmodifiable(_service.batches);

  int get totalQuantity => _service.totalQuantity;

  double get totalValue => _service.totalValue;

  List<String> get categories {
    final values = _service.categories.toSet().toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<InventoryItem> itemsForCategory(String category) {
    return List.unmodifiable(
      _service.items.where((item) => item.category == category),
    );
  }

  int quantityForCategory(String category) {
    return _service.items
        .where((item) => item.category == category)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  double stockValueForCategory(String category) {
    final itemIds = _service.items
        .where((item) => item.category == category)
        .map((item) => item.id)
        .toSet();
    return _service.batches
        .where((batch) => itemIds.contains(batch.itemId))
        .fold(
          0,
          (sum, batch) => sum + (batch.remainingQuantity * batch.unitCost),
        );
  }

  List<StockBatch> stockRotationForItem(int itemId) {
    return _service.stockRotationForItem(itemId);
  }

  Future<bool> addCategory(String name) async {
    final added = await _service.addCategory(name);
    notifyListeners();
    return added;
  }

  Future<bool> renameCategory(String oldName, String newName) async {
    final renamed = await _service.renameCategory(oldName, newName);
    notifyListeners();
    return renamed;
  }

  Future<bool> deleteCategory(String name) async {
    final deleted = await _service.deleteCategory(name);
    notifyListeners();
    return deleted;
  }

  List<InventoryItem> get lowStockItems {
    return _service.items.where((item) => item.isLowStock).toList();
  }

  List<InventoryItem> get expiringSoonItems {
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 7));
    return _service.items.where((item) {
      final expiry = _service.nextExpiryForItem(item.id);
      if (expiry == null) {
        return false;
      }
      return expiry.isAfter(now) && expiry.isBefore(soon);
    }).toList();
  }

  InventoryItem? getItemById(int id) {
    return _service.getItemById(id);
  }

  DateTime? nextExpiryForItem(int itemId) {
    return _service.nextExpiryForItem(itemId);
  }

  bool isItemExpiringSoon(int itemId) {
    return _service.isItemExpiringSoon(itemId);
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    await _service.load();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setSearchQuery(String value) async {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> setCategoryFilter(String? value) async {
    _categoryFilter = value;
    notifyListeners();
  }

  Future<void> setLowStockThreshold(int value) async {
    await _service.setLowStockThreshold(value);
    notifyListeners();
  }

  Future<void> setPurchaseFilter(PurchaseFilter filter) async {
    _purchaseFilter = filter;
    notifyListeners();
  }

  Future<InventoryItem> addItem({
    required String name,
    required String category,
    required int quantity,
    required double sellingPrice,
    required double initialUnitCost,
    required int lowStockThreshold,
  }) async {
    try {
      return await _service.addItem(
        name: name,
        category: category,
        quantity: quantity,
        sellingPrice: sellingPrice,
        initialUnitCost: initialUnitCost,
        lowStockThreshold: lowStockThreshold,
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> addPurchase({
    required int itemId,
    required int quantity,
    required double unitCost,
    required DateTime purchasedAt,
    DateTime? expiryDate,
  }) async {
    await _service.addPurchase(
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      purchasedAt: purchasedAt,
      expiryDate: expiryDate,
    );
    notifyListeners();
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
    await _service.addPurchaseForNewItem(
      name: name,
      category: category,
      quantity: quantity,
      unitCost: unitCost,
      sellingPrice: sellingPrice,
      purchasedAt: purchasedAt,
      expiryDate: expiryDate,
      lowStockThreshold: lowStockThreshold,
    );
    notifyListeners();
  }

  Future<void> updatePurchase({
    required PurchaseEntry existing,
    required int itemId,
    required int quantity,
    required double unitCost,
    required DateTime purchasedAt,
    DateTime? expiryDate,
  }) async {
    await _service.updatePurchase(
      existing: existing,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      purchasedAt: purchasedAt,
      expiryDate: expiryDate,
    );
    notifyListeners();
  }

  Future<void> cancelPurchase(int id, {String? reason}) async {
    await _service.cancelPurchase(id, reason: reason);
    notifyListeners();
  }

  Future<void> deletePurchaseHard(int id) async {
    await _service.deletePurchaseHard(id);
    notifyListeners();
  }

  Future<void> updateItem(InventoryItem updated) async {
    await _service.updateItem(updated);
    notifyListeners();
  }

  Future<void> removeItem(int id) async {
    await _service.removeItem(id);
    notifyListeners();
  }

  Future<String> exportJson() async {
    return _service.exportJson();
  }

  Future<void> importJson(String input) async {
    await _service.importJson(input);
    notifyListeners();
  }

  Future<Map<String, String>> exportCsvFiles() async {
    return _service.exportCsvFiles();
  }

  Future<void> importCsvFiles({
    required String inventoryCsv,
    required String purchasesCsv,
  }) async {
    await _service.importCsvFiles(
      inventoryCsv: inventoryCsv,
      purchasesCsv: purchasesCsv,
    );
    notifyListeners();
  }
}

enum PurchaseFilter { all, active, cancelled }
