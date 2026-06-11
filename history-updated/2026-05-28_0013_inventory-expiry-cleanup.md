# Update 2026-05-28 00:13

## Scope
- One-time cleanup to remove inventory expiry values.

## What is included
- Database helper to clear inventory expiry column.
- Controller runs cleanup once and records completion in settings.

## Notes
- This only affects inventory items; purchase/batch expiry remains unchanged.
