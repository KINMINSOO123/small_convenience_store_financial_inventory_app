Remove Date-Based Purchase/Sales Deduplication
==================================================

Problem
-------
`findPurchaseByDate` in `PurchaseService` matches **ACTIVE (completed)**
purchases by date. When a user adds a new purchase item on a date that
already has a completed purchase, the item is silently merged into that
completed purchase — bypassing the DRAFT/ACTIVE workflow, creating stock
batches and movements immediately, and modifying a locked document.

Additionally, the one-entry-per-date design causes problems:
- Multiple suppliers on the same date can't be represented
- Returns and cancellations become confusing (which entry to cancel?)
- Audit trail is unclear
- Modifying completed entries accidentally

New Design
----------
Purchase entries and sales entries are **documents identified by ID**,
not by date. Date is just an attribute.

```
Purchase #P001   Date: 2026-06-10
Purchase #P002   Date: 2026-06-10
Purchase #P003   Date: 2026-06-11
```

Purchase Flow
-------------
When "Add purchase" is tapped from purchases_screen.dart:

1. Look for an existing **DRAFT** purchase with the same normalized date.
2. If a draft exists on that date → add the line item to that draft
   (no stock effects, no batches, no movements).
3. If no draft exists → create a **new DRAFT** purchase, then add
   the line item.
4. Completed (ACTIVE) purchases are never modified.

Sales Flow
----------
Same logic for sales (if sales also has date-based matching).


Changes Required
----------------

### PurchaseService

- `findPurchaseByDate()`: Change filter from `!entry.isDraft` to
  `entry.isDraft` — only match DRAFT purchases by date.

- `addPurchaseWithLineItem()`: Since matched purchases are now always
  DRAFT, remove the `if (!purchase.isDraft)` dead-code branch that
  creates batches, updates inventory, and records movements.

### SalesService

- If `findSaleByDate()` exists and is used by `addSale()`, apply the
  same change: only match DRAFT sales.

### Controller

- Remove `findPurchaseByDate()` / `findSaleByDate()` delegation
  methods if no UI code calls them.

### DB Schema

- No schema changes needed. UNIQUE constraints on date columns can be
  removed from `onCreate` at next version bump, but existing data
  migration is optional (dates are no longer unique identifiers).


Files to Modify
---------------
| File | Change |
|------|--------|
| `lib/services/purchase_service.dart` | Update `findPurchaseByDate()` to match drafts only; remove dead `!purchase.isDraft` branch in `addPurchaseWithLineItem()` |
| `lib/services/sales_service.dart` | Update `findSaleByDate()` to match drafts only (if used for dedup) |
| `lib/controllers/purchase_controller.dart` | Remove `findPurchaseByDate()` if unused by UI |
| `lib/controllers/sales_controller.dart` | Remove `findSaleByDate()` if unused by UI |


Verification
------------
1. `flutter analyze` — no errors or new warnings.
2. "Add purchase" with a new date → creates a new DRAFT purchase.
3. "Add purchase" with a date matching an existing DRAFT → adds item
   to that draft.
4. "Add purchase" with a date matching an existing ACTIVE purchase →
   creates a new DRAFT purchase (does not modify the active one).
5. Line items in draft purchases have no stock/batch/movement effects
   until "Complete Purchase" is tapped.
