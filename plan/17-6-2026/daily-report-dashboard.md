Daily Report & Dashboard Improvement Plan
==========================================

Current State
-------------
- ReportingScreen exists with month-to-date / year-to-date range reports
- ReportingService calculates profit as cash-flow (sales - purchases - expenses),
  NOT true COGS-based profit
- SalesEntryItem.costOfGoodsSold is computed on sale completion but UNUSED in
  reporting
- No daily report screen - current reporting is range-based, monthly focus
- No dashboard summary on home screen
- No top-selling products feature
- InventoryController already exposes lowStockItems and expiringSoonItems
- 5 tabs: Inventory, Purchases, Sales, Expenses, Reports

Design Principles
-----------------
1. Shopkeeper-focused: daily closing report is the primary view
2. COGS-based profit: use costOfGoodsSold from SalesEntryItem for true
   gross profit, not the misleading (sales - purchases) formula
3. Only ACTIVE sales count (DRAFT and VOID excluded)
4. Only ACTIVE purchases count (DRAFT and CANCELLED excluded)
5. Expenses always count (no status system on expenses)
6. Supplier returns reduce purchase totals
7. Top-selling by quantity, not revenue (shopkeeper intuition)


Phase 1: Fix Status Filtering in ReportingService
---------------------------------------------------

The current ReportingService.buildReport does NOT filter sales or
purchases by status. Fix this:

- Only ACTIVE sales contribute to revenue and COGS (DRAFT/VOID excluded)
- Only ACTIVE purchases contribute (DRAFT/CANCELLED excluded)

This is a prerequisite for accurate profit reporting.

Files: lib/services/reporting_service.dart


Phase 2: DailyReportData Model + ReportingService.buildDailyReport
-------------------------------------------------------------------

Add a DailyReportData model and a buildDailyReport method to
ReportingService that computes true gross profit using COGS.

DailyReportData model:
  - date: DateTime
  - salesRevenue: double        (sum of ACTIVE sale amounts for the date)
  - costOfGoodsSold: double      (sum of ACTIVE sale item COGS for the date)
  - grossProfit: double          (salesRevenue - costOfGoodsSold)
  - expensesTotal: double        (sum of expenses for the date)
  - netProfit: double            (grossProfit - expensesTotal)
  - transactionCount: int         (number of ACTIVE sales for the date)
  - salesLines: List<ReportLine>     (per-item: name, qty, revenue)
  - expenseLines: List<ReportLine>   (per-category: name, amount)
  - topSellingItems: List<ReportLine>(top 5 by quantity sold)
  - lowStockItems: List<InventoryItem>(items below threshold)
  - expiringSoonItems: List<InventoryItem>(items expiring within 30 days)

ReportingService.buildDailyReport(DateTime date):
  - Sum sales: filter salesEntries where isActive, salesDate == date
  - Sum COGS: for each ACTIVE sale's line items, sum costOfGoodsSold
  - Sum expenses: filter expense entries where date == date
  - Supplier returns: sum return items on this date (reduce gross profit)
  - Top selling: aggregate ACTIVE sale items by itemId, group by name,
    sort by quantity descending, take top 5
  - Low stock / expiring: delegate to InventoryController

Files: lib/models/daily_report_data.dart (new),
       lib/services/reporting_service.dart (modify)


Phase 3: Daily Report Screen
------------------------------

New screen: lib/screens/daily_report_screen.dart

AppBar title: "Daily Report"
Date selector (defaults to today, can pick other dates)

Sections:

1. PROFIT & LOSS SUMMARY (card)
   Sales Revenue          RM 850.00
   Cost of Goods Sold    -RM 520.00
   ─────────────────────────────────
   Gross Profit           RM 330.00
   Expenses             -RM  50.00
   ─────────────────────────────────
   Net Profit             RM 280.00

2. SALES BREAKDOWN (card)
   Transactions: 35
   [per-item list: name, qty, amount]

3. TOP SELLING PRODUCTS (card)
   [top 5 items by quantity sold]

4. EXPENSE BREAKDOWN (card)
   [per-category: name, amount]

5. INVENTORY ALERTS (card)
   Low Stock Items:
     Bread     2 left
     Milo      3 left
   Near Expiry:
     Milk      3 days
     Yogurt    5 days

Files: lib/screens/daily_report_screen.dart (new)


Phase 4: Dashboard on Home Screen
-----------------------------------

Replace the Reports tab with a combined view:
- Top section: Today's summary cards (Revenue, Profit, Low Stock, Expiring)
- Below: [View Full Report] button opens DailyReportScreen with today
- Existing monthly/analytics reports accessible via a tab or button

Files: lib/screens/home_shell.dart (modify),
       lib/screens/reporting_screen.dart (minor modify)


Phase 5: Supplier Returns in Gross Profit
------------------------------------------

When computing gross profit, supplier returns reduce it:
  grossProfit = salesRevenue - costOfGoodsSold - supplierReturnTotal

Where supplierReturnTotal = sum of (quantity * unitCost) for all
SupplierReturnItem entries on the report date.

Files: lib/services/reporting_service.dart


Implementation Order
--------------------
1. Phase 1: Fix status filtering (small change, high impact)
2. Phase 2: DailyReportData + buildDailyReport
3. Phase 3: Daily Report screen
4. Phase 4: Dashboard on home screen
5. Phase 5: Supplier returns in gross profit


Summary of Files to Create
--------------------------
| File | Purpose |
|------|---------|
| lib/models/daily_report_data.dart | DailyReportData model |
| lib/screens/daily_report_screen.dart | Daily report UI |


Summary of Files to Modify
--------------------------
| File | Change |
|------|--------|
| lib/services/reporting_service.dart | Add buildDailyReport, fix status filtering, add supplier returns |
| lib/screens/home_shell.dart | Wire DailyReportScreen or summary cards |
| lib/screens/reporting_screen.dart | Minor adjustments for navigation |
