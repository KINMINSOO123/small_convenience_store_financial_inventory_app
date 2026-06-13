import 'package:flutter/foundation.dart';

import '../models/inventory_item.dart';
import '../models/stock_batch.dart';
import '../services/inventory_service.dart';
import 'purchase_controller.dart';

class InventoryController extends ChangeNotifier {
  InventoryController({
    required InventoryService inventoryService,
    PurchaseController? purchaseController,
  }) : _service = inventoryService,
       _purchaseController = purchaseController;

  final InventoryService _service;
  final PurchaseController? _purchaseController;
  bool _isLoading = false;
  String _searchQuery = '';
  String? _categoryFilter;

  bool get isLoading => _isLoading;

  String? get categoryFilter => _categoryFilter;

  int get lowStockThreshold => _service.lowStockThreshold;

  List<InventoryItem> get items {
    final query = _searchQuery.trim().toLowerCase();
    final normalizedFilter = _categoryFilter?.trim().toLowerCase();
    return List.unmodifiable(
      _service.items.where((item) {
        final matchesQuery =
            query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query);
        final matchesCategory =
            normalizedFilter == null ||
            item.category.trim().toLowerCase() == normalizedFilter;
        return matchesQuery && matchesCategory;
      }),
    );
  }

  List<InventoryItem> get allItems => List.unmodifiable(_service.items);

  int get totalQuantity => _service.totalQuantity;

  double get totalValue =>
      _purchaseController?.totalValue ?? _service.totalValue;

  List<String> get categories {
    final values = _service.categories.toSet().toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<InventoryItem> itemsForCategory(String category) {
    final normalized = category.trim().toLowerCase();
    return List.unmodifiable(
      _service.items.where(
        (item) => item.category.trim().toLowerCase() == normalized,
      ),
    );
  }

  int quantityForCategory(String category) {
    final normalized = category.trim().toLowerCase();
    return _service.items
        .where((item) => item.category.trim().toLowerCase() == normalized)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  double stockValueForCategory(String category) {
    final purchaseController = _purchaseController;
    if (purchaseController == null) {
      return 0;
    }
    final normalized = category.trim().toLowerCase();
    final itemIds = _service.items
        .where((item) => item.category.trim().toLowerCase() == normalized)
        .map((item) => item.id)
        .toSet();
    return purchaseController.batches
        .where((batch) => itemIds.contains(batch.itemId))
        .fold(
          0,
          (sum, batch) => sum + (batch.remainingQuantity * batch.unitCost),
        );
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
    final purchaseController = _purchaseController;
    if (purchaseController == null) {
      return [];
    }
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 7));
    return _service.items.where((item) {
      final expiry = purchaseController.nextExpiryForItem(item.id);
      if (expiry == null) {
        return false;
      }
      return expiry.isAfter(now) && expiry.isBefore(soon);
    }).toList();
  }

  InventoryItem? getItemById(int id) {
    return _service.getItemById(id);
  }

  List<StockBatch> stockRotationForItem(int itemId) {
    return _purchaseController?.stockRotationForItem(itemId) ?? [];
  }

  bool isItemExpiringSoon(int itemId) {
    return _purchaseController?.isItemExpiringSoon(itemId) ?? false;
  }

  DateTime? nextExpiryForItem(int itemId) {
    return _purchaseController?.nextExpiryForItem(itemId);
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

  Future<InventoryItem> addItem({
    required String name,
    required String category,
    required double sellingPrice,
    required int lowStockThreshold,
  }) async {
    try {
      return await _service.addItem(
        name: name,
        category: category,
        sellingPrice: sellingPrice,
        lowStockThreshold: lowStockThreshold,
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> updateItem(InventoryItem updated) async {
    await _service.updateItem(updated);
    notifyListeners();
  }

  Future<void> removeItem(int id) async {
    final purchaseController = _purchaseController;
    if (purchaseController != null) {
      await purchaseController.deleteItemsPurchases(id);
    }
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
