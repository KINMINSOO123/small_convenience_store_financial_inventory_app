import 'package:flutter/foundation.dart';

import '../models/supplier_return.dart';
import '../models/supplier_return_item.dart';
import '../services/supplier_return_service.dart';

class SupplierReturnController extends ChangeNotifier {
  SupplierReturnController({
    required SupplierReturnService supplierReturnService,
    this.onInventoryChanged,
  }) : _service = supplierReturnService;

  final SupplierReturnService _service;
  final VoidCallback? onInventoryChanged;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  List<SupplierReturn> get returns => _service.returns;

  List<SupplierReturnItem> get returnItems => _service.returnItems;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    await _service.load();
    _isLoading = false;
    notifyListeners();
  }

  Future<int> createReturn({
    required int purchaseId,
    required DateTime returnDate,
    String? memo,
    required List<SupplierReturnItemDraft> items,
  }) async {
    final id = await _service.createReturn(
      purchaseId: purchaseId,
      returnDate: returnDate,
      memo: memo,
      drafts: items,
    );
    onInventoryChanged?.call();
    notifyListeners();
    return id;
  }

  Future<void> deleteReturn(int returnId) async {
    await _service.deleteReturn(returnId);
    onInventoryChanged?.call();
    notifyListeners();
  }

  List<SupplierReturn> returnsForPurchase(int purchaseId) {
    return _service.returnsForPurchase(purchaseId);
  }

  List<SupplierReturnItem> returnItemsForReturn(int returnId) {
    return _service.returnItemsForReturn(returnId);
  }

  double totalReturnedForPurchase(int purchaseId) {
    return _service.totalReturnedForPurchase(purchaseId);
  }
}
