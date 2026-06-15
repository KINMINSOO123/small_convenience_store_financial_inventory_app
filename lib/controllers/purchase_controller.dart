import 'package:flutter/foundation.dart';

import '../models/purchase_entry.dart';
import '../models/purchase_entry_item.dart';
import '../models/stock_batch.dart';
import '../services/purchase_service.dart';

class PurchaseController extends ChangeNotifier {
  PurchaseController({
    required PurchaseService purchaseService,
    this.onInventoryChanged,
  }) : _service = purchaseService;

  final PurchaseService _service;
  final VoidCallback? onInventoryChanged;
  bool _isLoading = false;
  PurchaseFilter _purchaseFilter = PurchaseFilter.all;

  bool get isLoading => _isLoading;

  PurchaseFilter get purchaseFilter => _purchaseFilter;

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

  List<PurchaseEntryItem> get purchaseEntryItems =>
      _service.purchaseEntryItems;

  double get totalValue => _service.totalValue;

  double totalForPurchase(int purchaseId) {
    return _service.totalForPurchase(purchaseId);
  }

  List<PurchaseEntryItem> purchaseEntryItemsForPurchase(int purchaseId) {
    return _service.purchaseEntryItemsForPurchase(purchaseId);
  }

  PurchaseEntry? findPurchaseByDate(DateTime date) {
    return _service.findPurchaseByDate(date);
  }

  Future<void> addLineItemToPurchase({
    required int purchaseId,
    required int itemId,
    required int quantity,
    required double unitCost,
    DateTime? expiryDate,
  }) async {
    await _service.addLineItemToPurchase(
      purchaseId: purchaseId,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> updatePurchaseEntryMemo(int purchaseId, String? memo) async {
    await _service.updatePurchaseEntryMemo(purchaseId, memo);
    notifyListeners();
  }

  Future<void> deleteLineItemFromPurchase(
    int purchaseId,
    int lineItemId,
  ) async {
    await _service.deleteLineItemFromPurchase(purchaseId, lineItemId);
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> updateLineItemInPurchase({
    required int purchaseId,
    required int lineItemId,
    required int itemId,
    required int quantity,
    required double unitCost,
    DateTime? expiryDate,
  }) async {
    await _service.updateLineItemInPurchase(
      purchaseId: purchaseId,
      lineItemId: lineItemId,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    await _service.load();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setPurchaseFilter(PurchaseFilter filter) async {
    _purchaseFilter = filter;
    notifyListeners();
  }

  Future<int> addPurchase({
    required int itemId,
    required int quantity,
    required double unitCost,
    required DateTime purchaseDate,
    DateTime? expiryDate,
  }) async {
    final id = await _service.addPurchaseWithLineItem(
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      purchaseDate: purchaseDate,
      expiryDate: expiryDate,
    );
    onInventoryChanged?.call();
    notifyListeners();
    return id;
  }

  Future<void> updatePurchase({
    required PurchaseEntry existing,
    required int itemId,
    required int quantity,
    required double unitCost,
    required DateTime purchaseDate,
    DateTime? expiryDate,
  }) async {
    await _service.updatePurchase(
      existing: existing,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
      purchaseDate: purchaseDate,
      expiryDate: expiryDate,
    );
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> cancelPurchase(int id, {String? reason}) async {
    await _service.cancelPurchase(id, reason: reason);
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> deletePurchaseHard(int id) async {
    await _service.deletePurchaseHard(id);
    onInventoryChanged?.call();
    notifyListeners();
  }

  int availableQuantityForItem(int itemId) {
    return _service.availableQuantityForItem(itemId);
  }

  List<StockBatch> stockRotationForItem(int itemId) {
    return _service.stockRotationForItem(itemId);
  }

  DateTime? nextExpiryForItem(int itemId) {
    return _service.nextExpiryForItem(itemId);
  }

  bool isItemExpiringSoon(int itemId) {
    return _service.isItemExpiringSoon(itemId);
  }

  Future<void> deleteItemsPurchases(int itemId) async {
    await _service.deletePurchasesByItem(itemId);
    notifyListeners();
  }

  Future<void> consumeStock({
    required int itemId,
    required int quantity,
  }) async {
    await _service.consumeStock(itemId: itemId, quantity: quantity);
    notifyListeners();
  }

  Future<void> restockFromSale({
    required int itemId,
    required int quantity,
  }) async {
    await _service.restockFromSale(itemId: itemId, quantity: quantity);
    notifyListeners();
  }
}

enum PurchaseFilter { all, active, cancelled }
