Draft Active Status System — Implementation Plan
====================================================

Overview
--------
Separate draft and completed states for purchases and sales to prevent
data integrity issues when editing line items that already affect stock,
batches, and movements.

Draft entries allow add/edit/delete of line items with no stock or
movement effects. Completed entries lock line items and only offer
status-changing actions (Cancel, Void, Return to Supplier).

Status Flows
-------------

Purchases:  DRAFT → ACTIVE → CANCELLED
Sales:      DRAFT → ACTIVE → VOID

| Status    | Purchase                                    | Sale                                         |
|-----------|---------------------------------------------|----------------------------------------------|
| DRAFT     | Add/edit/delete items. No stock effect.     | Add/edit/delete items. No stock effect.       |
|           | "Complete Purchase" button.                  | "Complete Sale" button.                       |
| ACTIVE    | Stock in. Batches exist. Movements recorded. | Stock consumed. Movements recorded.           |
|           | Cannot edit/delete items.                    | Cannot edit/delete items.                     |
|           | "Return to Supplier" / "Cancel Purchase".   | "Void Sale".                                  |
| CANCELLED | Stock reversed. Can delete permanently     | N/A                                           |
|           | or reactivate.                               |                                               |
| VOID      | N/A                                         | Stock reversed. Can delete permanently        |
|           |                                             | or reactivate.                                |

Existing data: All current purchases are ACTIVE (already completed).
All current sales get status='ACTIVE' via migration default.


Phase A: Database Schema v20
-----------------------------

Bump _dbVersion from 19 to 20.

In onCreate: add status column to sales_entries table definition:
  status TEXT NOT NULL DEFAULT 'ACTIVE'

In onUpgrade (if oldVersion < 20):
  ALTER TABLE sales_entries ADD COLUMN status TEXT NOT NULL DEFAULT 'ACTIVE'

The purchase_entries table already has a status column with values
'ACTIVE' and 'CANCELLED'. We add 'DRAFT' as a third value — no schema
change needed for purchases.

Files: lib/data/inventory_db.dart


Phase B: Model Changes
-----------------------

models/purchase_entry.dart:
- Add: bool get isDraft => status.toUpperCase() == 'DRAFT';
- (isCancelled already exists)

models/sales_entry.dart:
- Add field: final String status (defaults to 'ACTIVE')
- Add: bool get isDraft => status.toUpperCase() == 'DRAFT';
- Add: bool get isVoid => status.toUpperCase() == 'VOID';
- Update toMap() to include 'status' key
- Update fromMap() to read 'status' key (default 'ACTIVE' for null)

Files: lib/models/purchase_entry.dart, lib/models/sales_entry.dart


Phase C: Repository Changes
-----------------------------

No new repository methods needed. Status updates use existing
updateSalesEntry() / updatePurchase() methods.

Files: None


Phase D: Service Changes
-------------------------

PurchaseService changes:

1. addPurchase(): Change default status from 'ACTIVE' to 'DRAFT'
   - Change to status='DRAFT'.

2. addPurchaseWithLineItem():
   - When purchase is DRAFT: create line item in DB only (no batch,
     no inventory update, no movement). Return purchaseId.

