# Inventory UI: Scannable Values Redesign

## Problem

Important numbers (value, quantity, selling price) are buried inside pill chips in `ListTile.subtitle`. They all carry equal visual weight, making it hard to scan down a list and compare items or categories at a glance. The trailing row also crams the selling price alongside edit/delete icon buttons, adding clutter.

## Current Layouts

### Item list (inside a category)

```
[Avatar]  Item Name                    5.99 [Edit] [Delete]
           [Category] [12 units] [Value 59.88] [Low at 5]
```

Problems:
- Value, quantity, threshold are equal-weight pills — no visual hierarchy
- Selling price is tiny text crammed next to icon buttons
- Edit/delete buttons add clutter to every row
- Hard to compare values across items because they're buried in a Wrap

### Category list

```
[Avatar]  Category                     [Rename ⋮ Delete]
           [5 items] [12 units] [Value 59.88]
```

Problems:
- Same pill-density issue — "5 items", "12 units", "Value 59.88" all look the same
- Hard to quickly compare category values

### Item detail screen

```
┌────────────────────────────────────┐
│  Item Name            Stock Value   │
│  Category                   59.88  │
│  Quantity: 12                      │
└────────────────────────────────────┘
```

Problems:
- Selling price per unit not shown on this screen
- "Quantity: 12" is body text — easy to miss
- No visual distinction between info fields

---

## Proposed Layouts

### 1. Item list — right-aligned value column

```
[Avatar]  Item Name                   59.88
           12 units · Low at 5     5.99/unit
```

- **Title line**: Item name on the left, total stock **value** bold and right-aligned
- **Subtitle line**: Quantity + low-stock threshold on the left, selling price per unit right-aligned in secondary style
- **Remove** edit/delete `IconButton`s from the row — move edit into the detail screen's AppBar and delete into a popup menu on the detail screen
- This creates a clean right-aligned column for monetary values that can be scanned vertically

### 2. Category list — right-aligned total value

```
[Avatar]  Category                     59.88
           5 items · 12 units              ⋮
```

- **Title line**: Category name on the left, total stock value bold and right-aligned
- **Subtitle line**: item count + total units on the left
- Keep `PopupMenuButton` (⋮) for rename/delete as `trailing`

### 3. Item detail screen — two-column info card with selling price

```
┌──────────────────────────────────────┐
│  Item Name                           │
│  Category                            │
│                                      │
│  Quantity          Selling price     │
│  12 units           5.99/unit         │
│                                      │
│                     Stock Value       │
│                       59.88           │
└──────────────────────────────────────┘
```

Add selling price to the info card, shown alongside quantity in a two-column row.
Stock value remains right-aligned and prominent at the bottom of the card.

---

## Changes by File

### `lib/screens/inventory_screen.dart`

**Item list tile** — Restructure from pills to two-line layout:
- Remove `Wrap` of `_Pill` widgets from subtitle
- Set `title` to item name
- Set `subtitle` to: left side = `"${item.quantity} units · Low at ${item.lowStockThreshold}"`, right-aligned secondary text = `"${item.sellingPrice.toStringAsFixed(2)}/unit"`
- Set `trailing` to total stock value text (bold, `titleMedium`) stacked above the per-unit price
- Remove `IconButton` edit/delete from trailing row; these move to the detail screen

**Category list tile** — Restructure from pills to two-line layout:
- Remove `Wrap` of `_Pill` widgets from subtitle
- Set `title` to category name
- Set `subtitle` to: `"${itemCount} items · ${quantity} units"`
- Set `trailing` to stock value (bold, `titleMedium`) with `PopupMenuButton` below it
- Keep `PopupMenuButton` (⋮) for rename/delete actions

**Remove `_Pill` widget** — No longer used in this file after both lists switch to text layout.

### `lib/screens/inventory_item_detail_screen.dart`

**Info card** — Add selling price row:
- Add a two-column `Row` below the category pill:
  - Left: `"${item.quantity} units"`
  - Right: `"${item.sellingPrice.toStringAsFixed(2)}/unit"`
- Keep "Stock Value" right-aligned at the bottom of the card

**Add edit action** — Add an `IconButton` with `Icons.edit_outlined` in the AppBar `actions` for editing the item. Tapping it opens the `_showItemDialog` with the current item. Since this screen is a `StatelessWidget`, it needs to either:
  - Call `_showItemDialog` via a callback passed from `InventoryScreen`, OR
  - Be converted to `StatefulWidget`, OR
  - Use a separate route/callback pattern

Best approach: convert `InventoryItemDetailScreen` to a `StatefulWidget` and move the `_showItemDialog` and `_confirmDeleteItem` logic here (or pass callbacks). The simplest is to pass an `onEdit` and `onDelete` callback from the parent.

**Add delete action** — Add a `PopupMenuButton` in the AppBar with a "Delete" option. This requires the same callback pattern as edit.

### `lib/models/inventory_item.dart`

No changes needed — `sellingPrice` and `quantity` are already on the model.

---

## What Stays the Same

- Category → items drill-down navigation
- Warning banner for low stock / expiring soon
- Top info cards (Total Units / Stock Value)
- Batch list on item detail screen (pills work well for batch-level metadata)
- FAB behavior
- `_Pill` widget in `inventory_item_detail_screen.dart` (still used for batch info)

## What Gets Removed

- `_Pill` widget from `inventory_screen.dart` (no longer used)
- Edit/delete `IconButton` row from item `ListTile.trailing`
- Pill `Wrap` from both item and category `ListTile.subtitle`

## What Gets Added

- Selling price display in item list subtitle
- Selling price display in item detail info card
- Edit action in detail screen AppBar
- Delete action in detail screen AppBar popup menu
- `onEdit` and `onDelete` callbacks passed to `InventoryItemDetailScreen`

---

## Execution Order

1. Restructure category list tile in `inventory_screen.dart` (remove pills, add right-aligned value)
2. Restructure item list tile in `inventory_screen.dart` (remove pills + edit/delete buttons, add right-aligned value and /unit price)
3. Remove `_Pill` class from `inventory_screen.dart`
4. Add edit/delete callbacks to `InventoryItemDetailScreen` constructor
5. Add selling price and structured info card in `inventory_item_detail_screen.dart`
6. Add AppBar actions (edit + delete) in `inventory_item_detail_screen.dart`
7. Update the `onTap` in `inventory_screen.dart` to pass callbacks for edit/delete
8. Run `flutter analyze` and verify no errors