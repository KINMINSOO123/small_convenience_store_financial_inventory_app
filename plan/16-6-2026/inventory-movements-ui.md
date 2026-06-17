Inventory Movements UI — Implementation Plan
==============================================

Overview
--------
Add a Movements section to the Inventory Item Detail Screen that displays
the movement history for a specific item. Movements are already recorded in
the inventory_movements DB table (currently only for supplier returns; purchase
and sale movements can be added later).

Design decisions:
- Movements are shown per-item on the Inventory Item Detail Screen
- Movement type displayed with icon and label
- Negative quantities (outbound) shown in red, positive (inbound) in green
- Reference type + ID shown as tappable text (navigates to the source entry)
- Movements sorted newest-first


Step 1: Add movements to InventoryService
-------------------------------------------

Modify lib/services/inventory_service.dart:

- Add import for InventoryMovement model and InventoryRepository.fetchInventoryMovements
- Add a List<InventoryMovement> _movements = [] field
- Add a getter: List<InventoryMovement> get movements => List.unmodifiable(_movements)
- In load(), after existing loads, add:
    final movementRows = await _inventoryRepository.fetchInventoryMovements();
    _movements..clear()..addAll(movementRows);
- Add a helper method:
    List<InventoryMovement> movementsForItem(int itemId) =>
        _movements.where((m) => m.itemId == itemId).toList()
          ..sort((a, b) => b.movementDate.compareTo(a.movementDate));


Step 2: Add movements to InventoryController
---------------------------------------------

Modify lib/controllers/inventory_controller.dart:

- Add import for InventoryMovement model
- Add a getter:
    List<InventoryMovement> movementsForItem(int itemId) =>
        _service.movementsForItem(itemId);


Step 3: Add Movements section to InventoryItemDetailScreen
-----------------------------------------------------------

Modify lib/screens/inventory_item_detail_screen.dart:

- Add import for InventoryMovement model
- Change from StatelessWidget to StatefulWidget (needed for navigation)
- In the AnimatedBuilder body, after the Stock Batches section, add
  a "Movements (N)" section that lists movements for this item.

Movement row layout:
┌────────────────────────────────────────────────────────────┐
│ [icon] SUPPLIER_RETURN     2026-06-16                      │
│        -5 units × $2.50 = -$12.50                         │
│        Ref: Supplier Return #3                              │
├────────────────────────────────────────────────────────────┤
│ [icon] PURCHASE            2026-06-12                      │
│        +100 units × $2.50 = $250.00                        │
│        Ref: Purchase #1                                    │
└────────────────────────────────────────────────────────────┘

Movement type icons:
- PURCHASE           → Icons.add_circle_outline (green)
- SALE               → Icons.remove_circle_outline (red)
- SUPPLIER_RETURN    → Icons.replay_outlined (orange/amber)
- CANCEL_PURCHASE    → Icons.cancel_outlined (red)

- Negative quantities (outbound) colored with theme.colorScheme.error
- Positive quantities (inbound) colored with theme.colorScheme.primary
- Total value = quantity * unitCost, prefixed with + or -

Currently only SUPPLIER_RETURN movements are recorded. PURCHASE, SALE, and
CANCEL_PURCHASE movement types exist in the schema but will be populated in
a future enhancement. The UI should show all types that have data.


Step 4: Record purchase movements (future enhancement, NOT in this change)
---------------------------------------------------------------------------

Deferred — the inventory_movements table is ready for purchase and sale
movements, but recording those will be added separately later.


Summary of Files to Modify
---------------------------
1. lib/services/inventory_service.dart — add _movements list, load movements, movementsForItem()
2. lib/controllers/inventory_controller.dart — expose movementsForItem()
3. lib/screens/inventory_item_detail_screen.dart — add Movements section