Implemented per-item inventory thresholds.

Changed:

Added lowStockThreshold to InventoryItem and persisted it as low_stock_threshold.
Added DB migration to version 9.
Inventory add/edit dialog now lets the user set each item’s low-stock threshold.
Purchase “Create new item” flow also supports setting the threshold.
Low-stock warnings now use item.isLowStock, not just the global threshold.
CSV/JSON import-export now carries low_stock_threshold.