3. addLineItemToPurchase():
   - If purchase.isDraft: add line item only (no batch, no inventory,
     no movement).
   - If purchase.isCancelled: throw error.
   - If purchase is ACTIVE: throw StateError('Cannot add items to a
     completed purchase.').

4. deleteLineItemFromPurchase():
   - If purchase.isDraft: delete line item from DB + in-memory.
   - If purchase is ACTIVE: throw StateError.

5. updateLineItemInPurchase():
   - If purchase.isDraft: update line item in DB + in-memory.
   - If purchase is ACTIVE: throw StateError.

6. NEW completePurchase(int id):
   - Find purchase, verify it's DRAFT
   - For each line item:
     a. Create StockBatch
     b. Update inventory quantity (+lineItem.quantity)
     c. Record PURCHASE movement
   - Update purchase status to 'ACTIVE' in DB + in-memory

7. cancelPurchase(): Keep existing behavior for ACTIVE purchases
   with stock consumption check.

8. NEW deleteDraftPurchase(int id):
   - Verify purchase is DRAFT
   - Delete all line items from DB + in-memory
   - Delete purchase from DB + in-memory

SalesService changes:

1. addSale(): Create sale as DRAFT entry.
   - Create sale entry with status='DRAFT'
   - Create line item in DB + in-memory
   - Do NOT call consumeStock()
   - Do NOT record SALE movement

2. addLineItemToSale():
   - If sale.isDraft: add line item only (no consumption, no movement).
     Update sale amount.
   - If sale is ACTIVE: throw StateError.

3. deleteLineItemFromSale():
   - If sale.isDraft: delete line item, update sale amount.
   - If sale is ACTIVE: throw StateError.

4. updateLineItemInSale():
   - If sale.isDraft: update line item, recalculate sale amount.
   - If sale is ACTIVE: throw StateError.

5. NEW completeSale(int id):
   - Find sale, verify it's DRAFT
   - For each line item:
     a. Consume stock via purchaseService.consumeStock()
     b. Compute COGS for each line item
     c. Record SALE movement
     d. Update line item's costOfGoodsSold
   - Update sale status to 'ACTIVE' in DB + in-memory

6. NEW voidSale(int id):
   - Find sale, verify it's ACTIVE
   - For each line item:
     a. Restock via purchaseService.restockFromSale()
     b. Delete SALE inventory movements for this sale
   - Update sale status to 'VOID' in DB + in-memory

7. updateSale(): Only allow for DRAFT sales.

Files: lib/services/purchase_service.dart, lib/services/sales_service.dart


Phase E: Controller Changes
-----------------------------

PurchaseController:
- Add completePurchase(int id) method
- Add deleteDraftPurchase(int id) method
- Update PurchaseFilter enum: { all, draft, active, cancelled }
- Update purchases getter to filter by status

SalesController:
- Add completeSale(int id) method
- Add voidSale(int id) method
- Add SalesFilter enum: { all, draft, active, void_ }
- Add filter state and setter
- Update salesEntries getter for status filtering

Files: lib/controllers/purchase_controller.dart,
       lib/controllers/sales_controller.dart


Phase F: UI Changes
--------------------

purchase_entry_detail_screen.dart:
- DRAFT: "Draft" badge. Add/edit/delete items. "Complete Purchase" + "Delete Draft".
- ACTIVE: "Completed" badge. No add/edit/delete. "Cancel Purchase" + "Return to Supplier".
- CANCELLED: Current behavior (Reactivate + Delete permanently).

sales_entry_detail_screen.dart:
- DRAFT: "Draft" badge. Add/edit/delete items. "Complete Sale" + "Delete Draft".
- ACTIVE: "Completed" badge. No add/edit/delete. "Void Sale".
- VOID: "Void" badge. "Delete permanently" + "Reactivate".

purchases_screen.dart:
- Update PurchaseFilter dropdown: All / Draft / Active / Cancelled
- Show status badge on each list item

sales_screen.dart:
- Add SalesFilter dropdown: All / Draft / Active / Void
- Show status badge on each list item

Files: lib/screens/purchase_entry_detail_screen.dart,
       lib/screens/purchases_screen.dart,
       lib/screens/sales_entry_detail_screen.dart,
       lib/screens/sales_screen.dart


Execution Order
---------------
1. Phase A: DB Schema v20 (inventory_db.dart)
2. Phase B: Model changes (purchase_entry.dart, sales_entry.dart)
3. Phase D: Service changes (purchase_service.dart, sales_service.dart)
4. Phase E: Controller changes (purchase_controller.dart, sales_controller.dart)
5. Phase F: UI changes (4 screen files)


Summary of Files to Modify
---------------------------
1. lib/data/inventory_db.dart
2. lib/models/purchase_entry.dart
3. lib/models/sales_entry.dart
4. lib/services/purchase_service.dart
5. lib/services/sales_service.dart
6. lib/controllers/purchase_controller.dart
7. lib/controllers/sales_controller.dart
8. lib/screens/purchase_entry_detail_screen.dart
9. lib/screens/purchases_screen.dart
10. lib/screens/sales_entry_detail_screen.dart
11. lib/screens/sales_screen.dart