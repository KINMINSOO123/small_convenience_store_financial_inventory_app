# Update 2026-05-28 00:09

## Scope
- Add cancel reason and Active/Cancelled filter for purchases.

## What is included
- Purchase records now store an optional cancel reason.
- Purchases list supports filter (All, Active, Cancelled).
- Cancel flow captures a reason and shows it in the list.
- CSV export/import includes cancel reason.

## Notes
- Cancelling a purchase still reverses stock and removes its FIFO batch.

## Next upgrade ideas
- Add notes for active purchases.
- Add purchase detail view with full audit trail.
- Add search for purchases.
