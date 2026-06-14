# Group Purchase & Sales Entries by Date

## Goal

Enforce a one-entry-per-date business rule for both purchases and sales:

1. **Purchase**: When adding a purchase item, check if a `PurchaseEntry` with the same `purchase_date` already exists. If yes, add the new `PurchaseEntryItem` to that entry. If no, create a new entry.
2. **Sales**: Same logic — one `SalesEntry` per `sales_date`, with multiple `SalesEntryItem` records.
3. **UI**: Add an "Add item" FAB on both detail screens to append line items to existing entries.
4. **Memo**: Editable on both detail screens.

## Current State

- Every call to `addPurchaseWithLineItem()` creates a **new** `PurchaseEntry` — no deduplication.
- Every call to `addSale()` creates a **new** `SalesEntry` — no deduplication.
- Detail screens are read-only with no "Add item" button.
- Cancel purchase reverses stock for all line items (keep this behavior).
- `purchase_entry_items` has a UNIQUE constraint on `(purchase_id, item_id)` which prevents the same item appearing twice in one purchase.

## Changes Required

### Step 1 — DB: Add UNIQUE on date columns + remove item uniqueness constraint (v17)

`lib/data/inventory_db.dart`:

- Bump `_dbVersion` from 16 to 17.
- v17 migration: three table recreations:

```sql
-- 1. purchase_entries: add UNIQUE on purchase_date
CREATE TABLE purchase_entries_new(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_date TEXT NOT NULL UNIQUE,
  memo TEXT,
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  cancel_reason TEXT
);
INSERT INTO purchase_entries_new (id, purchase_date, memo, status, cancel_reason)
  SELECT id, purchase_date, memo, status, cancel_reason FROM purchase_entries;
DROP TABLE purchase_entries;
ALTER TABLE purchase_entries_new RENAME TO purchase_entries;

-- 2. sales_entries: add UNIQUE on sales_date
CREATE TABLE sales_entries_new(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sales_date TEXT NOT NULL UNIQUE,
  memo TEXT,
  amount REAL NOT NULL DEFAULT 0
);
INSERT INTO sales_entries_new (id, sales_date, memo, amount)
  SELECT id, sales_date, memo, amount FROM sales_entries;
DROP TABLE sales_entries;
ALTER TABLE sales_entries_new RENAME TO sales_entries;

-- 3. purchase_entry_items: remove UNIQUE(purchase_id, item_id)
CREATE TABLE purchase_entry_items_new(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_id INTEGER NOT NULL,
  item_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  unit_cost REAL NOT NULL,
  expiry_date TEXT,
  FOREIGN KEY(purchase_id) REFERENCES purchase_entries(id),
  FOREIGN KEY(item_id) REFERENCES inventory_items(id)
);
INSERT INTO purchase_entry_items_new SELECT * FROM purchase_entry_items;
DROP TABLE purchase_entry_items;
ALTER TABLE purchase_entry_items_new RENAME TO purchase_entry_items;
```

- Update `onCreate` for all three tables to match the new schemas (UNIQUE on date columns; no UNIQUE on `purchase_entry_items`).

### Step 2 — Service: `PurchaseService` — find-or-create by date

`lib/services/purchase_service.dart`:

- Add method:
```dart
PurchaseEntry? findPurchaseByDate(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  for (final entry in _purchases) {
    final entryDate = DateTime(
      entry.purchaseDate.year, entry.purchaseDate.month, entry.purchaseDate.day,
    );
    if (entryDate == normalized && !entry.isCancelled) return entry;
  }
  return null;
}
```

- Modify `addPurchaseWithLineItem()`:
  - Normalize the date to date-only.
  - Call `findPurchaseByDate(purchaseDate)`.
  - If an active entry exists for that date, reuse its `purchaseId` — skip creating a new `PurchaseEntry`.
  - If not found, create a new `PurchaseEntry` as before.
  - Either way, add the line item, stock batch, and inventory update.

```dart
Future<int> addPurchaseWithLineItem({
  required int itemId,
  required int quantity,
  required double unitCost,
  required DateTime purchaseDate,
  DateTime? expiryDate,
  String? memo,
}) async {
  if (quantity <= 0) throw StateError('Quantity must be greater than zero.');
  final normalizedDate = DateTime(purchaseDate.year, purchaseDate.month, purchaseDate.day);
  final existing = findPurchaseByDate(normalizedDate);
  int purchaseId;
  if (existing != null) {
    purchaseId = existing.id;
  } else {
    purchaseId = await addPurchase(purchaseDate: normalizedDate, memo: memo);
  }
  // Add line item + stock batch + inventory update (same as before)
  ...
}
```

### Step 3 — Service: `SalesService` — find-or-create by date

`lib/services/sales_service.dart`:

- Add method:
```dart
SalesEntry? findSaleByDate(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  for (final entry in _entries) {
    final entryDate = DateTime(
      entry.salesDate.year, entry.salesDate.month, entry.salesDate.day,
    );
    if (entryDate == normalized) return entry;
  }
  return null;
}
```

