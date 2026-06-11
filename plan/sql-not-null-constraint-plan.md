# SQL NOT NULL Constraint Plan

## Goal
Investigate and fix the SQLite `NOT NULL` constraint error that still appears when adding an inventory item.

## Problem statement
The item save flow is still hitting a SQLite `NOT NULL` constraint error. The goal is to identify which field is missing or being written as `null`, then adjust the inventory add-item path so a valid item can be saved without the database rejecting it.

## Planned steps
1. Trace the item creation flow from `lib/screens/inventory_screen.dart` into `lib/controllers/inventory_controller.dart` and `lib/services/inventory_service.dart`.
2. Check the exact values passed into the repository and database insert calls.
3. Inspect the item and batch table schemas in `lib/data/inventory_db.dart` to find which column is marked `NOT NULL`.
4. Compare the form validation against the required database fields.
5. Confirm whether the error comes from the item row, the stock batch row, or a related insert that runs after the item save.
6. Apply the smallest fix that guarantees all required fields are populated before insert.
7. Verify the fix with analyzer checks and a focused UI test or manual run.

## Likely risk areas
- Empty or untrimmed category values
- Missing initial unit cost when opening stock quantity is greater than zero
- A batch insert that receives a null required field
- Validation that allows the form to submit before all required database fields are ready

## Success criteria
- Adding a new item no longer throws a SQLite `NOT NULL` constraint error.
- The item appears in the selected category after save.
- The inventory list updates immediately after the save completes.
- No false error snackbar appears for a successful save.

## Task list
- Trace the add-item path from the inventory screen into the controller and service.
- Identify which insert call is sending a null value to SQLite.
- Compare the form fields with the database schema to find the missing required value.
- Confirm whether the failure comes from the item row or the batch row.
- Add the smallest validation or save-path fix needed to satisfy the database constraints.
- Verify the fix with analyzer checks and a quick item-add test.
