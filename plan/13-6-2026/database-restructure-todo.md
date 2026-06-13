# Database Restructure Plan

This plan converts the database from flat per-item purchase/sales entries to a header+line-item model, removes `quantity` and `expiry_date` from `inventory_items`, and replaces `purchase_id` with `purchase_item_id` on `stock_batches`. The `inventory_movements` audit table is deferred to a later phase.

---

## Final Schema After All Steps

### `inventory_items`
- id INTEGER PRIMARY KEY AUTOINCREMENT
- name TEXT NOT NULL
- category TEXT NOT NULL
- selling_price REAL NOT NULL DEFAULT 0
- low_stock_threshold INTEGER NOT NULL DEFAULT 5

### `inventory_categories`
- name TEXT PRIMARY KEY

### `purchase_entries` (header)
- id INTEGER PRIMARY KEY AUTOINCREMENT
- purchase_date TEXT NOT NULL
- memo TEXT
- total_cost REAL NOT NULL DEFAULT 0
- status TEXT NOT NULL DEFAULT 'ACTIVE'
- cancel_reason TEXT

### `purchase_entry_items` (line items)
- id INTEGER PRIMARY KEY AUTOINCREMENT
- purchase_id INTEGER NOT NULL
- item_id INTEGER NOT NULL
- quantity INTEGER NOT NULL
- unit_cost REAL NOT NULL
- expiry_date TEXT
- FOREIGN KEY(purchase_id) REFERENCES purchase_entries(id)
- FOREIGN KEY(item_id) REFERENCES inventory_items(id)

### `stock_batches`
- id INTEGER PRIMARY KEY AUTOINCREMENT
- item_id INTEGER NOT NULL
- purchase_item_id INTEGER
- quantity INTEGER NOT NULL
- remaining_qty INTEGER NOT NULL
- unit_cost REAL NOT NULL
- expiry_date TEXT
- received_at TEXT NOT NULL
- FOREIGN KEY(item_id) REFERENCES inventory_items(id)

### `sales_entries` (header)
- id INTEGER PRIMARY KEY AUTOINCREMENT
- entry_date TEXT NOT NULL
- memo TEXT
- amount REAL NOT NULL DEFAULT 0

### `sales_entry_items` (line items)
- id INTEGER PRIMARY KEY AUTOINCREMENT
- sales_id INTEGER NOT NULL
- item_id INTEGER NOT NULL
- quantity INTEGER NOT NULL
- unit_price REAL NOT NULL
- cost_of_goods_sold REAL NOT NULL DEFAULT 0
- subtotal REAL NOT NULL DEFAULT 0
- FOREIGN KEY(sales_id) REFERENCES sales_entries(id)
- FOREIGN KEY(item_id) REFERENCES inventory_items(id)

### `app_settings` (unchanged)

### `accounts` (unchanged)

### `journal_entries` (unchanged)

### `journal_lines` (unchanged)

---

## Step 1 — Fix the NOT NULL bug (unit_cost)

**Why first**: The app is currently broken — any add-item attempt crashes with `NOT NULL constraint failed: inventory_items.unit_cost`. Fix this before making further structural changes.

**Changes**:
1. **`lib/data/inventory_db.dart`**
   - Bump `_dbVersion` from 11 to 12.
   - Update v11 migration: remove the `DROP COLUMN unit_cost` line (it silently fails on SQLite < 3.35.0). Keep the `ADD COLUMN selling_price` and `UPDATE selling_price = unit_cost` steps.
   - Add v12 migration: recreate the `inventory_items` table without `unit_cost` using the table-recreation technique (create temp, copy data, drop old, rename).

2. **No model/service/controller changes** needed — `InventoryItem.toMap()` already omits `unit_cost`.

**Verification**: Add a new inventory item with initial unit cost and quantity > 0. It should save without a NOT NULL error.

---

## Step 2 — New models: `PurchaseEntryItem` and `SalesEntryItem`

**Why**: These new models are needed before the DB and service layers change. They have zero runtime impact — just new immutable Dart classes.

**Changes**:
1. **Create `lib/models/purchase_entry_item.dart`**
   ```dart
   class PurchaseEntryItem {
     final int id;
     final int purchaseId;
     final int itemId;
     final int quantity;
     final double unitCost;
     final DateTime? expiryDate;
     // toMap(), fromMap()
   }
   ```

