import 'package:flutter/foundation.dart';

import '../models/sales_entry.dart';
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
    required DateTime entryDate,
  }) async {
    await _service.addSale(
      itemId: itemId,
      quantity: quantity,
      memo: memo,
      entryDate: entryDate,
    );
    onInventoryChanged?.call();
    notifyListeners();
  }

  Future<void> updateSale({
    required int id,
    required int itemId,
    required int quantity,
    required String memo,
    required DateTime entryDate,
  }) async {
    await _service.updateSale(
      id: id,
      itemId: itemId,
      quantity: quantity,
      memo: memo,
      entryDate: entryDate,
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
