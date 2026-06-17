import 'package:flutter/foundation.dart';

import '../models/sales_entry.dart';
import '../models/sales_entry_item.dart';
import '../services/sales_service.dart';

class SalesController extends ChangeNotifier {
  SalesController({
    required SalesService salesService,
    this.onInventoryChanged,
  }) : _service = salesService;

  final SalesService _service;
  final VoidCallback? onInventoryChanged;
  bool _isLoading = false;
  SalesFilter _salesFilter = SalesFilter.all;

  bool get isLoading => _isLoading;

  SalesFilter get salesFilter => _salesFilter;

  List<SalesEntry> get salesEntries {
    final list = _service.salesEntries.toList();
    switch (_salesFilter) {
      case SalesFilter.draft:
        return List.unmodifiable(list.where((entry) => entry.isDraft));
      case SalesFilter.active:
        return List.unmodifiable(
          list.where((entry) => !entry.isDraft && !entry.isVoid),
        );
      case SalesFilter.void_:
        return List.unmodifiable(list.where((entry) => entry.isVoid));
      case SalesFilter.all:
        return List.unmodifiable(list);
    }
  }

  List<SalesEntryItem> get salesEntryItems => _service.salesEntryItems;

  double totalForSale(int salesId) {
    return _service.totalForSale(salesId);
  }

  List<SalesEntryItem> salesEntryItemsForSale(int salesId) {
    return _service.salesEntryItemsForSale(salesId);
  }

  Future<void> addLineItemToSale({
    required int saleId,
    required int itemId,
    required int quantity,
  }) async {
    await _service.addLineItemToSale(
      saleId: saleId,
      itemId: itemId,
      quantity: quantity,
    );
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> updateSalesEntryMemo(int saleId, String memo) async {
    await _service.updateSalesEntryMemo(saleId, memo);
    notifyListeners();
  }

  Future<void> deleteLineItemFromSale(int saleId, int lineItemId) async {
    await _service.deleteLineItemFromSale(saleId, lineItemId);
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> updateLineItemInSale({
    required int saleId,
    required int lineItemId,
    required int itemId,
    required int quantity,
  }) async {
    await _service.updateLineItemInSale(
      saleId: saleId,
      lineItemId: lineItemId,
      itemId: itemId,
      quantity: quantity,
    );
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> setSalesFilter(SalesFilter filter) async {
    _salesFilter = filter;
    notifyListeners();
  }

  Future<void> completeSale(int id) async {
    await _service.completeSale(id);
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> voidSale(int id) async {
    await _service.voidSale(id);
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> reactivateSale(int id) async {
    await _service.reactivateSale(id);
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

  Future<void> addSale({
    required int itemId,
    required int quantity,
    required String memo,
    required DateTime salesDate,
  }) async {
    await _service.addSale(
      itemId: itemId,
      quantity: quantity,
      memo: memo,
      salesDate: salesDate,
    );
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> updateSale({
    required int id,
    required int itemId,
    required int quantity,
    required String memo,
    required DateTime salesDate,
  }) async {
    await _service.updateSale(
      id: id,
      itemId: itemId,
      quantity: quantity,
      memo: memo,
      salesDate: salesDate,
    );
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> deleteSale(int id) async {
    await _service.deleteSale(id);
    onInventoryChanged?.call();
    notifyListeners();
  }
}

enum SalesFilter { all, draft, active, void_ }
