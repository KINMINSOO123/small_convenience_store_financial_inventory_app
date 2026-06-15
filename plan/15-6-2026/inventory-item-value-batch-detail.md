# Inventory Item Value & Batch Detail Screen

## Goal
1. Show per-item **Value** in the inventory items list (`Value = Σ (batch.remainingQuantity × batch.unitCost)`)
2. When tapping an item, navigate to a **dedicated detail screen** that lists batches sorted by expiry date (FEFO) then purchase date (FIFO)
3. Show **total stock value** (sum of all items' batch-based values) right-aligned above the item list

---

## Current State

- **Inventory items list** (`inventory_screen.dart`): Each item shows `name`, pills for `category`, `quantity units`, `Low at X`. No per-item value. Tapping opens a stock rotation **dialog** (not a screen).
- **Category view**: Already shows `Value` per category (batch-based: `stockValueForCategory`).
- **Stock rotation dialog**: Shows batches sorted FEFO/FIFO with per-batch `Value X.XX`, but it's a modal dialog — limited space, no navigation.
- **Total stock value**: Already displayed in a top `_InfoCard` as `Stock Value` (computed via `PurchaseService.totalValue` = sum of all batches' `remainingQuantity × unitCost`). Positioned on the right side of a Row.
- **`InventoryController`** has `totalValue` and `stockValueForCategory()` but **no per-item value method**.
- **`PurchaseService.stockRotationForItem()`**: Returns batches sorted by `_compareRotationPriority` (expiry ASC, then receivedAt ASC for ties). Only includes batches with `remainingQuantity > 0`.

---

## Changes

### 1. Add `stockValueForItem()` to `InventoryController`

**File**: `lib/controllers/inventory_controller.dart`

Add a method that computes the batch-based value for a single item:

```dart
double stockValueForItem(int itemId) {
  return _purchaseController?.batches
      .where((batch) => batch.itemId == itemId && batch.remainingQuantity > 0)
      .fold(0.0, (sum, batch) => sum + batch.remainingQuantity * batch.unitCost)
      ?? 0.0;
}
```

This mirrors `stockValueForCategory` but filters by `itemId`. Only counts batches with `remainingQuantity > 0`.

### 2. Show per-item Value in the inventory items list

**File**: `lib/screens/inventory_screen.dart`

In the `ListView.separated` for items (around line 504-574), add a Value pill to each item's subtitle `Wrap`:

```dart
_Pill(label: 'Value ${_controller.stockValueForItem(item.id).toStringAsFixed(2)}'),
```

Add it after the existing `'${item.quantity} units'` pill.

### 3. Create `InventoryItemDetailScreen`

**File**: New file `lib/screens/inventory_item_detail_screen.dart`

A `StatelessWidget` that receives an `InventoryItem` and `InventoryController`.

Layout:
```
┌─────────────────────────────────────────┐
│  AppBar: item name                      │
├─────────────────────────────────────────┤
│  Item info card:                         │
│    Name, Category, Quantity              │
│                          Total Value ──► │ right-aligned
├─────────────────────────────────────────┤
│  "Stock Batches (FEFO/FIFO)"             │
│  ┌─────────────────────────────────────┐│
│  │ Batch #1 — Sell first               ││
│  │ X units · Unit cost Y.YY            ││
│  │ Expires YYYY-MM-DD (or No expiry)   ││
│  │ Purchased YYYY-MM-DD                ││
│  │ Value: Z.ZZ                          ││
│  ├─────────────────────────────────────┤│
│  │ Batch #2 — Sell next                ││
│  │ ...                                  ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

Key details:
- **Top section**: Item name, category pill, quantity, and total value (right-aligned). Total value = `controller.stockValueForItem(item.id)`.
- **Batch list**: Uses `controller.stockRotationForItem(item.id)` — already sorted FEFO/FIFO (expiry date ASC, then receivedAt ASC for no-expiry batches).
- **Each batch tile** shows: remaining quantity, unit cost, expiry date (or "No expiry"), purchase date, batch value (remainingQuantity × unitCost).
- **Empty state**: "No stock available" message when no batches have remaining quantity > 0.

### 4. Navigate to detail screen instead of dialog

**File**: `lib/screens/inventory_screen.dart`

Change item `onTap` from `_showStockRotationDialog(item)` to `Navigator.push` to the new `InventoryItemDetailScreen`. Remove the `_showStockRotationDialog` method entirely.

### 5. Verify total stock value display

The total stock value is already displayed in the top `_InfoCard` as "Stock Value" on the right side of the Row. `PurchaseService.totalValue` sums `batch.remainingQuantity × batch.unitCost` for all batches. Since `0 × unitCost = 0`, fully-consumed batches don't affect the total. No change needed.

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/controllers/inventory_controller.dart` | Add `stockValueForItem(int itemId)` method |
| `lib/screens/inventory_screen.dart` | Add Value pill per item; replace dialog tap with `Navigator.push`; remove `_showStockRotationDialog` |
| `lib/screens/inventory_item_detail_screen.dart` | **New file** — Full item detail screen with batch list |

## Files NOT Modified

| File | Reason |
|------|--------|
| `lib/services/purchase_service.dart` | `stockRotationForItem` already returns FEFO/FIFO sorted batches; `totalValue` already computes correctly |
| `lib/controllers/purchase_controller.dart` | No changes needed — delegates work already |
| `lib/models/inventory_item.dart` | No model changes |
| `lib/models/stock_batch.dart` | No model changes |
| `lib/data/inventory_db.dart` | No DB changes |

---

## Execution Order

1. Add `stockValueForItem()` to `InventoryController`
2. Create `InventoryItemDetailScreen`
3. Update `InventoryScreen` — add Value pill, replace dialog with navigation, remove `_showStockRotationDialog` and helper methods (`_formatDate`, `_expiryLabel`)
4. Run `flutter analyze` and verify no errors