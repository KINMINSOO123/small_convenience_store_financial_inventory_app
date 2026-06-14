# Purchase & Sales Entry Header-Detail Navigation

## Goal

Restructure the Purchases and Sales screens so that each entry is displayed as a **header** (date + total + status). Tapping a header navigates to a **detail screen** showing all line items for that entry.

```
Purchase Entries Screen (list of headers)
    → Tap entry → Purchase Entry Detail Screen (shows all line items)

Sales Entries Screen (list of headers)
    → Tap entry → Sales Entry Detail Screen (shows all line items)
```

Each header shows: **date**, **computed total** (sum of line item subtotals), **status** badge.

## Current State

- `PurchaseEntry` model stores `item_id`, `quantity`, `unit_cost`, `expiry_date` directly on the header — effectively a single-item flat record, not a true header.
- `PurchaseEntryItem` model exists but duplicates the item data from `PurchaseEntry`.
- `SalesEntry` is already a header model (`id`, `entry_date`, `memo`, `amount`), but `amount` is precomputed rather than derived from line items.
- Both screens show flat lists where tapping opens an edit dialog inline.

## Changes Required

### 1. Database Migration (v15) — `lib/data/inventory_db.dart`

Restructure `purchase_entries` to a pure header schema (remove `item_id`, `quantity`, `unit_cost`, `expiry_date`; add `memo`):

```sql
-- New purchase_entries schema:
CREATE TABLE purchase_entries(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  purchased_at TEXT NOT NULL,
  memo TEXT,
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  cancel_reason TEXT
)
```

**Migration v15 steps:**

1. Create `purchase_entries_new` with the header-only schema.
2. Copy header data from old `purchase_entries` (preserve id, purchased_at, status, cancel_reason; set memo = NULL):
   ```sql
   INSERT INTO purchase_entries_new (id, purchased_at, memo, status, cancel_reason)
   SELECT id, purchased_at, NULL, status, cancel_reason
   FROM purchase_entries
   ```
3. Migrate item data from old `purchase_entries` into `purchase_entry_items` (for rows not already having a matching line item):
   ```sql
   INSERT OR IGNORE INTO purchase_entry_items (purchase_id, item_id, quantity, unit_cost, expiry_date)
   SELECT p.id, p.item_id, p.quantity, p.unit_cost, p.expiry_date
   FROM purchase_entries p
   WHERE p.item_id IS NOT NULL
   ```
4. Drop old `purchase_entries`, rename `purchase_entries_new` → `purchase_entries`.
5. Also update `stock_batches.purchase_item_id` references if needed (they reference `purchase_entry_items.id` which is preserved).
6. Update `onCreate` to use the new header-only schema for `purchase_entries`.
7. Update `deletePurchasesByItem()` — the old query `WHERE item_id = ?` won't work since `purchase_entries` no longer has `item_id`. New approach:
   - Find all `purchase_entry_items` with that `item_id`
   - Get their `purchase_id`s
   - Delete the purchase entries by those ids
   - Delete the purchase entry items by `item_id`

### 2. Model Changes

**`lib/models/purchase_entry.dart`** — Rebuild as a header model:

```dart
class PurchaseEntry {
  final int id;
  final DateTime purchasedAt;
  final String memo;
  final String status;
  final String? cancelReason;
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  // Remove: itemId, quantity, unitCost, expiryDate
  // Add: memo
}
```

**`lib/models/purchase_entry_item.dart`** — Keep as-is (already the line item model).

**`lib/models/sales_entry.dart`** — Keep as-is (already a header model).

**`lib/models/sales_entry_item.dart`** — Keep as-is.

### 3. Repository Layer — `lib/repositories/purchase_repository.dart`

- Update `insertPurchase()` / `updatePurchase()` mapping for new header fields (remove item-level fields, add `memo`).
- No new methods needed — `fetchPurchaseEntryItemsByPurchase()` already exists.

### 4. Database Layer — `lib/data/inventory_db.dart`

- Update `insertPurchase()` to work with new header fields.
- Update `updatePurchase()` to work with new header fields.
- Fix `deletePurchasesByItem()` to look up item_id through `purchase_entry_items` join.
- Add v15 migration as described above.
- Update `onCreate` to create `purchase_entries` with header-only schema.

### 5. Service Layer Changes

**`lib/services/purchase_service.dart`:**

- `addPurchase()` → creates a header entry only (no item-level fields). Returns purchaseId.
- `addPurchaseWithLineItem()` → creates header + line item + stock batch + updates inventory quantity. This becomes the primary entry point.
- `updatePurchase()` → updates the header + replaces line items + updates stock batches.
- `cancelPurchase()` → cancels header + reverses all line items' stock effect.
- `deletePurchaseHard()` → deletes header + line items + reverses stock.
- Add computed `totalForPurchase(int purchaseId)` — sums line item `quantity * unit_cost`.
- Remove references to `itemId`, `quantity`, `unitCost`, `expiryDate` from `PurchaseEntry` method signatures.

