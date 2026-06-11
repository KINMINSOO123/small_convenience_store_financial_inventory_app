Implemented inventory pricing rules with batch costs and product selling prices.

Changed:

Added selling_price to InventoryItem and stored unit_cost only on stock batches.
Added DB migration (v11) to backfill selling_price from unit_cost.
CSV export/import now uses selling_price with fallback to unit_cost for legacy files.
Stock consumption uses FEFO when expiry dates are present, FIFO otherwise.
UI updates for selling price fields and FEFO/FIFO messaging.
