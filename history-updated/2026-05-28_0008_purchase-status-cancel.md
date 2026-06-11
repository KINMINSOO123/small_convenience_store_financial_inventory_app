# Update 2026-05-28 00:08

## Scope
- Add purchase status and cancellation flow to protect audit history.

## What is included
- Purchase records now store a status (ACTIVE/CANCELLED).
- Cancelling a purchase reverses stock and removes its FIFO batch, without deleting history.
- Purchases UI shows status and disables editing for cancelled entries.

## Notes
- CSV export/import now includes purchase status.
- Batches are linked to purchases by purchase ID.

## Next upgrade ideas
- Add a void reason or note field.
- Filter list by Active/Cancelled.
- Add a dedicated purchase detail view.
