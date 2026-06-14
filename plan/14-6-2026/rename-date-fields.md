# Rename Date Fields: purchased_at → purchase_date, entry_date → sales_date

## Goal

Rename DB columns and Dart model fields for clarity:

- `purchase_entries.purchased_at` → `purchase_entries.purchase_date`
- `sales_entries.entry_date` → `sales_entries.sales_date`
- `PurchaseEntry.purchasedAt` → `PurchaseEntry.purchaseDate`
- `SalesEntry.entryDate` → `SalesEntry.salesDate`

No schema additions. No new tables. Pure rename.

## Step 1 — DB Migration v16 (`lib/data/inventory_db.dart`)

Bump `_dbVersion` from 15 to 16.

Migration v16 for `purchase_entries` (table recreation):

```sql
CREATE TABLE purchase_entries_new(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_date TEXT NOT NULL,
  memo TEXT,
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  cancel_reason TEXT
);
INSERT INTO purchase_entries_new (id, purchase_date, memo, status, cancel_reason)
  SELECT id, purchased_at, memo, status, cancel_reason FROM purchase_entries;
DROP TABLE purchase_entries;
ALTER TABLE purchase_entries_new RENAME TO purchase_entries;
```

Migration v16 for `sales_entries` (same approach):

```sql
CREATE TABLE sales_entries_new(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sales_date TEXT NOT NULL,
  memo TEXT,
  amount REAL NOT NULL DEFAULT 0
);
INSERT INTO sales_entries_new (id, sales_date, memo, amount)
  SELECT id, entry_date, memo, amount FROM sales_entries;
DROP TABLE sales_entries;
ALTER TABLE sales_entries_new RENAME TO sales_entries;
```

Update `onCreate` to use new column names for both tables.

## Step 2 — Model: `PurchaseEntry` (`lib/models/purchase_entry.dart`)

- Rename field: `purchasedAt` → `purchaseDate`
- Update constructor parameter name
- Update `toMap()`: key `'purchased_at'` → `'purchase_date'`
- Update `fromMap()`: key `'purchased_at'` → `'purchase_date'`

## Step 3 — Model: `SalesEntry` (`lib/models/sales_entry.dart`)

- Rename field: `entryDate` → `salesDate`
- Update constructor parameter name
- Update `toMap()`: key `'entry_date'` → `'sales_date'`
- Update `fromMap()`: key `'entry_date'` → `'sales_date'`

## Step 4 — Service: `PurchaseService` (`lib/services/purchase_service.dart`)

- Rename all references: `purchasedAt` → `purchaseDate`
- Update method `addPurchase()` param: `purchasedAt` → `purchaseDate`
- Update method `addPurchaseWithLineItem()` param: `purchasedAt` → `purchaseDate`
- Update method `updatePurchase()` param: `purchasedAt` → `purchaseDate`
- Update inline usages in `cancelPurchase()`, `deletePurchaseHard()`, etc.

## Step 5 — Service: `SalesService` (`lib/services/sales_service.dart`)

- Rename all references: `entryDate` → `salesDate`
- Update method `addSale()` param: `entryDate` → `salesDate`
- Update method `updateSale()` param: `entryDate` → `salesDate`
- Update `_sortEntries()`: `entryDate` → `salesDate`

## Step 6 — Controllers

**`lib/controllers/purchase_controller.dart`:**
- Rename param `purchasedAt` → `purchaseDate` in `addPurchase()` and `updatePurchase()`

**`lib/controllers/sales_controller.dart`:**
- Rename param `entryDate` → `salesDate` in `addSale()` and `updateSale()`

## Step 7 — Screens (all call sites)

**`lib/screens/purchases_screen.dart`:**
- Update named arg `purchasedAt:` → `purchaseDate:` in controller calls
- Update `entry.purchasedAt` → `entry.purchaseDate` references (list display, date filter `_isWithinRange`, detail navigation)

**`lib/screens/purchase_entry_detail_screen.dart`:**
- `purchase.purchasedAt` → `purchase.purchaseDate`

**`lib/screens/sales_screen.dart`:**
- `sale.entryDate` → `sale.salesDate` (list display, date filter, navigation)
- Update named arg `entryDate:` → `salesDate:` in controller calls

**`lib/screens/sales_entry_detail_screen.dart`:**
- `sale.entryDate` → `sale.salesDate`

**`lib/screens/reporting_screen.dart`:**
- Update any `entryDate` → `salesDate` references

## Step 8 — Search for remaining references

- Grep for `purchasedAt`, `purchased_at`, `entryDate`, `entry_date` across `lib/`
- Fix all remaining references

## Files Summary

| File | Change |
|------|--------|
| `lib/data/inventory_db.dart` | Bump to v16; add migration; update `onCreate` |
| `lib/models/purchase_entry.dart` | `purchasedAt` → `purchaseDate`; map key `purchase_date` |
| `lib/models/sales_entry.dart` | `entryDate` → `salesDate`; map key `sales_date` |
| `lib/services/purchase_service.dart` | Rename `purchasedAt` → `purchaseDate` |
| `lib/services/sales_service.dart` | Rename `entryDate` → `salesDate` |
| `lib/controllers/purchase_controller.dart` | Rename param `purchasedAt` → `purchaseDate` |
| `lib/controllers/sales_controller.dart` | Rename param `entryDate` → `salesDate` |
| `lib/screens/purchases_screen.dart` | Update all `purchasedAt`/`.purchaseDate` references |
| `lib/screens/purchase_entry_detail_screen.dart` | `purchasedAt` → `purchaseDate` |
| `lib/screens/sales_screen.dart` | Update all `entryDate`/`.salesDate` references |
| `lib/screens/sales_entry_detail_screen.dart` | `entryDate` → `salesDate` |
| `lib/screens/reporting_screen.dart` | Update `entryDate` references if any |

## Verification

1. `flutter analyze` — no new warnings
2. Existing DB (v15) → v16 migration runs without errors
3. Purchase entries list shows dates correctly
4. Sales entries list shows dates correctly
5. Add/Edit purchase and sale flows still work
6. Reporting still computes totals correctly