# Update 2026-05-28 00:04

## Scope
- Add FIFO purchase tracking, a purchases screen, and manual JSON export/import.

## What is included
- New purchase and stock batch models.
- SQLite tables for purchases and FIFO stock batches.
- Shared controller now loads purchases/batches and exports/imports JSON.
- New Purchases screen and app shell with bottom navigation.

## Notes
- Inventory expiry warnings now use batch expiry dates.
- Import replaces all existing data.

## Next upgrade ideas
- Sales screen that consumes FIFO batches.
- Expense tracking screen.
- Report summaries for stock valuation and purchases.
