Supplier Return System — Implementation Plan
==============================================

Overview
--------
Add Supplier Return functionality that allows returning items from an active
purchase back to the supplier. Stock is consumed via FEFO/FIFO (same as sales).
Also adds cancel-purchase restriction and inventory_movements audit table.

Design decisions (from Q&A):
- Keep Cancel + add "Return to Supplier"; cancelled purchases can be hard-deleted
- Cancel restricted: only when NO stock from that purchase has been consumed
  (all batches for the purchase have remainingQuantity == quantity)
- Returns happen at the **line-item level** (supplier_return_items references purchase_item_id)
- Multiple returns per purchase allowed; each return reduces available stock
- Return date is independent from purchase date
- Returns have NO status field — always completed immediately
- "stock is not enough to return" error if insufficient available stock
- total_amount on supplier_returns is computed from return items
- Stock consumed via FEFO/FIFO (same as sales)
- UI: "Return to Supplier" action within purchase detail screen (no separate tab)
- inventory_movements table created from day one


Phase 1: Database Schema v19
-----------------------------

Bump _dbVersion from 18 to 19.

New tables in onCreate AND in onUpgrade (if oldVersion < 19):

1. supplier_returns
   - id              INTEGER PRIMARY KEY AUTOINCREMENT
   - return_date     TEXT NOT NULL
   - purchase_id     INTEGER NOT NULL  FK → purchase_entries(id)
   - memo            TEXT
   - total_amount    REAL NOT NULL DEFAULT 0

2. supplier_return_items
   - id              INTEGER PRIMARY KEY AUTOINCREMENT
   - return_id       INTEGER NOT NULL  FK → supplier_returns(id)
   - item_id         INTEGER NOT NULL  FK → inventory_items(id)
   - purchase_item_id INTEGER NOT NULL FK → purchase_entry_items(id)
   - quantity        INTEGER NOT NULL
   - unit_cost       REAL NOT NULL

3. inventory_movements
   - id              INTEGER PRIMARY KEY AUTOINCREMENT
   - item_id         INTEGER NOT NULL  FK → inventory_items(id)
   - batch_id        INTEGER            FK → stock_batches(id)   (nullable)
   - movement_type   TEXT NOT NULL    -- PURCHASE, SALE, SUPPLIER_RETURN, CANCEL_PURCHASE
   - quantity        INTEGER NOT NULL -- positive=inbound, negative=outbound
   - unit_cost       REAL NOT NULL
   - movement_date   TEXT NOT NULL
   - reference_type  TEXT NOT NULL    -- PURCHASE, SALE, SUPPLIER_RETURN
   - reference_id    INTEGER NOT NULL -- FK to the header record

New constants:
  _tableSupplierReturns = 'supplier_returns'
  _tableSupplierReturnItems = 'supplier_return_items'
  _tableInventoryMovements = 'inventory_movements'

New CRUD methods in InventoryDb:
  // Supplier returns
  Future<List<Map<String, Object?>>> fetchSupplierReturns()
  Future<int> insertSupplierReturn(Map<String, Object?> values)
  Future<void> updateSupplierReturn(Map<String, Object?> values, int id)
  Future<void> deleteSupplierReturn(int id)
  Future<List<Map<String, Object?>>> fetchSupplierReturnsByPurchase(int purchaseId)

  // Supplier return items
  Future<List<Map<String, Object?>>> fetchSupplierReturnItems()
  Future<int> insertSupplierReturnItem(Map<String, Object?> values)
  Future<void> deleteSupplierReturnItemsByReturn(int returnId)
  Future<void> deleteSupplierReturnItem(int id)

  // Inventory movements
  Future<List<Map<String, Object?>>> fetchInventoryMovements()
  Future<int> insertInventoryMovement(Map<String, Object?> values)
  Future<void> deleteInventoryMovementsByReference(String referenceType, int referenceId)

  // clearAll() — add deletions for the 3 new tables

Files: lib/data/inventory_db.dart


Phase 2: Models
---------------