- Modify `addSale()`:
  - Normalize the date.
  - Call `findSaleByDate(salesDate)`.
  - If found, reuse that entry's `id` — skip creating header, just add the line item and update the header `amount`.
  - If not found, create a new `SalesEntry` as before.

- When appending a line item to an existing sale, update the header `amount` field:
```dart
final newAmount = entry.amount + (quantity * item.sellingPrice);
final updatedEntry = SalesEntry(
  id: entry.id, salesDate: entry.salesDate, memo: entry.memo, amount: newAmount,
);
await _repository.updateSalesEntry(updatedEntry);
_entries[index] = updatedEntry;
```

### Step 4 — Controller: Add find-by-date methods

`lib/controllers/purchase_controller.dart`:
- Add `PurchaseEntry? findPurchaseByDate(DateTime date)` delegating to `_service.findPurchaseByDate(date)`.

`lib/controllers/sales_controller.dart`:
- Add `SalesEntry? findSaleByDate(DateTime date)` delegating to `_service.findSaleByDate(date)`.

### Step 5 — Service: `PurchaseService` — Add `addLineItemToPurchase()`

`lib/services/purchase_service.dart`:

```dart
Future<void> addLineItemToPurchase({
  required int purchaseId,
  required int itemId,
  required int quantity,
  required double unitCost,
  DateTime? expiryDate,
}) async {
  if (quantity <= 0) throw StateError('Quantity must be greater than zero.');
  final purchase = _purchases.firstWhere((p) => p.id == purchaseId);
  if (purchase.isCancelled) throw StateError('Cannot add items to a cancelled purchase.');

  final lineItem = PurchaseEntryItem(
    id: 0, purchaseId: purchaseId, itemId: itemId,
    quantity: quantity, unitCost: unitCost, expiryDate: expiryDate,
  );
  final lineItemId = await _repository.insertPurchaseEntryItem(lineItem);
  _purchaseEntryItems.add(PurchaseEntryItem(
    id: lineItemId, purchaseId: purchaseId, itemId: itemId,
    quantity: quantity, unitCost: unitCost, expiryDate: expiryDate,
  ));

  final batch = StockBatch(
    id: 0, itemId: itemId, purchaseId: purchaseId,
    receivedAt: purchase.purchaseDate, quantity: quantity,
    remainingQuantity: quantity, unitCost: unitCost, expiryDate: expiryDate,
  );
  final batchId = await _repository.insertBatch(batch);
  _batches.add(StockBatch(
    id: batchId, itemId: itemId, purchaseId: purchaseId,
    receivedAt: purchase.purchaseDate, quantity: quantity,
    remainingQuantity: quantity, unitCost: unitCost, expiryDate: expiryDate,
  ));

  await _updateItemQuantity(itemId, quantityDelta: quantity);
}
```

### Step 6 — Service: `SalesService` — Add `addLineItemToSale()`

`lib/services/sales_service.dart`:

```dart
Future<void> addLineItemToSale({
  required int saleId,
  required int itemId,
  required int quantity,
}) async {
  if (quantity <= 0) return;
  final item = _requireItem(itemId);
  final cogs = _computeCogs(itemId, quantity);
  await _purchaseService.consumeStock(itemId: itemId, quantity: quantity);

  final unitPrice = item.sellingPrice;
  final lineItem = SalesEntryItem(
    id: 0, salesId: saleId, itemId: itemId,
    quantity: quantity, unitPrice: unitPrice, costOfGoodsSold: cogs,
  );
  final lineItemId = await _repository.insertSalesEntryItem(lineItem);
  _entryItems.add(SalesEntryItem(
    id: lineItemId, salesId: saleId, itemId: itemId,
    quantity: quantity, unitPrice: unitPrice, costOfGoodsSold: cogs,
  ));

  // Update header amount
  final index = _entries.indexWhere((e) => e.id == saleId);
  if (index == -1) return;
  final entry = _entries[index];
  final newAmount = entry.amount + (quantity * unitPrice);
  final updatedEntry = SalesEntry(
    id: entry.id, salesDate: entry.salesDate, memo: entry.memo, amount: newAmount,
  );
  await _repository.updateSalesEntry(updatedEntry);
  _entries[index] = updatedEntry;
  _sortEntries();
}
```

### Step 7 — Service: Add `updatePurchaseEntryMemo()` and `updateSalesEntryMemo()`

`lib/services/purchase_service.dart`:
```dart
Future<void> updatePurchaseEntryMemo(int purchaseId, String? memo) async {
  final index = _purchases.indexWhere((p) => p.id == purchaseId);
  if (index == -1) return;
  final existing = _purchases[index];
  final updated = PurchaseEntry(
    id: existing.id, purchaseDate: existing.purchaseDate, memo: memo,
    status: existing.status, cancelReason: existing.cancelReason,
  );
  await _repository.updatePurchase(updated);
  _purchases[index] = updated;
}
```

