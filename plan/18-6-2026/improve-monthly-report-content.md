Improve Monthly Report Content (CSV & PDF)
============================================

Problem
-------
The current monthly report has several issues:

1. **"Purchases Total" is misleading** — shows purchase cost without
   explaining gross profit. A shopkeeper sees RM65 purchases and -RM907
   profit and can't trace why.
2. **"Profit (cash)" is confusing** — should be "Net Profit".
3. **No transaction counts** in exports — `salesCount`, `purchaseCount`,
   `expenseCount` exist in `ReportData` but aren't shown.
4. **No sales-by-item breakdown** — purchases and expenses have item
   breakdowns, but sales doesn't.
5. **No expiring item details** — only a count; no item names, expiry dates,
   or days left.
6. **No report generation timestamp**.
7. **No gross margin**.
8. **No cash flow summary** — shopkeepers need "money in vs money out".
9. **No P&L derivation** — numbers are shown flat with no explanation of
   how they relate.

Design Decisions
----------------

**Cash Flow vs Net Outflow:**
Remove `netOutflow` from UI and reports. Replace with:
- `totalCashIn` (sales revenue)
- `totalCashOut` (purchases + expenses)
- `netCashFlow` (cash in minus cash out)

Keep `netOutflow` in model temporarily, marked deprecated.

**Layout: Both Cards AND P&L List:**
- Cards for quick-glance overview (Sales, Gross Profit, Expenses, Net Profit)
- P&L-style detailed list below explaining how numbers are derived
- Cash Flow section after P&L
- Then inventory, top sellers, purchases, expenses, daily reports

**COGS Terminology:**
Use "Cost of Goods Sold (Purchase Cost)" as a label since the system
uses purchases-in-period as a COGS proxy, not true FIFO/FEFO COGS.

**Phase-based implementation:** Model first, then UI, then exports.


Phase 1: Extend ReportData Model
----------------------------------

File: lib/services/reporting_service.dart

### 1a. Add ExpiryAlert class

```dart
class ExpiryAlert {
  const ExpiryAlert({
    required this.itemName,
    required this.expiryDate,
    required this.daysLeft,
    required this.remainingQuantity,
  });

  final String itemName;
  final DateTime expiryDate;
  final int daysLeft;
  final int remainingQuantity;
}
```

### 1b. Extend ReportData

Add new fields:

```dart
// Sales breakdown by item (sorted by revenue desc)
final List<ReportLine> salesLines;

// Gross profit & margin
final double grossProfit;    // salesTotal - purchasesTotal
final double grossMargin;     // grossProfit / salesTotal * 100 (0 if no sales)

// Cash flow
final double totalCashIn;    // = salesTotal
final double totalCashOut;   // = purchasesTotal + expensesTotal
final double netCashFlow;    // = totalCashIn - totalCashOut

// Inventory details (replacing bare counts)
final List<InventoryItem> lowStockItems;
final List<ExpiryAlert> expiringAlerts;
```

Keep `netOutflow` temporarily but mark `@Deprecated('Use netCashFlow instead')`.
Keep `lowStockCount` and `expiringSoonCount` temporarily for `DailyReport`
compatibility but compute from the new lists:
- `lowStockCount = lowStockItems.length`
- `expiringSoonCount = expiringAlerts.map((e) => e.itemName).toSet().length`

### 1c. Update buildReport() signature

Add new required parameters:

```dart
ReportData buildReport({
  // ... existing params ...
  required List<StockBatch> batches,          // NEW: for expiry alerts
  required List<InventoryItem> lowStockItems,  // NEW: replaces int lowStockCount
})
```

Remove `lowStockCount` and `expiringSoonCount` from the signature — compute
from the new list params inside the method.

### 1d. Compute new fields inside buildReport()

**Sales lines:** Aggregate sales by item across the date range (reuse the
pattern from `_buildDailyReports`):

```dart
final salesLines = <String, ReportLine>{};
for (final sale in salesInRange) {
  final saleItems = salesEntryItems.where((i) => i.salesId == sale.id);
  for (final lineItem in saleItems) {
    final label = itemNames[lineItem.itemId] ?? 'Item #${lineItem.itemId}';
    salesLines.update(
      label,
      (line) => line.copyWith(
        quantity: line.quantity + lineItem.quantity,
        total: line.total + lineItem.subtotal,
      ),
      ifAbsent: () => ReportLine(
        label: label,
        quantity: lineItem.quantity,
        total: lineItem.subtotal,
      ),
    );
  }
}
final sortedSalesLines = salesLines.values.toList()
  ..sort((a, b) => b.total.compareTo(a.total));
```