New file: lib/models/supplier_return.dart

  class SupplierReturn {
    final int id;
    final DateTime returnDate;
    final int purchaseId;
    final String? memo;
    final double totalAmount;
    // toMap / fromMap
    // Keys: id, return_date, purchase_id, memo, total_amount
  }

New file: lib/models/supplier_return_item.dart

  class SupplierReturnItem {
    final int id;
    final int returnId;
    final int itemId;
    final int purchaseItemId;
    final int quantity;
    final double unitCost;
    double get subtotal => quantity * unitCost;
    // toMap / fromMap
    // Keys: id, return_id, item_id, purchase_item_id, quantity, unit_cost
  }

New file: lib/models/inventory_movement.dart

  class InventoryMovement {
    final int id;
    final int itemId;
    final int? batchId;
    final String movementType;   // PURCHASE, SALE, SUPPLIER_RETURN, CANCEL_PURCHASE
    final int quantity;          // + inbound, - outbound
    final double unitCost;
    final DateTime movementDate;
    final String referenceType;  // PURCHASE, SALE, SUPPLIER_RETURN
    final int referenceId;
    // toMap / fromMap
    // Keys: id, item_id, batch_id, movement_type, quantity, unit_cost,
    //       movement_date, reference_type, reference_id
  }

Files: lib/models/supplier_return.dart, lib/models/supplier_return_item.dart,
       lib/models/inventory_movement.dart


Phase 3: Repository
-------------------

New file: lib/repositories/supplier_return_repository.dart

  class SupplierReturnRepository {
    SupplierReturnRepository({InventoryDb? database})
      : _database = database ?? InventoryDb();
    final InventoryDb _database;

    Future<void> init() async => await _database.init();

    // SupplierReturn header CRUD
    Future<List<SupplierReturn>> fetchSupplierReturns() async
    Future<int> insertSupplierReturn(SupplierReturn entry) async
    Future<void> updateSupplierReturn(SupplierReturn entry) async
    Future<void> deleteSupplierReturn(int id) async
    Future<List<SupplierReturn>> fetchSupplierReturnsByPurchase(int purchaseId) async

    // SupplierReturnItem line CRUD
    Future<List<SupplierReturnItem>> fetchSupplierReturnItems() async
    Future<int> insertSupplierReturnItem(SupplierReturnItem item) async
    Future<void> deleteSupplierReturnItemsByReturn(int returnId) async
    Future<void> deleteSupplierReturnItem(int id) async

    // InventoryMovement CRUD
    Future<List<InventoryMovement>> fetchInventoryMovements() async
    Future<int> insertInventoryMovement(InventoryMovement movement) async
    Future<void> deleteInventoryMovementsByReference(String referenceType, int referenceId) async
  }

All methods delegate to InventoryDb and convert via toMap/fromMap.

Files: lib/repositories/supplier_return_repository.dart


Phase 4: Service
----------------

