# Update 2026-05-28 00:10

## Scope
- Allow hard delete of purchase records for manual data correction.

## What is included
- Controller method to delete purchases permanently and reverse stock if active.
- Purchases dialog now includes a "Delete permanently" action with confirmation.

## Notes
- Hard delete removes the purchase record and its FIFO batch.
- Cancel still preserves audit history when needed.

## Next upgrade ideas
- Add role-based controls (admin-only delete).
- Add activity log for deletions.
