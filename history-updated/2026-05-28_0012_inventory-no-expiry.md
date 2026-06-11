# Update 2026-05-28 00:12

## Scope
- Remove expiry date from inventory items (expiry now lives only on purchases/batches).

## What is included
- Inventory model no longer stores expiry.
- Inventory add/edit UI removed expiry fields.
- Inventory CSV import/export no longer includes expiry column.

## Notes
- Expiry tracking remains on purchases and FIFO batches.

## Next upgrade ideas
- Add batch-level expiry editing tools.
- Add FEFO consumption rules when sales are implemented.