New file: lib/services/supplier_return_service.dart

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
    final List<InventoryMovement> _movements = [];

    // Getters
    List<SupplierReturn> get returns => List.unmodifiable(_returns);
    List<SupplierReturnItem> get returnItems => List.unmodifiable(_returnItems);
    List<InventoryMovement> get movements => List.unmodifiable(_movements);

    Future<void> load() async { ... }

    // --- Core method: createReturn ---
    Future<int> createReturn({
      required int purchaseId,
      required DateTime returnDate,
      String? memo,
      required List<SupplierReturnItemDraft> items,  // input DTO
    }) async {
      // 1. Validate purchase exists and is ACTIVE
      // 2. For each draft item:
      //    a. Look up the PurchaseEntryItem by purchaseItemId
      //    b. Validate that itemId matches
      //    c. Validate available stock for the item >= requested quantity
      //       (use _purchaseService.availableQuantityForItem)
      //    d. If not enough: throw StateError('Stock is not enough to return')
      // 3. Use unit_cost from the PurchaseEntryItem (original purchase cost),
      //    NOT from the FEFO/FIFO batch
      // 4. Consume stock: call _purchaseService.consumeStock(itemId, quantity)
      //    for each item (FEFO/FIFO rotation across ALL batches for the item)
      // 5. Create SupplierReturn header in DB + in-memory
      // 6. Create SupplierReturnItem rows in DB + in-memory
      // 7. Compute totalAmount = sum of (quantity * unitCost) for all items
      // 8. Update header totalAmount in DB + in-memory
      // 9. Record inventory_movements (SUPPLIER_RETURN, negative quantity)
      //    per item with reference_type='SUPPLIER_RETURN', reference_id=returnId
      // 10. Return the return ID
    }

    // --- Delete a supplier return (undo) ---
    Future<void> deleteReturn(int returnId) async {
      // 1. Find the return and its items
      // 2. For each return item: restock via _purchaseService.restockFromSale()
      //    (reuses LIFO restock logic — adds back to batches, updates inventory)
      // 3. Delete inventory_movements for this return
      // 4. Delete return items from DB + in-memory
      // 5. Delete return header from DB + in-memory
    }

    // --- Query helpers ---
    List<SupplierReturn> returnsForPurchase(int purchaseId)
    List<SupplierReturnItem> returnItemsForReturn(int returnId)
    double totalReturnedForPurchase(int purchaseId)
    double totalReturnedForPurchaseItem(int purchaseItemId)

    // --- Movement recording ---
    Future<void> _recordMovement({
      required int itemId,
      int? batchId,
      required String movementType,
      required int quantity,
      required double unitCost,
      required DateTime movementDate,
      required String referenceType,
      required int referenceId,
    }) async { ... }
  }

  // Input DTO for creating return items
  class SupplierReturnItemDraft {
    final int purchaseItemId;
    final int itemId;
    final int quantity;
    SupplierReturnItemDraft({required this.purchaseItemId, required this.itemId, required this.quantity});
  }

NOTE on unit_cost: The unit_cost on SupplierReturnItem comes from the
PurchaseEntryItem's unit_cost (the original purchase cost), NOT from the
FEFO/FIFO batch. This ensures the return amount matches what was paid.