`lib/services/sales_service.dart`:
```dart
Future<void> updateSalesEntryMemo(int saleId, String memo) async {
  final index = _entries.indexWhere((e) => e.id == saleId);
  if (index == -1) return;
  final existing = _entries[index];
  final updated = SalesEntry(
    id: existing.id, salesDate: existing.salesDate, memo: memo, amount: existing.amount,
  );
  await _repository.updateSalesEntry(updated);
  _entries[index] = updated;
}
```

### Step 8 — Controller: Add new service delegation methods

`lib/controllers/purchase_controller.dart`:
- `PurchaseEntry? findPurchaseByDate(DateTime date)`
- `Future<void> addLineItemToPurchase({required int purchaseId, required int itemId, required int quantity, required double unitCost, DateTime? expiryDate})` — calls `_service.addLineItemToPurchase(...)`, then `onInventoryChanged?.call()` and `notifyListeners()`
- `Future<void> updatePurchaseEntryMemo(int purchaseId, String? memo)` — calls `_service.updatePurchaseEntryMemo(...)`, then `notifyListeners()`

`lib/controllers/sales_controller.dart`:
- `SalesEntry? findSaleByDate(DateTime date)`
- `Future<void> addLineItemToSale({required int saleId, required int itemId, required int quantity})` — calls `_service.addLineItemToSale(...)`, then `onInventoryChanged?.call()` and `notifyListeners()`
- `Future<void> updateSalesEntryMemo(int saleId, String memo)` — calls `_service.updateSalesEntryMemo(...)`, then `notifyListeners()`

### Step 9 — Screen: `PurchaseEntryDetailScreen` — Add item FAB + Edit memo

`lib/screens/purchase_entry_detail_screen.dart`:

- Convert from `StatelessWidget` to `StatefulWidget`.
- Add a `FloatingActionButton.extended` with icon `Icons.add` and label "Add item".
- Tapping it opens a dialog with: item dropdown (filtered by category), quantity, unit cost, expiry date.
- On save, calls `_controller.addLineItemToPurchase(purchaseId: purchase.id, ...)`.
- Add an "Edit memo" icon button in the AppBar actions (or popup menu).
- Tapping it opens a dialog with a TextField pre-filled with the current memo (or empty).
- On save, calls `_controller.updatePurchaseEntryMemo(purchase.id, newMemo)`.

### Step 10 — Screen: `SalesEntryDetailScreen` — Add item FAB + Edit memo

`lib/screens/sales_entry_detail_screen.dart`:

- Convert from `StatelessWidget` to `StatefulWidget`.
- Add a `FloatingActionButton.extended` with icon `Icons.add` and label "Add item".
- Tapping it opens a dialog with: item dropdown (showing stock info), quantity.
- On save, calls `_controller.addLineItemToSale(saleId: sale.id, ...)`.
- Add "Edit memo" option to the existing `PopupMenuButton` (alongside "Delete").
- Tapping it opens a dialog with a TextField pre-filled with the current memo.
- On save, calls `_controller.updateSalesEntryMemo(sale.id, newMemo)`.

## Files Summary

| File | Change |
|------|--------|
| `lib/data/inventory_db.dart` | v17 migration: UNIQUE on `purchase_date` and `sales_date`; remove UNIQUE `(purchase_id, item_id)` from `purchase_entry_items`; update `onCreate` |
| `lib/services/purchase_service.dart` | Add `findPurchaseByDate()`, `addLineItemToPurchase()`, `updatePurchaseEntryMemo()`; modify `addPurchaseWithLineItem()` to find-or-create |
| `lib/services/sales_service.dart` | Add `findSaleByDate()`, `addLineItemToSale()`, `updateSalesEntryMemo()`; modify `addSale()` to find-or-create; update header `amount` when adding items |
| `lib/controllers/purchase_controller.dart` | Add `findPurchaseByDate()`, `addLineItemToPurchase()`, `updatePurchaseEntryMemo()` |
| `lib/controllers/sales_controller.dart` | Add `findSaleByDate()`, `addLineItemToSale()`, `updateSalesEntryMemo()` |
| `lib/screens/purchase_entry_detail_screen.dart` | Convert to StatefulWidget; add "Add item" FAB; add "Edit memo" action |
| `lib/screens/sales_entry_detail_screen.dart` | Convert to StatefulWidget; add "Add item" FAB; add "Edit memo" to popup menu |

## Verification

1. `flutter analyze` — no new errors/warnings.
2. Fresh install: `onCreate` creates tables with UNIQUE on date columns, no UNIQUE on `purchase_entry_items(purchase_id, item_id)`.
3. Upgrade from v16: v17 migration runs without errors.
4. Adding a purchase item on a date that already has an entry → item is appended to the existing entry (no duplicate header).
5. Adding a purchase item on a new date → new entry is created.
6. Detail screen "Add item" button → opens dialog, saves line item, stock updates correctly.
7. Cancel purchase with multiple items → all items' stock is reversed.
8. Edit memo on detail screen → memo is persisted and displayed on return.
9. Same logic works for sales entries.
10. Header `amount` on `SalesEntry` updates correctly when adding/removing line items.
11. `purchase_entry_items` no longer has UNIQUE constraint → same item can appear multiple times in one purchase.