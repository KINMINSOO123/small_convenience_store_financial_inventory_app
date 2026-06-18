Daily Report Detail & Export Plan
==================================

Current State
-------------
- ReportingScreen has a Daily/Monthly toggle
- `_showDaily` renders `_buildDailyBody()` inline showing P&L Summary,
  Sales Breakdown, Top Selling, Expenses, and Inventory Alerts
- No way to drill into a daily report — all rendered inline with no
  navigation or export from the daily view
- `DailyReportScreen` exists (standalone, not wired anywhere) with a date
  picker and all sections BUT no CSV/PDF export
- Monthly report already has CSV export (`_exportCsv`), PDF export
  (`_exportPdf`), and WhatsApp share (`_shareWhatsapp`) using `csv`,
  `pdf`, `share_plus`, and `path_provider` packages
- Navigation uses `Navigator.of(context).push(MaterialPageRoute(...))`
- All detail screens follow the same pattern: create, pass controllers,
  push via MaterialPageRoute

Design Principles
-----------------
1. Clicking a section in the daily toggle view navigates to a dedicated
   detail screen with the full daily report
2. The detail screen supports date selection (pick any date)
3. CSV and PDF export cover ALL sections of the daily report, not just
   a summary
4. WhatsApp share sends both CSV + PDF files (same as monthly)
5. Reuse existing export patterns (csv → ListToCsvConverter, pdf →
   pw.Document, share → Share.shareXFiles)


Phase 1: DailyReportDetailScreen (new screen)
-----------------------------------------------

New file: lib/screens/daily_report_detail_screen.dart

Constructor params:
  - required InventoryController inventoryController
  - required PurchaseController purchaseController
  - required ExpensesController expensesController
  - required SalesController salesController
  - SupplierReturnController? supplierReturnController
  - DateTime initialDate (defaults to DateTime.now())

State:
  - DateTime _selectedDate (initialized from initialDate)
  - DailyReportData computed via ReportingService.buildDailyReportData()

Build method:
  - AppBar with title "Daily Report — {date}" and a date-picker icon button
  - Body: SingleChildScrollView with Column:
    1. P&L SUMMARY (same P&L rows as _buildDailyBody, in a card)
    2. SALES BREAKDOWN (per-item list with qty and total)
    3. TOP SELLING PRODUCTS (top 5 by qty)
    4. EXPENSE BREAKDOWN (per-category with total)
    5. INVENTORY ALERTS (low stock + near expiry)
    6. EXPORT BUTTONS ROW:
       - FilledButton.icon "Export CSV" → _exportCsv(data)
       - OutlinedButton.icon "Export PDF" → _exportPdf(data)
    7. SHARE BUTTON (full width):
       - FilledButton.icon "Share via WhatsApp" → _shareWhatsapp(data)

Date picker changes trigger setState → rebuild with new _selectedDate.

Files: lib/screens/daily_report_detail_screen.dart (NEW)


Phase 2: Daily CSV Export
---------------------------

Add to DailyReportDetailScreen a method:
  String _buildDailyCsvContent(DailyReportData data)

CSV structure:

  Daily Report,2026-06-18
  ,
  Profit & Loss Summary
  Metric,Value
  Sales Revenue,850.00
  Cost of Goods Sold,520.00
  Supplier Returns,0.00
  Gross Profit,330.00
  Expenses,50.00
  Net Profit,280.00
  ,
  Sales Breakdown
  Item,Quantity,Total
  Bread,10,200.00
  Milo,5,150.00
  ...
  ,
  Top Selling Products
  Item,Quantity
  Bread,10
  Milo,5
  ...
  ,
  Expense Breakdown
  Category,Entries,Total
  Utilities,1,30.00
  Rent,1,20.00
  ...
  ,
  Inventory Alerts
  Type,Item,Details
  Low Stock,Bread,2 left
  Low Stock,Milo,3 left
  Near Expiry,Milk,expires in 5 days

Uses: ListToCsvConverter from csv package.
Saves to: getApplicationDocumentsDirectory() via path_provider.

Files: lib/screens/daily_report_detail_screen.dart (modify)


Phase 3: Daily PDF Export
---------------------------

Add to DailyReportDetailScreen a method:
  Future<List<int>> _buildDailyPdfBytes(DailyReportData data)

PDF structure via pw.Document + pw.MultiPage:

  Page 1:
    Title: "Daily Report — 2026-06-18"
    Subtitle: "Profit & Loss Summary"
    Table (Metric, Value):
      Sales Revenue        850.00
      Cost of Goods Sold   520.00
      Supplier Returns     0.00
      Gross Profit         330.00
      Expenses             50.00
      Net Profit           280.00

    Subtitle: "Sales Breakdown"
    Table (Item, Qty, Total):
      Bread   10   200.00
      Milo    5    150.00
      ...

    Subtitle: "Top Selling Products"
    Table (Item, Qty):
      Bread   10
      Milo    5

  Page 2 (if needed):
    Subtitle: "Expense Breakdown"
    Table (Category, Entries, Total):
      Utilities  1  30.00
      Rent       1  20.00

    Subtitle: "Inventory Alerts"
    Bullet list:
      Low Stock: Bread (2 left)
      Low Stock: Milo (3 left)
      Near Expiry: Milk (expires in 5 days)

Uses: pdf package.
Saves to: getApplicationDocumentsDirectory() via path_provider.

Files: lib/screens/daily_report_detail_screen.dart (modify)


Phase 4: Share via WhatsApp
-----------------------------

Add to DailyReportDetailScreen a method:
  Future<void> _shareWhatsapp(DailyReportData data)

Flow:
  1. Generate CSV and PDF files temporarily
  2. Call Share.shareXFiles([csvXFile, pdfXFile], text: message)
  3. Where message = "Daily Report — 2026-06-18"

Same pattern as ReportingScreen._shareWhatsapp().

Files: lib/screens/daily_report_detail_screen.dart (modify)


Phase 5: Navigation from Daily View Sections
-----------------------------------------------

In ReportingScreen._buildDailyBody():

  Option A (recommended): Wrap the entire Column in a "tap to view"
    button at the top, OR wrap each _dailySection card with InkWell,
    all navigating to the same DailyReportDetailScreen.

  Approach:
    - Wrap the first section (P&L Summary) with an InkWell
    - Add a "View Full Report →" trailing widget to it
    - onTap: Navigator.of(context).push(MaterialPageRoute(...))
    - Pass all controllers and DateTime.now() as initialDate

  Navigation call:
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyReportDetailScreen(
          inventoryController: _inventoryController,
          purchaseController: _purchaseController,
          expensesController: _expensesController,
          salesController: _salesController,
          supplierReturnController: _supplierReturnController,
          initialDate: DateTime.now(),
        ),
      ),
    );

Files: lib/screens/reporting_screen.dart (modify)


Implementation Order
---------------------
1. Phase 1: Create DailyReportDetailScreen with date picker and all
   sections (no export yet)
2. Phase 2: Add _buildDailyCsvContent and _exportCsv
3. Phase 3: Add _buildDailyPdfBytes and _exportPdf
4. Phase 4: Add _shareWhatsapp
5. Phase 5: Wire navigation from ReportingScreen sections


Summary of Files to Create
---------------------------
| File | Purpose |
|------|---------|
| lib/screens/daily_report_detail_screen.dart | Full daily report detail with P&L, sections, date picker, export buttons |


Summary of Files to Modify
---------------------------
| File | Change |
|------|--------|
| lib/screens/reporting_screen.dart | Wrap daily sections with InkWell, navigate to DailyReportDetailScreen |

No changes needed to home_shell.dart, reporting_service.dart, or any other files.
