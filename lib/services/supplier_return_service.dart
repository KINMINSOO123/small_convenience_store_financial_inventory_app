import '../models/inventory_movement.dart';
import '../models/supplier_return.dart';
import '../models/supplier_return_item.dart';
import '../repositories/inventory_repository.dart';
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
    this._inventoryRepository,
  );

  final SupplierReturnRepository _repository;
  final PurchaseService _purchaseService;
  final InventoryService _inventoryService;
  final InventoryRepository _inventoryRepository;

  final List<SupplierReturn> _returns = [];
  final List<SupplierReturnItem> _returnItems = [];
  final List<InventoryMovement> _movements = [];

  List<SupplierReturn> get returns => List.unmodifiable(_returns);

  List<SupplierReturnItem> get returnItems => List.unmodifiable(_returnItems);

  List<InventoryMovement> get movements => List.unmodifiable(_movements);

  Future<void> load() async {
    await _repository.init();
    final returns = await _repository.fetchSupplierReturns();
    final items = await _repository.fetchSupplierReturnItems();
    final movements = await _inventoryRepository.fetchInventoryMovements();
    _returns
      ..clear()
      ..addAll(returns);
    _returnItems
      ..clear()
      ..addAll(items);
    _movements
      ..clear()
      ..addAll(movements);
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
          _purchaseService.availableQuantityForItem(draft.itemId);
      if (available < draft.quantity) {
        final item = _inventoryService.getItemById(draft.itemId);
        final name = item?.name ?? 'Item #${draft.itemId}';
        throw StateError(
          'Stock is not enough to return. $name has only $available '
          'units available, but ${draft.quantity} requested.',
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

      await _purchaseService.consumeStock(
        itemId: item.itemId,
        quantity: item.quantity,
      );

      await _recordMovement(
        itemId: item.itemId,
        batchId: null,
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

    await _inventoryRepository.deleteInventoryMovementsByReference(
      'SUPPLIER_RETURN',
      returnId,
    );
    _movements.removeWhere(
      (m) => m.referenceType == 'SUPPLIER_RETURN' && m.referenceId == returnId,
    );

    await _repository.deleteSupplierReturnItemsByReturn(returnId);
    _returnItems.removeWhere((i) => i.returnId == returnId);

    await _repository.deleteSupplierReturn(returnId);
    _returns.removeAt(returnIndex);

    for (final item in items) {
      await _purchaseService.restockFromSale(
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

  Future<void> _recordMovement({
    required int itemId,
    int? batchId,
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
      batchId: batchId,
      movementType: movementType,
      quantity: quantity,
      unitCost: unitCost,
      movementDate: movementDate,
      referenceType: referenceType,
      referenceId: referenceId,
    );
    final id = await _inventoryRepository.insertInventoryMovement(movement);
    _movements.add(InventoryMovement(
      id: id,
      itemId: itemId,
      batchId: batchId,
      movementType: movementType,
      quantity: quantity,
      unitCost: unitCost,
      movementDate: movementDate,
      referenceType: referenceType,
      referenceId: referenceId,
    ));
  }
}