2. **Create `lib/models/sales_entry_item.dart`**
   ```dart
   class SalesEntryItem {
     final int id;
     final int salesId;
     final int itemId;
     final int quantity;
     final double unitPrice;
     final double costOfGoodsSold;
     final double subtotal;
     // toMap(), fromMap()
   }
   ```

---

## Step 3 — DB schema: add new tables + rename `purchase_entries` columns

**Why**: Add the new tables while the old columns still exist. This is a non-destructive migration — existing data is preserved.

**Changes in `lib/data/inventory_db.dart`**:

1. Bump `_dbVersion` from 12 to 13.
2. In `onCreate`, create all tables in their final form (including `purchase_entry_items`, `sales_entry_items`, and `stock_batches` with `purchase_item_id` instead of `purchase_id`).
3. In `onUpgrade` for v13:
   - Create `purchase_entry_items` table.
   - Migrate data from old `purchase_entries` (per-item rows) into the new header+line-item structure:
     - For each distinct `(item_id, purchased_at)` group in the old `purchase_entries`, create one `purchase_entries` header row.
     - Each old row becomes one `purchase_entry_items` line item.
   - Create `sales_entry_items` table.
   - Migrate data from old `sales_entries` (per-item rows) into the new header+line-item structure.
   - Create new `stock_batches` table with `purchase_item_id` column.
   - Migrate data from old `stock_batches` to new, mapping `purchase_id` → `purchase_item_id`.
   - Drop old `stock_batches` (rename temp approach).
   - Drop columns `item_id, quantity, unit_cost, purchased_at, status, cancel_reason, expiry_date` from `purchase_entries` (table recreation).
   - Drop columns `item_id, quantity, unit_price, amount, memo` from `sales_entries` (table recreation).
   - Drop `quantity` and `expiry_date` from `inventory_items` (table recreation, building on v12).

**Important**: The v13 migration must handle the `inventory_items` table recreation carefully since v12 already recreated it without `unit_cost`. It now needs to also remove `quantity` and `expiry_date`.

**Also**: Update `clearAll()` to delete from `purchase_entry_items` and `sales_entry_items` too.

**Update `InventoryItem` model**:
- Remove `quantity` field.
- Remove `expiry_date` considerations (already not in model, but confirms removal from table).
- `quantity` becomes a computed getter or an externally-set field.

**Update `PurchaseEntry` model**:
- Replace `itemId`, `quantity`, `unitCost`, `purchasedAt`, `status`, `expiryDate`, `cancelReason` with `purchaseDate`, `memo`, `totalCost`, `status`, `cancelReason`.

**Update `SalesEntry` model**:
- Replace `itemId`, `quantity`, `unitPrice`, `date`, `memo` with `entryDate`, `memo`, `amount`.

**Update `StockBatch` model**:
- Replace `purchaseId` with `purchaseItemId`.

---

## Step 4 — DB methods: query and insert for new tables

**Changes in `lib/data/inventory_db.dart`**:

1. Add fetch/insert/update/delete methods for `purchase_entry_items`.
2. Add fetch/insert/delete methods for `sales_entry_items`.
3. Update `fetchPurchases` to return the new `purchase_entries` schema.
4. Update `insertPurchase` to accept the new header schema.
5. Update `fetchSalesEntries` to return the new schema.
6. Update `insertSalesEntry` to accept the new schema.
7. Update stock batch methods to use `purchase_item_id` instead of `purchase_id`.

**Changes in repositories**:
- `InventoryRepository`: add methods for `purchase_entry_items`.
- `SalesRepository`: add methods for `sales_entry_items`.

---

## Step 5 — Service layer: restructure purchase logic

**Changes in `lib/services/inventory_service.dart`**:

