# Update 2026-05-28 00:05

## Scope
- Add CSV export/import for inventory and purchases.

## What is included
- CSV export generates two files (inventory and purchases).
- CSV import reads two files and rebuilds inventory, purchases, and FIFO batches.
- App menu now uses CSV export/import.

## Notes
- CSV files are saved in the app documents directory.
- Import replaces all existing data.

## Next upgrade ideas
- Add a file share action for exported CSVs.
- Validate CSV headers with user-friendly errors.
- Add sales CSV support.
