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

  bool get isLoading => _isLoading;

  List<SalesEntry> get salesEntries => _service.salesEntries;

  List<SalesEntryItem> get salesEntryItems => _service.salesEntryItems;

  double totalForSale(int salesId) {
    return _service.totalForSale(salesId);
  }

  List<SalesEntryItem> salesEntryItemsForSale(int salesId) {
    return _service.salesEntryItemsForSale(salesId);
  }

  SalesEntry? findSaleByDate(DateTime date) {
    return _service.findSaleByDate(date);
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