NOTE on consumeStock: consumeStock uses FEFO/FIFO rotation across ALL batches
for the item (not just the purchase's batches). The returned items may come
from different batches than the original purchase. This is correct — items
are fungible and we always consume expiring stock first.

Files: lib/services/supplier_return_service.dart


Phase 5: Controller
-------------------

New file: lib/controllers/supplier_return_controller.dart

  class SupplierReturnController extends ChangeNotifier {
    SupplierReturnController({
      required SupplierReturnService supplierReturnService,
      this.onInventoryChanged,
    }) : _service = supplierReturnService;

    final SupplierReturnService _service;
    final VoidCallback? onInventoryChanged;
    bool _isLoading = false;

    // Delegates to _service, then calls:
    //   onInventoryChanged?.call();
    //   notifyListeners();

    List<SupplierReturn> get returns => _service.returns;
    List<SupplierReturnItem> get returnItems => _service.returnItems;

    Future<void> loadData() async { ... }

    Future<int> createReturn({
      required int purchaseId,
      required DateTime returnDate,
      String? memo,
      required List<SupplierReturnItemDraft> items,
    }) async {
      final id = await _service.createReturn(...);
      onInventoryChanged?.call();
      notifyListeners();
      return id;
    }

    Future<void> deleteReturn(int returnId) async {
      await _service.deleteReturn(returnId);
      onInventoryChanged?.call();
      notifyListeners();
    }

    List<SupplierReturn> returnsForPurchase(int purchaseId) =>
        _service.returnsForPurchase(purchaseId);
    List<SupplierReturnItem> returnItemsForReturn(int returnId) =>
        _service.returnItemsForReturn(returnId);
    double totalReturnedForPurchase(int purchaseId) =>
        _service.totalReturnedForPurchase(purchaseId);
  }

Files: lib/controllers/supplier_return_controller.dart


Phase 6: Cancel Purchase Restriction
-------------------------------------

Modify PurchaseService.cancelPurchase():

  Future<void> cancelPurchase(int id, {String? reason}) async {
    final index = _purchases.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    final purchase = _purchases[index];
    if (purchase.isCancelled) return;

    // NEW: Check that no stock from this purchase has been consumed
    final purchaseBatches = _batches
        .where((b) => b.purchaseId == purchase.id)
        .toList();
    final anyConsumed = purchaseBatches.any(
        (b) => b.remainingQuantity != b.quantity);
    if (anyConsumed) {
      throw StateError(
        'Cannot cancel — some stock from this purchase has been consumed. '
        'Use "Return to Supplier" instead.',
      );
    }

    // ... existing cancel logic (delete batches, reduce inventory) unchanged
  }

Add a canCancelPurchase(int purchaseId) helper:

  bool canCancelPurchase(int purchaseId) {
    final purchaseBatches = _batches
        .where((b) => b.purchaseId == purchaseId)
        .toList();
    return purchaseBatches.isNotEmpty &&
        purchaseBatches.every((b) => b.remainingQuantity == b.quantity);
  }

Expose via PurchaseController:

  bool canCancelPurchase(int purchaseId) =>
      _service.canCancelPurchase(purchaseId);

Files: lib/services/purchase_service.dart, lib/controllers/purchase_controller.dart


Phase 7: UI — Purchase Detail Screen Modifications
---------------------------------------------------

Modify lib/screens/purchase_entry_detail_screen.dart.

7a. Accept SupplierReturnController as a new required parameter.

7b. In the AnimatedBuilder body, after the "Items" section, add a
    "Returns (N)" section (only if there are returns for this purchase):

    Returns (2)
    ┌─────────────────────────────────────────────────┐
    │ [Avatar] 2026-06-15          -$40.00 (bold)     │
    │          Damaged products                        │
    └─────────────────────────────────────────────────┘
    ┌─────────────────────────────────────────────────┐
    │ [Avatar] 2026-06-16          -$80.00 (bold)     │
    │          Expired items                           │
    └─────────────────────────────────────────────────┘

    Tapping a return card shows a dialog with return item details
    (return date, memo, total, list of returned items with qty x unit_cost = subtotal)
    with a "Delete return" button that reverses the stock effect.

7c. Modify the bottom action row:

    ACTIVE purchase:
    ┌──────────────────────┐  ┌──────────────────────┐
    │  Cancel purchase     │  │  Return to supplier   │
    │  (only if canCancel) │  │  (always available)   │
    └──────────────────────┘  └──────────────────────┘

    - Cancel: disabled (greyed out) if !canCancelPurchase. Show tooltip:
      "Cannot cancel — stock has been consumed. Use Return to Supplier."
    - Return to Supplier: opens a dialog (see 7d)

    CANCELLED purchase:
    ┌──────────────────────┐
    │  Delete permanently  │
    └──────────────────────┘

7d. Return to Supplier dialog flow:

    showDialog with StatefulBuilder:

    ┌─────────────────────────────────────────────────────┐
    │ Return to Supplier                                   │
    │                                                       │
    │ Return date: [____] [Pick date]                       │
    │ Memo:         [________________]                      │
    │                                                       │
    │ Items:                                               │
    │ ┌─────────────────────────────────────────────────┐  │
    │ │ Coke  (Purchased: 100, Available: 70)           │  │
    │ │ Return qty: [____]                               │  │
    │ └─────────────────────────────────────────────────┘  │
    │ ┌─────────────────────────────────────────────────┐  │
    │ │ Bread  (Purchased: 20, Available: 20)           │  │
    │ │ Return qty: [____]                               │  │
    │ └─────────────────────────────────────────────────┘  │
    │                                                       │
    │                          [Cancel]  [Return]           │
    └─────────────────────────────────────────────────────┘

    - Return date defaults to today (independent of purchase date)
    - Each line item shows: item name, purchased qty, available qty
    - Available qty = purchaseService.availableQuantityForItem(itemId) (global)
    - Return qty: TextField for each item, default 0
    - Validation: return qty <= available qty, return qty > 0
    - At least one item must have qty > 0
    - On submit: create SupplierReturnItemDraft for each item with qty > 0,
      call controller.createReturn(...)

7e. Return detail dialog (tapping a return card):

    Shows: return date, memo, total amount, list of returned items with
    qty x unit_cost = subtotal. "Delete return" button at bottom with
    confirmation dialog.

Files: lib/screens/purchase_entry_detail_screen.dart


Phase 8: Integration — home_shell.dart
---------------------------------------

8a. Add imports:
  - import '../controllers/supplier_return_controller.dart';
  - import '../repositories/supplier_return_repository.dart';
  - import '../services/supplier_return_service.dart';

8b. Create SupplierReturnRepository, SupplierReturnService,
    SupplierReturnController in _HomeShellState.

    late final SupplierReturnRepository _supplierReturnRepository =
        SupplierReturnRepository(database: _database);
    late final SupplierReturnService _supplierReturnService =
        SupplierReturnService(
          _supplierReturnRepository,
          _purchaseService,
          _inventoryService,
        );
    late final SupplierReturnController _supplierReturnController =
        SupplierReturnController(
          supplierReturnService: _supplierReturnService,
          onInventoryChanged: () {
            _inventoryController.notifyListeners();
            _purchaseController.notifyListeners();
          },
        );

8c. Add _supplierReturnController.loadData() to _loadData() Future.wait.

8d. Dispose _supplierReturnController.

8e. Pass _supplierReturnController to PurchasesScreen (and through to
    PurchaseEntryDetailScreen).

    PurchasesScreen needs to accept and forward supplierReturnController.

Files: lib/screens/home_shell.dart, lib/screens/purchases_screen.dart


Phase 9: Inventory Movements Recording (Scope)
-----------------------------------------------

Included now:
- Supplier return movements (recorded in SupplierReturnService.createReturn())
- Movement deletion when a return is deleted

Deferred to future enhancement:
- Purchase movement recording (requires injecting movement capability into PurchaseService)
- Sale movement recording (requires injecting into SalesService)
- Cancel-purchase movement recording

The inventory_movements table is created and functional; only supplier return
movements are populated initially. Purchase/sale movements can be added later
as a separate enhancement.


Execution Order
---------------
1. Phase 1: DB schema v19 (inventory_db.dart)
2. Phase 2: Models (3 new files)
3. Phase 3: Repository (1 new file)
4. Phase 4: Service (1 new file)
5. Phase 5: Controller (1 new file)
6. Phase 6: Cancel restriction (purchase_service.dart, purchase_controller.dart)
7. Phase 8: home_shell.dart integration
8. Phase 7: UI (purchase_entry_detail_screen.dart, purchases_screen.dart)


Summary of Files to Create
---------------------------
1. lib/models/supplier_return.dart
2. lib/models/supplier_return_item.dart
3. lib/models/inventory_movement.dart
4. lib/repositories/supplier_return_repository.dart
5. lib/services/supplier_return_service.dart
6. lib/controllers/supplier_return_controller.dart


Summary of Files to Modify
---------------------------
1. lib/data/inventory_db.dart          — v19 migration, new tables, CRUD methods
2. lib/services/purchase_service.dart  — canCancelPurchase(), cancel restriction
3. lib/controllers/purchase_controller.dart — expose canCancelPurchase()
4. lib/screens/purchase_entry_detail_screen.dart — Returns section, Return dialog, cancel restriction
5. lib/screens/purchases_screen.dart  — accept/forward SupplierReturnController
6. lib/screens/home_shell.dart        — wire SupplierReturnController


Open Questions — Resolved
--------------------------
1. Should the Return dialog allow returning items that weren't in the original
   purchase? No — return items must reference a purchase_item_id from the
   purchase. The dialog only shows line items from that purchase.

2. When a return is deleted (undo), should we also delete the inventory
   movements? Yes — for audit consistency, deleting a return removes its
   movements and reverses the stock effect.

3. Should the "available" quantity shown in the return dialog be the global
   available (across all purchases) or only the stock from this purchase?
   Global available — because FEFO/FIFO consumes from any batch. The user
   needs to know how much total stock is available to return.

4. Should the unit_cost on return items use the purchase line item's unit_cost
   or the current batch unit_cost? Purchase line item's unit_cost — this
   ensures the return amount matches what was paid to the supplier.