**Gross profit & margin:**

```dart
final grossProfit = salesTotal - purchasesTotal;
final grossMargin = salesTotal > 0 ? (grossProfit / salesTotal * 100) : 0.0;
```

**Cash flow:**

```dart
final totalCashIn = salesTotal;
final totalCashOut = purchasesTotal + expensesTotal;
final netCashFlow = totalCashIn - totalCashOut;
```

**Expiring alerts:** For each batch expiring within 30 days with
remaining quantity > 0:

```dart
final now = DateTime.now();
final thirtyDays = now.add(const Duration(days: 30));
final expiringAlerts = <ExpiryAlert>[];
for (final batch in batches) {
  if (batch.remainingQuantity > 0 &&
      batch.expiryDate != null &&
      batch.expiryDate!.isAfter(now) &&
      batch.expiryDate!.isBefore(thirtyDays)) {
    final itemName = itemNames[batch.itemId] ?? 'Item #${batch.itemId}';
    final daysLeft = batch.expiryDate!.difference(now).inDays;
    expiringAlerts.add(ExpiryAlert(
      itemName: itemName,
      expiryDate: batch.expiryDate!,
      daysLeft: daysLeft,
      remainingQuantity: batch.remainingQuantity,
    ));
  }
}
expiringAlerts.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
```

### 1e. Update ReportingScreen call sites

In `lib/screens/reporting_screen.dart`, update `buildReport()` calls to
pass the new parameters:

```dart
final report = _reportingService.buildReport(
  // ... existing params ...
  batches: _purchaseController.batches,              // NEW
  lowStockItems: _inventoryController.lowStockItems, // NEW
);
```

Also update `_DailyReportList`'s `buildDailyReport()` calls if needed
(the daily report uses `buildDailyReport` which internally calls
`buildReport`, so it also needs the new params).

Files: lib/services/reporting_service.dart, lib/screens/reporting_screen.dart


Phase 2: Restructure On-Screen Report Cards
---------------------------------------------

File: lib/screens/reporting_screen.dart

### 2a. Replace current 6 info cards

Current cards (2 rows of 2 + 1 row of 2):

| Sales | Purchases |
| Expenses | Profit (cash) |
| Net Outflow | Inventory Value |

Replace with:

**Row 1 — Quick-glance overview (4 cards in 2x2):**

| Sales Revenue | Gross Profit |
| Expenses | Net Profit |

Captions:
- Sales Revenue: "Selling price · 12 transactions"
- Gross Profit: "Margin 58.9%"
- Expenses: "1 entry"
- Net Profit: colored green if positive, red if negative

**Row 2 — Cash Flow (2 cards):**

| Money In | Money Out |
| Net Cash Flow | |

Actually, 3 cards don't fit in a 2-column row cleanly. Use:

| Money In | Money Out |
| Net Cash Flow | Inventory Value |

Captions:
- Money In: "Sales"
- Money Out: "Purchases + Expenses"
- Net Cash Flow: "Cash movement"
- Inventory Value: "Current stock" (keep existing)

### 2b. Add P&L detail section

After the cards, add a new section "Financial Summary" as a Card with
a P&L-style list:

```
Financial Summary

Sales Revenue                    158.00
Cost of Goods Sold (Purchase Cost) 65.00
──────────────────────────────────────
Gross Profit                      93.00
  Gross Margin                    58.9%

Operating Expenses             1,000.00
──────────────────────────────────────
Net Profit                     -907.00
```

Implement using a `_buildPnlCard()` method that returns a `Card` with
`Padding` and `Column` containing `Row` widgets for each line, with
`Divider()` for separators.

### 2c. Add Cash Flow section

After P&L, add a "Cash Flow" Card:

```
Cash Flow

Money In (Sales)                 158.00
Money Out (Purchases)             65.00
Money Out (Expenses)           1,000.00
──────────────────────────────────────
Net Cash Flow                  -907.00
```

### 2d. Add Top Selling Items section

After Cash Flow, add:

```
Top Selling Items

[existing _ReportList widget with report.salesLines]
```

### 2e. Update Inventory Alerts section

Replace `_HealthRow` (just showing counts) with a full alerts section
that shows:

1. Inventory Value card (keep in cash flow row)
2. Low stock items list (if any) — show item name and quantity
3. Expiring items list (if any) — show item name, expiry date, days left