**`lib/services/sales_service.dart`:**

- `addSale()` already creates header + line item. No major logic change needed.
- Add computed `totalForSale(int salesId)` — sums line item `quantity * unit_price`.

### 6. Controller Changes

**`lib/controllers/purchase_controller.dart`:**

- Add `purchaseEntryItemsForPurchase(int purchaseId)` — filters `_service.purchaseEntryItems` by purchaseId.
- Add `totalForPurchase(int purchaseId)` — sums subtotal of line items.

**`lib/controllers/sales_controller.dart`:**

- Add `salesEntryItemsForSale(int salesId)` — filters `_service.salesEntryItems` by salesId.
- Add `totalForSale(int salesId)` — sums subtotal of line items.

### 7. New Screens

**`lib/screens/purchase_entry_detail_screen.dart`** (NEW):

- Receives: `PurchaseEntry` header, `PurchaseController`, `InventoryController`.
- Displays header info: purchase date, memo, status badge, computed total.
- Lists all `PurchaseEntryItem`s for this purchase using `ListView`.
- Each line item shows: item name, quantity, unit cost, subtotal.
- Actions: Edit button (navigates to edit dialog), Cancel purchase, Delete permanently.
- Back button in AppBar.

**`lib/screens/sales_entry_detail_screen.dart`** (NEW):

- Receives: `SalesEntry` header, `SalesController`, `InventoryController`.
- Displays header info: sale date, memo, computed total.
- Lists all `SalesEntryItem`s for this sale using `ListView`.
- Each line item shows: item name, quantity, unit price, COGS, subtotal.
- Actions: Edit, Delete.
- Back button in AppBar.

### 8. Modify Existing Screens

**`lib/screens/purchases_screen.dart`:**

- Remove inline edit/cancel/delete from each list tile.
- Each list tile shows: **purchase date**, **computed total** (from line items), **status** badge (Active/Cancelled).
- Tapping a list tile navigates to `PurchaseEntryDetailScreen`.
- Keep FAB for "Add purchase".
- The "Add purchase" dialog creates a header + at least one line item.

**`lib/screens/sales_screen.dart`:**

- Each list tile shows: **sale date**, **total amount**, **memo** snippet.
- Tapping navigates to `SalesEntryDetailScreen`.
- Keep FAB for "Add sale".

### 9. Navigation Updates

- `PurchaseEntryDetailScreen` and `SalesEntryDetailScreen` are pushed via `Navigator.push()` from their respective list screens.
- No changes needed in `home_shell.dart` for the bottom navigation structure.

### 10. Update HomeShell / Service Wiring

- `PurchaseService` constructor already takes `(PurchaseRepository, InventoryService)` — no change needed from previous fix.
- Verify `PurchaseController.onInventoryChanged` callback is wired correctly (already done in previous fix).

## Files Summary

| File | Change |
|------|--------|
| `lib/data/inventory_db.dart` | Add v15 migration; update `onCreate`; update `insertPurchase`/`updatePurchase`; fix `deletePurchasesByItem` |
| `lib/models/purchase_entry.dart` | Remove `itemId`, `quantity`, `unitCost`, `expiryDate`; add `memo` |
| `lib/services/purchase_service.dart` | Restructure add/update/cancel/delete for header+line-items; add `totalForPurchase()` |
| `lib/repositories/purchase_repository.dart` | Update field mapping for new `PurchaseEntry` |
| `lib/controllers/purchase_controller.dart` | Add `purchaseEntryItemsForPurchase()`, `totalForPurchase()` |
| `lib/controllers/sales_controller.dart` | Add `salesEntryItemsForSale()`, `totalForSale()` |
| `lib/screens/purchases_screen.dart` | Show header list (date + total + status); tap → navigate to detail |
| `lib/screens/sales_screen.dart` | Show header list (date + total + memo); tap → navigate to detail |
| `lib/screens/purchase_entry_detail_screen.dart` | **NEW** — Detail screen for a purchase entry |
| `lib/screens/sales_entry_detail_screen.dart` | **NEW** — Detail screen for a sales entry |

## Verification

1. Run `flutter analyze` — no new warnings.
2. On a device with existing data (v14 DB), launch the app → v15 migration should run without errors.
3. Existing purchases appear as headers in the list with correct totals.
4. Tap a purchase header → detail screen shows all line items with correct data.
5. Add a new purchase → appears as header in list; tap → detail shows line items.
6. Cancel a purchase → status updates, stock reverses, detail screen reflects changes.
7. Delete a purchase permanently → removes header, line items, and stock effect.
8. Same flow works for sales entries.
9. Fresh install (no DB) → `onCreate` creates correct header-only `purchase_entries` schema.