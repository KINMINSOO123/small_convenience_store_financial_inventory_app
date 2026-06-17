import '../models/supplier_return.dart';
import '../models/supplier_return_item.dart';
import '../repositories/supplier_return_repository.dart';
import 'inventory_service.dart';
import 'purchase_service.dart';

class SupplierReturnItemDraft {
  final int purchaseItemId;
  final int itemId;
  final int quantity;

  SupplierReturnItemDraft({
    required this.purchaseItemId,
    required this.itemId,
    required this.quantity,
  });
}

class SupplierReturnService {
  SupplierReturnService(
    this._repository,
    this._purchaseService,
    this._inventoryService,
  );

  final SupplierReturnRepository _repository;
  final PurchaseService _purchaseService;
  final InventoryService _inventoryService;

  final List<SupplierReturn> _returns = [];
  final List<SupplierReturnItem> _returnItems = [];

  List<SupplierReturn> get returns => List.unmodifiable(_returns);

  List<SupplierReturnItem> get returnItems => List.unmodifiable(_returnItems);

  Future<void> load() async {
    await _repository.init();
    final returns = await _repository.fetchSupplierReturns();
    final items = await _repository.fetchSupplierReturnItems();
    _returns
      ..clear()
      ..addAll(returns);
    _returnItems
      ..clear()
      ..addAll(items);
  }

  Future<int> createReturn({
    required int purchaseId,
    required DateTime returnDate,
    String? memo,
    required List<SupplierReturnItemDraft> drafts,
  }) async {
    final purchases = _purchaseService.purchases;
    final purchase = purchases.firstWhere(
      (p) => p.id == purchaseId,
      orElse: () => throw StateError('Purchase not found.'),
    );
    if (purchase.isCancelled) {
      throw StateError('Cannot return items for a cancelled purchase.');
    }

    final items = <SupplierReturnItem>[];
    double totalAmount = 0;

    for (final draft in drafts) {
      final purchaseItem = _purchaseService.purchaseEntryItems.firstWhere(
        (i) => i.id == draft.purchaseItemId,
        orElse: () => throw StateError(
          'Purchase line item ${draft.purchaseItemId} not found.',
        ),
      );
      if (purchaseItem.itemId != draft.itemId) {
        throw StateError(
          'Item mismatch for purchase line item ${draft.purchaseItemId}.',
        );
      }

      if (draft.quantity <= 0) {
        continue;
      }

      final available =
          _purchaseService.availableQuantityForPurchaseItem(draft.purchaseItemId);
      if (available < draft.quantity) {
        final item = _inventoryService.getItemById(draft.itemId);
        final name = item?.name ?? 'Item #${draft.itemId}';
        throw StateError(
          'Not enough stock to return. $name has only $available '
          'units from this purchase line item, but ${draft.quantity} requested.',
        );
      }

      items.add(SupplierReturnItem(
        id: 0,
        returnId: 0,
        itemId: draft.itemId,
        purchaseItemId: draft.purchaseItemId,
        quantity: draft.quantity,
        unitCost: purchaseItem.unitCost,
      ));

      totalAmount += draft.quantity * purchaseItem.unitCost;
    }

    if (items.isEmpty) {
      throw StateError('No items to return.');
    }

    final returnEntry = SupplierReturn(
      id: 0,
      returnDate: returnDate,
      purchaseId: purchaseId,
      memo: memo,
      totalAmount: totalAmount,
    );
    final returnId = await _repository.insertSupplierReturn(returnEntry);
    final storedReturn = SupplierReturn(
      id: returnId,
      returnDate: returnDate,
      purchaseId: purchaseId,
      memo: memo,
      totalAmount: totalAmount,
    );
    _returns.insert(0, storedReturn);

    for (final item in items) {
      final itemId =
          await _repository.insertSupplierReturnItem(SupplierReturnItem(
        id: 0,
        returnId: returnId,
        itemId: item.itemId,
        purchaseItemId: item.purchaseItemId,
        quantity: item.quantity,
        unitCost: item.unitCost,
      ));
      final storedItem = SupplierReturnItem(
        id: itemId,
        returnId: returnId,
        itemId: item.itemId,
        purchaseItemId: item.purchaseItemId,
        quantity: item.quantity,
        unitCost: item.unitCost,
      );
      _returnItems.add(storedItem);

      await _purchaseService.consumeStockFromPurchaseItem(
        purchaseItemId: item.purchaseItemId,
        itemId: item.itemId,
        quantity: item.quantity,
      );

      await _inventoryService.recordMovement(
        itemId: item.itemId,
        movementType: 'SUPPLIER_RETURN',
        quantity: -item.quantity,
        unitCost: item.unitCost,
        movementDate: returnDate,
        referenceType: 'SUPPLIER_RETURN',
        referenceId: returnId,
      );
    }

    return returnId;
  }

  Future<void> deleteReturn(int returnId) async {
    final returnIndex = _returns.indexWhere((r) => r.id == returnId);
    if (returnIndex == -1) return;

    final items =
        _returnItems.where((i) => i.returnId == returnId).toList();

    await _inventoryService.deleteMovementsByReference(
      'SUPPLIER_RETURN',
      returnId,
    );

    await _repository.deleteSupplierReturnItemsByReturn(returnId);
    _returnItems.removeWhere((i) => i.returnId == returnId);

    await _repository.deleteSupplierReturn(returnId);
    _returns.removeAt(returnIndex);

    for (final item in items) {
      await _purchaseService.restockFromReturn(
        purchaseItemId: item.purchaseItemId,
        itemId: item.itemId,
        quantity: item.quantity,
      );
    }
  }

  List<SupplierReturn> returnsForPurchase(int purchaseId) {
    return _returns.where((r) => r.purchaseId == purchaseId).toList();
  }

  List<SupplierReturnItem> returnItemsForReturn(int returnId) {
    return _returnItems.where((i) => i.returnId == returnId).toList();
  }

  double totalReturnedForPurchase(int purchaseId) {
    return _returns
        .where((r) => r.purchaseId == purchaseId)
        .fold(0.0, (sum, r) => sum + r.totalAmount);
  }

  double totalReturnedForPurchaseItem(int purchaseItemId) {
    return _returnItems
        .where((i) => i.purchaseItemId == purchaseItemId)
        .fold(0.0, (sum, i) => sum + i.subtotal);
  }
}