### 2f. Rename labels

- "Profit (cash)" → "Net Profit"
- "Sales total (selling price)" → "Sales Revenue"
- "Purchases total (unit cost)" → "COGS (Purchase Cost)"
- Remove "Net Outflow" card (replaced by Cash Flow)
- Info banner: "Gross profit uses purchase cost as COGS proxy. Actual
  COGS may differ with FIFO/FEFO accounting."

### 2g. Update _DailyReportList label

In `_DailyReportList`, change "Profit (cash)" to "Net Profit" in the
subtitle Text widget.

Files: lib/screens/reporting_screen.dart


Phase 3: Restructure CSV Export
---------------------------------

File: lib/screens/reporting_screen.dart (_buildCsvContent method)

New CSV structure:

```csv
"Monthly Report","2026-06-01 to 2026-06-18"
"Generated","2026-06-18 21:15"
,
"FINANCIAL SUMMARY",
"Metric","Value",
"Sales Revenue","158.00",
"Cost of Goods Sold (Purchase Cost)","65.00",
"Gross Profit","93.00",
"Gross Margin","58.9%",
"Operating Expenses","1000.00",
"Net Profit","-907.00",
,
"CASH FLOW",
"Metric","Value",
"Money In (Sales)","158.00",
"Money Out (Purchases)","65.00",
"Money Out (Expenses)","1000.00",
"Net Cash Flow","-907.00",
,
"TRANSACTIONS",
"Type","Count",
"Sales","12",
"Purchases","2",
"Expenses","1",
,
"INVENTORY SUMMARY",
"Metric","Value",
"Inventory Value","723.00",
,
"INVENTORY ALERTS",
"Type","Item","Quantity","Expiry Date","Days Left",
"Near Expiry","corn3","","2026-06-20","2",
"Low Stock","Item A","2","","",
,
"TOP SELLING ITEMS",
"Item","Quantity","Revenue",
"corn3","8","120.00",
"corn2","2","38.00",
,
"PURCHASES BY ITEM",
"Item","Quantity","Cost",
...(keep existing)
,
"EXPENSES BY CATEGORY",
"Category","Entries","Total",
...(keep existing)
```

Implementation:

```dart
String _buildCsvContent(ReportData report) {
  final generated = DateTime.now();
  final stamp = '${_formatDate(generated)} ${generated.hour.toString().padLeft(2, '0')}:${generated.minute.toString().padLeft(2, '0')}';
  final grossMarginDisplay = report.salesTotal > 0
      ? '${report.grossMargin.toStringAsFixed(1)}%'
      : 'N/A';

  final rows = <List<dynamic>>[
    ['Monthly Report', '${_formatDate(report.start)} to ${_formatDate(report.end)}'],
    ['Generated', stamp],
    [],
    ['FINANCIAL SUMMARY'],
    ['Metric', 'Value'],
    ['Sales Revenue', report.salesTotal.toStringAsFixed(2)],
    ['Cost of Goods Sold (Purchase Cost)', report.purchasesTotal.toStringAsFixed(2)],
    ['Gross Profit', report.grossProfit.toStringAsFixed(2)],
    ['Gross Margin', grossMarginDisplay],
    ['Operating Expenses', report.expensesTotal.toStringAsFixed(2)],
    ['Net Profit', report.netCashFlow.toStringAsFixed(2)],
    [],
    ['CASH FLOW'],
    ['Metric', 'Value'],
    ['Money In (Sales)', report.totalCashIn.toStringAsFixed(2)],
    ['Money Out (Purchases)', report.purchasesTotal.toStringAsFixed(2)],
    ['Money Out (Expenses)', report.expensesTotal.toStringAsFixed(2)],
    ['Net Cash Flow', report.netCashFlow.toStringAsFixed(2)],
    [],
    ['TRANSACTIONS'],
    ['Type', 'Count'],
    ['Sales', report.salesCount],
    ['Purchases', report.purchaseCount],
    ['Expenses', report.expenseCount],
    [],
    ['INVENTORY SUMMARY'],
    ['Metric', 'Value'],
    ['Inventory Value', report.inventoryValue.toStringAsFixed(2)],
    [],
    ['INVENTORY ALERTS'],
    ['Type', 'Item', 'Quantity', 'Expiry Date', 'Days Left'],
    ...report.lowStockItems.map((item) =>
      ['Low Stock', item.name, item.quantity, '', '']),
    ...report.expiringAlerts.map((alert) =>
      ['Near Expiry', alert.itemName, '', _formatDate(alert.expiryDate), alert.daysLeft]),
    [],
    ['TOP SELLING ITEMS'],
    ['Item', 'Quantity', 'Revenue'],
    ...report.salesLines.map((line) => [
      line.label, line.quantity, line.total.toStringAsFixed(2)]),
    [],
    ['PURCHASES BY ITEM'],
    ['Item', 'Quantity', 'Cost'],
    ...report.purchaseLines.map((line) => [
      line.label, line.quantity, line.total.toStringAsFixed(2)]),
    [],
    ['EXPENSES BY CATEGORY'],
    ['Category', 'Entries', 'Total'],
    ...report.expenseLines.map((line) => [
      line.label, line.quantity, line.total.toStringAsFixed(2)]),
  ];

  return const ListToCsvConverter().convert(rows);
}
```

