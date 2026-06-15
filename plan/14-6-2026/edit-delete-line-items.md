# Edit & Delete Actions for Purchase/Sales Line Items

## Goal

Add Edit and Delete actions for each line item on the Purchase Entry Detail and Sales Entry Detail screens. Also fix a critical bug in batch deletion.

## Key Findings

1. **No single-item CRUD methods** exist for `purchase_entry_items` or `sales_entry_items` — only bulk delete-by-parent
2. **Bug**: `purchase_service.dart` calls `_repository.deleteBatchesByItem(purchase.id)` in `updatePurchase()`, `cancelPurchase()`, and `deletePurchaseHard()`, passing a `purchaseId` to a method that filters by `item_id`. Stock batches are never deleted from the DB — only removed from in-memory lists. After a reload, orphaned batches reappear.
3. **`StockBatch` model** doesn't expose `purchaseItemId` even though the DB column (`purchase_item_id`) exists from v13
4. **`deleteBatchesByPurchaseId()`** exists in the DB layer but isn't exposed through the repository

## Changes Required

### Step 1 — Model: Add `purchaseItemId` to `StockBatch`

`lib/models/stock_batch.dart`:

- Add `final int? purchaseItemId;` field
- Update constructor to accept `purchaseItemId`
- Update `toMap()`: add `'purchase_item_id': purchaseItemId`
- Update `fromMap()`: read from `map['purchase_item_id']`

### Step 2 — DB: Add single-item CRUD for line items

`lib/data/inventory_db.dart`:

Add these methods:

```dart
Future<void> deletePurchaseEntryItem(int id) async {
  final db = await database;
  await db.delete(_tablePurchaseItems, where: 'id = ?', whereArgs: [id]);
}

Future<void> updatePurchaseEntryItem(Map<String, Object?> values, int id) async {
  final db = await database;
  await db.update(_tablePurchaseItems, values, where: 'id = ?', whereArgs: [id]);
}

Future<void> deleteSalesEntryItem(int id) async {
  final db = await database;
  await db.delete(_tableSalesItems, where: 'id = ?', whereArgs: [id]);
}

Future<void> updateSalesEntryItem(Map<String, Object?> values, int id) async {
  final db = await database;
  await db.update(_tableSalesItems, values, where: 'id = ?', whereArgs: [id]);
}
```

### Step 3 — Repository: Add methods + fix batch deletion exposure

`lib/repositories/purchase_repository.dart`:

- Add `Future<void> deletePurchaseEntryItem(int id)` — delegates to `_database.deletePurchaseEntryItem(id)`
- Add `Future<void> updatePurchaseEntryItem(PurchaseEntryItem item)` — delegates to `_database.updatePurchaseEntryItem(item.toMap()..remove('id'), item.id)` (or similar)
- Add `Future<void> deleteBatchesByPurchaseId(int purchaseId)` — delegates to `_database.deleteBatchesByPurchaseId(purchaseId)`

`lib/repositories/sales_repository.dart`:

- Add `Future<void> deleteSalesEntryItem(int id)` — delegates to `_database.deleteSalesEntryItem(id)`
- Add `Future<void> updateSalesEntryItem(SalesEntryItem item)` — delegates to `_database.updateSalesEntryItem(item.toMap()..remove('id'), item.id)` (or similar)

### Step 4 — Service: Fix the batch deletion bug

`lib/services/purchase_service.dart`:

Fix three methods that incorrectly call `_repository.deleteBatchesByItem()` with a `purchaseId` instead of `itemId`:

- `updatePurchase()` line ~163: `_repository.deleteBatchesByItem(existing.id)` → `_repository.deleteBatchesByPurchaseId(existing.id)`
- `cancelPurchase()` line ~254: `_repository.deleteBatchesByItem(purchase.id)` → `_repository.deleteBatchesByPurchaseId(purchase.id)`
- `deletePurchaseHard()` line ~286: `_repository.deleteBatchesByItem(purchase.id)` → `_repository.deleteBatchesByPurchaseId(purchase.id)`