1. `addItem()`: Remove the `quantity` and `initialUnitCost` parameters from `InventoryItem` creation. Quantity is no longer stored on the item. The `addPurchase` call still creates batches that track quantity.
2. `addPurchase()`: Change from creating a single `PurchaseEntry` to creating a `PurchaseEntry` header + one or more `PurchaseEntryItem` line items. Update batch creation to reference `purchaseItemId` instead of `purchaseId`.
3. `updatePurchase()`: Work with header + line items instead of a flat entry.
4. `cancelPurchase()`: Update the header status and restore stock from related batches (same logic, different structure).
5. `deletePurchaseHard()`: Delete header, line items, and batches.
6. `_updateItemQuantity()`: Remove this method since `quantity` is no longer on `inventory_items`. Instead, recompute quantity from batches.
7. `load()`: After loading items and batches, compute each item's quantity from its batches' `remainingQuantity`.
8. `exportJson()` / `importJson()`: Update to include `purchase_entry_items` and handle the new structure.
9. `exportCsvFiles()` / `importCsvFiles()`: Update CSV format for the new structure.

**Change `InventoryItem` usage across all files**:
- `item.quantity` references must be replaced with computed values.
- The `Inventory` class and `InventoryController` need to compute `quantity` from batches.
- Low stock check: `item.isLowStock` must now use the computed quantity.

---

## Step 6 — Service layer: restructure sales logic

**Changes in `lib/services/sales_service.dart`**:

1. `addSale()`: Create a `SalesEntry` header + `SalesEntryItem` line items instead of a flat entry. Compute `costOfGoodsSold` from batches (FIFO).
2. `updateSale()`: Update header + line items. Restore stock from old sale, then consume for new sale.
3. `deleteSale()`: Restore stock from the sale's line items, then delete header + line items.
4. `load()`: Load both headers and line items from DB.

**Changes in `lib/controllers/sales_controller.dart`**:
- Update method signatures if parameters change.
- The controller still delegates to the service, but may need to pass multiple line items.

---

## Step 7 — Controller and UI layer: purchase screen

**Changes in `lib/controllers/inventory_controller.dart`**:
- Update `addPurchase`, `updatePurchase`, `cancelPurchase`, `deletePurchaseHard` to work with header + line items.
- Expose `purchaseEntryItems` for the UI.
- Compute item quantities from batches instead of `item.quantity`.

**Changes in `lib/screens/purchases_screen.dart`**:
- Update the purchase dialog to support adding multiple line items to a single purchase.
- Display purchase header info (date, memo, total) and line items beneath it.
- Cancel/delete actions work on the whole purchase header.

---

## Step 8 — Controller and UI layer: sales screen

**Changes in `lib/screens/sales_screen.dart`**:
- Update the sale dialog to support multiple line items (sell different items in one sale).
- Show line item details with COGS.
- `SalesController` exposes `salesEntryItems`.

---

## Step 9 — Controller and UI layer: inventory screen

**Changes in `lib/screens/inventory_screen.dart`** and `lib/controllers/inventory_controller.dart`**:
- Remove `quantity` from the add-item dialog (it's now set via purchase line items).
- Remove `initialUnitCost` from the add-item dialog (handled in purchase creation).
- Add-item flow becomes: create the item with name, category, selling price, threshold → then optionally add a purchase right after.
- Display computed quantities (from batches) instead of stored values.
- Update category and item display to use computed quantities.
- Remove the `expiry_date` display from the item list (expiry is on batches now).

---

## Step 10 — Reporting and export

**Changes in `lib/screens/reporting_screen.dart`** and `lib/services/reporting_service.dart`**:
- Update reporting to use header+line-item structure for purchases.
- Update COGS calculation to use `cost_of_goods_sold` from sales line items.
- Update CSV export/import for the new table structure.

---

## Step 11 — Final cleanup

- Remove dead code (old flat-style queries, unused model fields).
- Remove `expiry_date` column from `inventory_items` if not already done in Step 3.
- Run full analyzer check.
- Manual end-to-end testing: add item, add purchase, sell item, cancel purchase, delete item.
- Test migration from v12 (or earlier) database to v13.

---

## Dependency order

```
Step 1  (NOT NULL fix)
  ↓
Step 2  (new models — no runtime effect)
  ↓
Step 3  (DB migration v13 — schema only, old code still works)
  ↓
Step 4  (DB methods for new tables)
  ↓
Step 5  (inventory service restructure)
  ↓
Step 6  (sales service restructure)
  ↓
Step 7  (purchase UI)
  ↓
Step 8  (sales UI)
  ↓
Step 9  (inventory UI)
  ↓
Step 10 (reporting)
  ↓
Step 11 (cleanup)
```

Each step should be committed and tested independently before moving to the next.