Files: lib/screens/reporting_screen.dart


Phase 4: Restructure PDF Export
---------------------------------

File: lib/screens/reporting_screen.dart (_buildPdfBytes method)

Same sections as CSV but formatted with pw.Table and pw.Text:

```dart
Future<List<int>> _buildPdfBytes(ReportData report) async {
  final doc = pw.Document();
  final rangeText = '${_formatDate(report.start)} - ${_formatDate(report.end)}';
  final generated = _formatDate(DateTime.now());
  final grossMarginDisplay = report.salesTotal > 0
      ? '${report.grossMargin.toStringAsFixed(1)}%'
      : 'N/A';

  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        // Title
        pw.Text('Monthly Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Period: $rangeText'),
        pw.Text('Generated: $generated'),
        pw.SizedBox(height: 16),

        // Financial Summary
        pw.Text('Financial Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const ['Metric', 'Value'],
          data: [
            ['Sales Revenue', report.salesTotal.toStringAsFixed(2)],
            ['Cost of Goods Sold (Purchase Cost)', report.purchasesTotal.toStringAsFixed(2)],
            ['Gross Profit', report.grossProfit.toStringAsFixed(2)],
            ['Gross Margin', grossMarginDisplay],
            ['Operating Expenses', report.expensesTotal.toStringAsFixed(2)],
            ['Net Profit', report.netCashFlow.toStringAsFixed(2)],
          ],
        ),
        pw.SizedBox(height: 16),

        // Cash Flow
        pw.Text('Cash Flow',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const ['Metric', 'Value'],
          data: [
            ['Money In (Sales)', report.totalCashIn.toStringAsFixed(2)],
            ['Money Out (Purchases)', report.purchasesTotal.toStringAsFixed(2)],
            ['Money Out (Expenses)', report.expensesTotal.toStringAsFixed(2)],
            ['Net Cash Flow', report.netCashFlow.toStringAsFixed(2)],
          ],
        ),
        pw.SizedBox(height: 16),

        // Transactions
        pw.Text('Transactions',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const ['Type', 'Count'],
          data: [
            ['Sales', report.salesCount.toString()],
            ['Purchases', report.purchaseCount.toString()],
            ['Expenses', report.expenseCount.toString()],
          ],
        ),
        pw.SizedBox(height: 16),

        // Inventory Summary
        pw.Text('Inventory Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const ['Metric', 'Value'],
          data: [
            ['Inventory Value', report.inventoryValue.toStringAsFixed(2)],
          ],
        ),

        // Inventory Alerts (conditional)
        if (report.lowStockItems.isNotEmpty || report.expiringAlerts.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Inventory Alerts',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: const ['Type', 'Item', 'Quantity', 'Expiry Date', 'Days Left'],
            data: [
              ...report.lowStockItems.map((item) =>
                ['Low Stock', item.name, item.quantity.toString(), '', '']),
              ...report.expiringAlerts.map((alert) =>
                ['Near Expiry', alert.itemName, '', _formatDate(alert.expiryDate), alert.daysLeft.toString()]),
            ],
          ),
        ],

        // Top Selling Items
        pw.SizedBox(height: 16),
        pw.Text('Top Selling Items',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const ['Item', 'Quantity', 'Revenue'],
          data: report.salesLines
              .take(12)
              .map((line) => [
                line.label,
                line.quantity.toString(),
                line.total.toStringAsFixed(2),
              ])
              .toList(),
        ),
        pw.SizedBox(height: 16),

        // Purchases by Item (keep existing, limit 12)
        pw.Text('Purchases by Item',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const ['Item', 'Quantity', 'Cost'],
          data: report.purchaseLines
              .take(12)
              .map((line) => [
                line.label,
                line.quantity.toString(),
                line.total.toStringAsFixed(2),
              ])
              .toList(),
        ),
        pw.SizedBox(height: 16),

        // Expenses by Category (keep existing, limit 12)
        pw.Text('Expenses by Category',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const ['Category', 'Entries', 'Total'],
          data: report.expenseLines
              .take(12)
              .map((line) => [
                line.label,
                line.quantity.toString(),
                line.total.toStringAsFixed(2),
              ])
              .toList(),
        ),
      ],
    ),
  );

  return doc.save();
}
```