Leave `deletePurchasesByItem(itemId)` unchanged — that one correctly filters by `item_id`.

### Step 5 — Service: Set `purchaseItemId` when creating batches

`lib/services/purchase_service.dart`:

In `addPurchaseWithLineItem()` — after inserting the line item and getting `lineItemId`, set `purchaseItemId: lineItemId` on the `StockBatch`.

In `addLineItemToPurchase()` — same: set `purchaseItemId: lineItemId` on the `StockBatch`.

In `updatePurchase()` — when creating the replacement batch, set `purchaseItemId: lineItemId`.

### Step 6 — Service: Add line item delete/update for purchases

`lib/services/purchase_service.dart`:

```dart
Future<void> deleteLineItemFromPurchase(int purchaseId, int lineItemId) async {
  final lineItemIndex = _purchaseEntryItems.indexWhere((i) => i.id == lineItemId);
  if (lineItemIndex == -1) return;
  final lineItem = _purchaseEntryItems[lineItemIndex];
  final purchase = _purchases.firstWhere((p) => p.id == purchaseId);
  if (purchase.isCancelled) return;

  // Reverse inventory
  await _updateItemQuantity(lineItem.itemId, quantityDelta: -lineItem.quantity);

  // Find and delete the stock batch for this line item
  final batchIndex = _batches.indexWhere(
    (b) => b.purchaseId == purchaseId && b.itemId == lineItem.itemId,
  );
  if (batchIndex != -1) {
    await _repository.deleteBatch(_batches[batchIndex].id);
    _batches.removeAt(batchIndex);
  }

  // Delete the line item
  await _repository.deletePurchaseEntryItem(lineItemId);
  _purchaseEntryItems.removeAt(lineItemIndex);
}

Future<void> updateLineItemInPurchase({
  required int purchaseId,
  required int lineItemId,
  required int itemId,
  required int quantity,
  required double unitCost,
  DateTime? expiryDate,
}) async {
  if (quantity <= 0) throw StateError('Quantity must be greater than zero.');
  final oldItemIndex = _purchaseEntryItems.indexWhere((i) => i.id == lineItemId);
  if (oldItemIndex == -1) return;
  final oldItem = _purchaseEntryItems[oldItemIndex];
  final purchase = _purchases.firstWhere((p) => p.id == purchaseId);
  if (purchase.isCancelled) throw StateError('Cannot edit items in a cancelled purchase.');

  // Reverse old stock
  await _updateItemQuantity(oldItem.itemId, quantityDelta: -oldItem.quantity);

  // Delete old stock batch
  final oldBatchIndex = _batches.indexWhere(
    (b) => b.purchaseId == purchaseId && b.itemId == oldItem.itemId,
  );
  if (oldBatchIndex != -1) {
    await _repository.deleteBatch(_batches[oldBatchIndex].id);
    _batches.removeAt(oldBatchIndex);
  }

  // Update line item in DB
  final updatedLineItem = PurchaseEntryItem(
    id: lineItemId,
    purchaseId: purchaseId,
    itemId: itemId,
    quantity: quantity,
    unitCost: unitCost,
    expiryDate: expiryDate,
  );
  await _repository.updatePurchaseEntryItem(updatedLineItem);
  _purchaseEntryItems[oldItemIndex] = updatedLineItem;

  // Create new stock batch
  final newBatch = StockBatch(
    id: 0,
    itemId: itemId,
    purchaseId: purchaseId,
    purchaseItemId: lineItemId,
    receivedAt: purchase.purchaseDate,
    quantity: quantity,
    remainingQuantity: quantity,
    unitCost: unitCost,
    expiryDate: expiryDate,
  );
  final batchId = await _repository.insertBatch(newBatch);
  _batches.add(StockBatch(
    id: batchId,
    itemId: itemId,
    purchaseId: purchaseId,
    purchaseItemId: lineItemId,
    receivedAt: purchase.purchaseDate,
    quantity: quantity,
    remainingQuantity: quantity,
    unitCost: unitCost,
    expiryDate: expiryDate,
  ));

  // Apply new stock
  await _updateItemQuantity(itemId, quantityDelta: quantity);
}
```

