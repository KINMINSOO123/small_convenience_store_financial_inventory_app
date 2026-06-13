# Fix: NOT NULL constraint failed on inventory_items.unit_cost

## Root cause

The `ALTER TABLE inventory_items DROP COLUMN unit_cost` in **migration v11** (line 262 of `inventory_db.dart`) **silently fails** on most Android devices because SQLite versions prior to 3.35.0 do not support `DROP COLUMN`. The error is caught by the `try/catch` and swallowed, so the column remains in the table with its original `NOT NULL` constraint.

When a new inventory item is inserted, `InventoryItem.toMap()` does not include `unit_cost` (the field was removed from the model). SQLite's `INSERT INTO` only specifies the columns present in the map, so `unit_cost` receives no value. Since the column is `NOT NULL` with no `DEFAULT`, the insert fails:

```
DatabaseException(NOT NULL constraint failed: inventory_items.unit_cost)
INSERT INTO inventory_items (id, name, category, quantity, selling_price, low_stock_threshold)
VALUES (NULL, ?, ?, ?, ?, ?)
```

The user confirmed this with the breakpoint at line 266 of `inventory_screen.dart`.

## Fix strategy

Bump the DB version to **12** and add a v12 migration that properly removes the `unit_cost` column using the **table-recreation technique** (the standard way to drop a column in SQLite < 3.35.0):

1. Create a new `inventory_items` table with the correct schema (no `unit_cost`).
2. Copy all rows from the old table into the new one.
3. Drop the old table.
4. Rename the new table back to `inventory_items`.

The v11 migration's `DROP COLUMN` line should also be removed since v12 will handle it properly. The v11 migration should still add `selling_price` and copy data from `unit_cost`, but it should no longer try to drop the column.

## Implementation steps

### 1. `lib/data/inventory_db.dart`

#### 1a. Bump `_dbVersion` from 11 to 12

```dart
static const _dbVersion = 12;
```

#### 1b. Update the v11 migration — remove the DROP COLUMN attempt

Change the `try/catch` block so it only copies `unit_cost` -> `selling_price` and does NOT attempt `DROP COLUMN`:

```dart
if (oldVersion < 11) {
  await db.execute(
    'ALTER TABLE $_tableItems '
    'ADD COLUMN selling_price REAL NOT NULL DEFAULT 0',
  );
  try {
    await db.execute(
      'UPDATE $_tableItems '
      'SET selling_price = unit_cost '
      'WHERE selling_price = 0',
    );
  } catch (e) {
    // Ignore if unit_cost column does not exist (fresh installs)
  }
}
```

#### 1c. Add a v12 migration — recreate the table without `unit_cost`

```dart
if (oldVersion < 12) {
  await db.execute(
    'CREATE TABLE ${_tableItems}_temp('
    'id INTEGER PRIMARY KEY AUTOINCREMENT,'
    'name TEXT NOT NULL,'
    'category TEXT NOT NULL,'
    'quantity INTEGER NOT NULL,'
    'selling_price REAL NOT NULL DEFAULT 0,'
    'low_stock_threshold INTEGER NOT NULL DEFAULT 5,'
    'expiry_date TEXT'
    ')',
  );
  await db.execute(
    'INSERT INTO ${_tableItems}_temp '
    '(id, name, category, quantity, selling_price, low_stock_threshold, expiry_date) '
    'SELECT id, name, category, quantity, selling_price, low_stock_threshold, expiry_date '
    'FROM $_tableItems',
  );
  await db.execute('DROP TABLE $_tableItems');
  await db.execute(
    'ALTER TABLE ${_tableItems}_temp RENAME TO $_tableItems',
  );
}
```

The `onCreate` method already creates the table without `unit_cost`, so fresh installs are fine.

### 2. Verify `InventoryItem.toMap()` / `fromMap()` — no changes needed

- `toMap()` already excludes `unit_cost` — correct.
- `fromMap()` already uses `selling_price` with a `unit_cost` fallback — correct for reading old rows.

### 3. No changes needed in service, controller, or screen layers

The NOT NULL error is purely a schema problem. The service and controller already pass all required fields. The fix is entirely in the DB migration.

## Verification

1. Run `flutter analyze` — no new warnings.
2. On a device/emulator with an existing DB (v11), launch the app — the v12 migration should run.
3. After migration, add a new inventory item inside a category:
   - Enter name, quantity > 0, selling price, initial unit cost, low stock threshold.
   - Tap "Add" — the item should save without a NOT NULL error.
4. Confirm the item appears in the category list immediately.
5. On a fresh install (no existing DB), add an item — should also work.
6. Existing items should retain their `selling_price` values (migrated from `unit_cost`).

## Risk notes

- The v12 migration uses a transactional table-rename, which is atomic. If the migration fails halfway, the database version is not incremented and it will be retried on next launch.
- Foreign keys referencing `inventory_items(id)` are not affected by the rename because `sqflite` on Android does not enforce foreign keys by default (`PRAGMA foreign_keys` is OFF unless explicitly enabled).
- The `inventory_items_temp` table name must not collide with any existing table — it is only used during the migration.