Files: lib/screens/reporting_screen.dart


Phase 5: Rename Labels & Update Info Banner
---------------------------------------------

File: lib/screens/reporting_screen.dart

### 5a. Rename in info cards

- "Sales" → "Sales Revenue" (title), keep caption with transaction count
- "Purchases" → remove card (replaced by COGS in P&L and Money Out in Cash Flow)
- "Expenses" → keep card, update caption
- "Profit (cash)" → "Net Profit"
- "Net Outflow" → remove card (replaced by Cash Flow section)
- "Inventory Value" → keep but move to Cash Flow row

### 5b. Update info banner text

Change from:
  "Sales totals use selling prices. Purchases use unit cost.
   Profit is cash flow, not FIFO/FEFO COGS."

To:
  "Gross profit uses purchase cost as COGS proxy. Actual COGS may
   differ with FIFO/FEFO accounting."

### 5c. Rename in _DailyReportList subtitle

Change "Profit (cash)" to "Net Profit" in the ExpansionTile subtitle.

### 5d. Rename in CSV labels

- "Sales total (selling price)" → "Sales Revenue"
- "Purchases total (unit cost)" → "Cost of Goods Sold (Purchase Cost)"
- "Profit (cash)" → "Net Profit"
- "Net outflow" → removed (replaced by Cash Flow)
- "Purchases by item (cost)" → "Purchases by Item"

### 5e. Rename in PDF labels

Same as CSV labels above.

Files: lib/screens/reporting_screen.dart


Phase 6: Deprecate netOutflow in Model
----------------------------------------

File: lib/services/reporting_service.dart

- Mark `netOutflow` field in `ReportData` with `@Deprecated('Use netCashFlow instead')`
- Keep field temporarily for any remaining references
- Update any code that reads `report.netOutflow` to use `report.netCashFlow`
  or `report.totalCashOut` instead
- The `DailyReport` class also has a `profit` field — keep it but label
  it "Net Profit" in UI/exports

Files: lib/services/reporting_service.dart, lib/screens/reporting_screen.dart


Implementation Order
--------------------
1. Phase 1: Extend model (add fields, update buildReport, ExpiryAlert class)
2. Phase 2: Restructure on-screen UI (cards, P&L, cash flow, top sellers, alerts)
3. Phase 3: Restructure CSV export
4. Phase 4: Restructure PDF export
5. Phase 5: Rename labels and update info banner
6. Phase 6: Deprecate netOutflow, clean up


Summary of Files to Modify
----------------------------
| File | Changes |
|---|---|
| lib/services/reporting_service.dart | Add ExpiryAlert class; extend ReportData with salesLines, grossProfit, grossMargin, totalCashIn, totalCashOut, netCashFlow, lowStockItems, expiringAlerts; update buildReport() |
| lib/screens/reporting_screen.dart | Pass new params to buildReport(); restructure info cards; add P&L section, cash flow section, top sellers section, inventory alerts section; update CSV/PDF exports; rename labels; update info banner |


Testing Checklist
------------------
- [ ] Monthly CSV export includes all new sections
- [ ] Monthly PDF export includes all new sections
- [ ] WhatsApp share sends both updated CSV and PDF
- [ ] Info cards show correct values (Sales Revenue, Gross Profit, Expenses, Net Profit)
- [ ] Cash Flow cards show correct values
- [ ] P&L section displays correctly with dividers and margin
- [ ] Top Selling Items section appears with data
- [ ] Inventory Alerts section shows low stock items and expiring items with details
- [ ] Daily report cards in _DailyReportList still display "Net Profit" correctly
- [ ] Tapping daily report card still navigates to DailyReportDetailScreen
- [ ] No regression in existing monthly/year-to-date toggle behavior