### Step 7 — Service: Add line item delete/update for sales

`lib/services/sales_service.dart`:

```dart
Future<void> deleteLineItemFromSale(int saleId, int lineItemId) async {
  final lineItemIndex = _entryItems.indexWhere((i) => i.id == lineItemId);
  if (lineItemIndex == -1) return;
  final lineItem = _entryItems[lineItemIndex];

  // Restock
  await _purchaseService.restockFromSale(itemId: lineItem.itemId, quantity: lineItem.quantity);

  // Delete line item
  await _repository.deleteSalesEntryItem(lineItemId);
  _entryItems.removeAt(lineItemIndex);

  // Update header amount
  final entryIndex = _entries.indexWhere((e) => e.id == saleId);
  if (entryIndex != -1) {
    final entry = _entries[entryIndex];
    final newAmount = entry.amount - lineItem.subtotal;
    final updated = SalesEntry(
      id: entry.id,
      salesDate: entry.salesDate,
      memo: entry.memo,
      amount: newAmount,
    );
    await _repository.updateSalesEntry(updated);
    _entries[entryIndex] = updated;
  }
  _sortEntries();
}

Future<void> updateLineItemInSale({
  required int saleId,
  required int lineItemId,
  required int itemId,
  required int quantity,
}) async {
  if (quantity <= 0) return;
  final oldItemIndex = _entryItems.indexWhere((i) => i.id == lineItemId);
  if (oldItemIndex == -1) return;
  final oldItem = _entryItems[oldItemIndex];

  // Restock old item
  await _purchaseService.restockFromSale(itemId: oldItem.itemId, quantity: oldItem.quantity);

  // Consume new stock
  final item = _requireItem(itemId);
  final cogs = _computeCogs(itemId, quantity);
  await _purchaseService.consumeStock(itemId: itemId, quantity: quantity);

  // Update line item in DB
  final updatedLineItem = SalesEntryItem(
    id: lineItemId,
    salesId: saleId,
    itemId: itemId,
    quantity: quantity,
    unitPrice: item.sellingPrice,
    costOfGoodsSold: cogs,
  );
  await _repository.updateSalesEntryItem(updatedLineItem);
  _entryItems[oldItemIndex] = updatedLineItem;

  // Update header amount
  final entryIndex = _entries.indexWhere((e) => e.id == saleId);
  if (entryIndex != -1) {
    final entry = _entries[entryIndex];
    final newAmount = entry.amount - oldItem.subtotal + updatedLineItem.subtotal;
    final updatedEntry = SalesEntry(
      id: entry.id,
      salesDate: entry.salesDate,
      memo: entry.memo,
      amount: newAmount,
    );
    await _repository.updateSalesEntry(updated);
    _entries[entryIndex] = updatedEntry;
  }
  _sortEntries();
}
```

### Step 8 — Controllers: Delegate new methods

`lib/controllers/purchase_controller.dart`:

```dart
Future<void> deleteLineItemFromPurchase(int purchaseId, int lineItemId) async {
  await _service.deleteLineItemFromPurchase(purchaseId, lineItemId);
  onInventoryChanged?.call();
  notifyListeners();
}

Future<void> updateLineItemInPurchase({
  required int purchaseId,
  required int lineItemId,
  required int itemId,
  required int quantity,
  required double unitCost,
  DateTime? expiryDate,
}) async {
  await _service.updateLineItemInPurchase(
    purchaseId: purchaseId,
    lineItemId: lineItemId,
    itemId: itemId,
    quantity: quantity,
    unitCost: unitCost,
    expiryDate: expiryDate,
  );
  onInventoryChanged?.call();
  notifyListeners();
}
```

`lib/controllers/sales_controller.dart`:

```dart
Future<void> deleteLineItemFromSale(int saleId, int lineItemId) async {
  await _service.deleteLineItemFromSale(saleId, lineItemId);
  onInventoryChanged?.call();
  notifyListeners();
}

Future<void> updateLineItemInSale({
  required int saleId,
  required int lineItemId,
  required int itemId,
  required int quantity,
}) async {
  await _service.updateLineItemInSale(
    saleId: saleId,
    lineItemId: lineItemId,
    itemId: itemId,
    quantity: quantity,
  );
  onInventoryChanged?.call();
  notifyListeners();
}
```

### Step 9 — Screen: PurchaseEntryDetailScreen — Edit & Delete on each line item

`lib/screens/purchase_entry_detail_screen.dart`:

- Replace the simple `ListTile` for each line item with a `Dismissible` or add a `PopupMenuButton<String>` as `trailing`
- Menu items: **"Edit"**, **"Delete"**
- If the purchase is cancelled, hide both edit and delete
- **Edit dialog**: Pre-filled with current line item values (item, quantity, unit cost, expiry date). On save, calls `_controller.updateLineItemInPurchase()`
- **Delete**: Confirmation dialog, then calls `_controller.deleteLineItemFromPurchase()`

### Step 10 — Screen: SalesEntryDetailScreen — Edit & Delete on each line item

`lib/screens/sales_entry_detail_screen.dart`:

- Add a `PopupMenuButton<String>` as `trailing` on each line item (reorganize the current `trailing` Column with subtotal/COGS into a `Row` with the popup menu)
- Menu items: **"Edit"**, **"Delete"**
- **Edit dialog**: Pre-filled with current item and quantity. Shows stock hint. On save, calls `_controller.updateLineItemInSale()`
- **Delete**: Confirmation dialog, then calls `_controller.deleteLineItemFromSale()`

## Files Summary

| File | Change |
|------|--------|
| `lib/models/stock_batch.dart` | Add `purchaseItemId` field, update `toMap()`/`fromMap()` |
| `lib/data/inventory_db.dart` | Add `deletePurchaseEntryItem`, `updatePurchaseEntryItem`, `deleteSalesEntryItem`, `updateSalesEntryItem` methods |
| `lib/repositories/purchase_repository.dart` | Add `deletePurchaseEntryItem`, `updatePurchaseEntryItem`, `deleteBatchesByPurchaseId`; expose `deleteBatch(int id)` if not already |
| `lib/repositories/sales_repository.dart` | Add `deleteSalesEntryItem`, `updateSalesEntryItem` |
| `lib/services/purchase_service.dart` | Fix batch deletion bug (`deleteBatchesByItem` → `deleteBatchesByPurchaseId`); add `deleteLineItemFromPurchase`, `updateLineItemInPurchase`; set `purchaseItemId` when creating batches |
| `lib/services/sales_service.dart` | Add `deleteLineItemFromSale`, `updateLineItemInSale` |
| `lib/controllers/purchase_controller.dart` | Add `deleteLineItemFromPurchase`, `updateLineItemInPurchase` |
| `lib/controllers/sales_controller.dart` | Add `deleteLineItemFromSale`, `updateLineItemInSale` |
| `lib/screens/purchase_entry_detail_screen.dart` | Add popup menu on each line item with Edit & Delete actions |
| `lib/screens/sales_entry_detail_screen.dart` | Add popup menu on each line item with Edit & Delete actions |

## Verification

1. `flutter analyze` — no new errors/warnings
2. Edit a purchase line item → old stock reversed, new stock applied, total updates
3. Delete a purchase line item → stock reversed, batch deleted, total updates
4. Edit a sales line item → old stock restocked, new stock consumed, header amount updates
5. Delete a sales line item → stock restocked, header amount updates
6. Delete last line item from a purchase → entry stays with "No items." message
7. Delete last line item from a sale → entry stays with "No items." message, amount becomes 0
8. Cancel a purchase → all batches correctly deleted from DB (bug fix confirmed)
9. Delete a purchase permanently → all batches correctly deleted from DB (bug fix confirmed)
10. Stock batch `purchaseItemId` field is correctly set when creating new line items