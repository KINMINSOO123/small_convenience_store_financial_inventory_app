import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../controllers/expenses_controller.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/purchase_controller.dart';
import '../controllers/sales_controller.dart';
import '../controllers/supplier_return_controller.dart';
import '../services/reporting_service.dart';
import 'daily_report_detail_screen.dart';

class ReportingScreen extends StatefulWidget {
  const ReportingScreen({
    super.key,
    required this.inventoryController,
    required this.purchaseController,
    required this.expensesController,
    required this.salesController,
    this.supplierReturnController,
  });

  final InventoryController inventoryController;
  final PurchaseController purchaseController;
  final ExpensesController expensesController;
  final SalesController salesController;
  final SupplierReturnController? supplierReturnController;

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

enum ReportRange { monthToDate, yearToDate }

class _ReportingScreenState extends State<ReportingScreen> {
  final ReportingService _reportingService = ReportingService();

  DateTime? _selectedDate;

  InventoryController get _inventoryController => widget.inventoryController;
  PurchaseController get _purchaseController => widget.purchaseController;
  ExpensesController get _expensesController => widget.expensesController;
  SalesController get _salesController => widget.salesController;
  SupplierReturnController? get _supplierReturnController =>
      widget.supplierReturnController;

  ReportRange _range = ReportRange.monthToDate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _inventoryController,
        _expensesController,
        _salesController,
        if (_supplierReturnController != null) _supplierReturnController!,
      ]),
      builder: (context, _) {
        final report = _buildReport();
        return Scaffold(
          body: _inventoryController.isLoading ||
                  _expensesController.isLoading ||
                  _salesController.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reporting',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                        Text(
                          'Range: ${_formatDate(report.start)} - ${_formatDate(report.end)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<ReportRange>(
                        segments: const [
                          ButtonSegment(
                            value: ReportRange.monthToDate,
                            label: Text('Month-to-date'),
                          ),
                          ButtonSegment(
                            value: ReportRange.yearToDate,
                            label: Text('Year-to-date'),
                          ),
                        ],
                        selected: {_range},
                        onSelectionChanged: (value) {
                          setState(() {
                            _range = value.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _InfoBanner(
                        message:
                            'Gross profit uses purchase cost as COGS proxy. Actual COGS may differ with FIFO/FEFO accounting.',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              title: 'Sales Revenue',
                              value: report.salesTotal.toStringAsFixed(2),
                              caption: '${report.salesCount} transactions',
                              icon: Icons.point_of_sale_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              title: 'Gross Profit',
                              value: report.grossProfit.toStringAsFixed(2),
                              caption: report.salesTotal > 0
                                  ? 'Margin ${report.grossMargin.toStringAsFixed(1)}%'
                                  : 'No sales',
                              icon: Icons.trending_up,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              title: 'Expenses',
                              value: report.expensesTotal.toStringAsFixed(2),
                              caption: '${report.expenseCount} entries',
                              icon: Icons.payments_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              title: 'Net Profit',
                              value: report.netCashFlow.toStringAsFixed(2),
                              caption: 'After all costs',
                              icon: Icons.account_balance,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              title: 'Money In',
                              value: report.totalCashIn.toStringAsFixed(2),
                              caption: 'Sales revenue',
                              icon: Icons.arrow_downward,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              title: 'Money Out',
                              value: report.totalCashOut.toStringAsFixed(2),
                              caption: 'Purchases + Expenses',
                              icon: Icons.arrow_upward,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              title: 'Net Cash Flow',
                              value: report.netCashFlow.toStringAsFixed(2),
                              caption: 'Cash movement',
                              icon: Icons.swap_horiz,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              title: 'Inventory Value',
                              value: report.inventoryValue.toStringAsFixed(2),
                              caption: 'Current stock',
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildPnlCard(report),
                      const SizedBox(height: 16),
                      _buildCashFlowCard(report),
                      const SizedBox(height: 16),
                      if (report.salesLines.isNotEmpty) ...[
                        _SectionHeader(title: 'Top Selling Items'),
                        const SizedBox(height: 8),
                        _ReportList(
                          lines: report.salesLines,
                          emptyLabel: 'No sales in this range.',
                          quantityLabel: 'Qty sold',
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (report.expiringAlerts.isNotEmpty ||
                          report.lowStockItems.isNotEmpty) ...[
                        _SectionHeader(title: 'Inventory Alerts'),
                        const SizedBox(height: 8),
                        if (report.lowStockItems.isNotEmpty) ...[
                          _AlertSection(
                            title: 'Low Stock Items',
                            items: report.lowStockItems
                                .map((item) => _AlertItem(
                                      name: item.name,
                                      detail: '${item.quantity} left',
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (report.expiringAlerts.isNotEmpty) ...[
                          _AlertSection(
                            title: 'Expiring Soon',
                            items: report.expiringAlerts
                                .map((alert) => _AlertItem(
                                      name: alert.itemName,
                                      detail:
                                          'Expires ${_formatDate(alert.expiryDate)} · ${alert.daysLeft} days left',
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (report.lowStockCount == 0 &&
                            report.expiringSoonCount == 0) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('No inventory alerts.',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                      _SectionHeader(title: 'Purchases by item'),
                      const SizedBox(height: 8),
                      _ReportList(
                        emptyLabel: 'No purchases in this range.',
                        lines: report.purchaseLines,
                        quantityLabel: 'Units (cost)',
                      ),
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Expenses by category'),
                      const SizedBox(height: 8),
                      _ReportList(
                        emptyLabel: 'No expenses in this range.',
                        lines: report.expenseLines,
                        quantityLabel: 'Entries',
                      ),
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Daily reports'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedDate = picked;
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: Text(_selectedDate == null
                                  ? 'Select date'
                                  : _formatDate(_selectedDate!)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
                              });
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _DailyReportList(
                        reports: _selectedDate == null
                            ? report.dailyReports
                            : [
                                _reportingService.buildDailyReport(
                                  date: _selectedDate,
                                  purchases: _purchaseController.allPurchases,
                                  purchaseEntryItems:
                                      _purchaseController.purchaseEntryItems,
                                  items: _inventoryController.allItems,
                                  expenses: _expensesController.expenseEntries,
                                  journalLines: _expensesController.journalLines,
                                  accounts: _expensesController.accounts,
                                  sales: _salesController.salesEntries,
                                  salesEntryItems:
                                      _salesController.salesEntryItems,
                                  inventoryValue: _inventoryController.totalValue,
                                  batches: _purchaseController.batches,
                                  lowStockItems:
                                      _inventoryController.lowStockItems,
                                  supplierReturns:
                                      _supplierReturnController?.returns ?? [],
                                  supplierReturnItems:
                                      _supplierReturnController?.returnItems ?? [],
                                ),
                              ],
                        formatDate: _formatDate,
                        onTap: (date) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DailyReportDetailScreen(
                                inventoryController: _inventoryController,
                                purchaseController: _purchaseController,
                                expensesController: _expensesController,
                                salesController: _salesController,
                                supplierReturnController:
                                    _supplierReturnController,
                                initialDate: date,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _exportCsv(report),
                              icon: const Icon(Icons.table_view_outlined),
                              label: const Text('Export CSV'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _exportPdf(report),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('Export PDF'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _shareWhatsapp(report),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share via WhatsApp'),
                        ),
                      ),
                      ],
                ),
                ),
        );
      },
    );
  }



  ReportData _buildReport() {
    final now = DateTime.now();
    final start = _range == ReportRange.monthToDate
        ? DateTime(now.year, now.month, 1)
        : DateTime(now.year, 1, 1);

    return _reportingService.buildReport(
      start: start,
      end: now,
      purchases: _purchaseController.allPurchases,
      purchaseEntryItems: _purchaseController.purchaseEntryItems,
      items: _inventoryController.allItems,
      expenses: _expensesController.expenseEntries,
      journalLines: _expensesController.journalLines,
      accounts: _expensesController.accounts,
      sales: _salesController.salesEntries,
      salesEntryItems: _salesController.salesEntryItems,
      inventoryValue: _inventoryController.totalValue,
      batches: _purchaseController.batches,
      lowStockItems: _inventoryController.lowStockItems,
      supplierReturns: _supplierReturnController?.returns ?? [],
      supplierReturnItems: _supplierReturnController?.returnItems ?? [],
    );
  }

  Widget _buildPnlCard(ReportData report) {
    final theme = Theme.of(context);
    final grossMarginDisplay = report.salesTotal > 0
        ? '${report.grossMargin.toStringAsFixed(1)}%'
        : 'N/A';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Financial Summary',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _pnlRow('Sales Revenue', report.salesTotal),
            _pnlRow('Cost of Goods Sold (Purchase Cost)',
                -report.purchasesTotal),
            const Divider(height: 16),
            _pnlRow('Gross Profit', report.grossProfit,
                bold: true, showSign: true),
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text('Gross Margin: $grossMarginDisplay',
                  style: theme.textTheme.bodySmall),
            ),
            const Divider(height: 16),
            _pnlRow('Operating Expenses', -report.expensesTotal),
            const Divider(height: 16),
            _pnlRow('Net Profit', report.netCashFlow,
                bold: true, showSign: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowCard(ReportData report) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cash Flow',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _pnlRow('Money In (Sales)', report.totalCashIn),
            _pnlRow('Money Out (Purchases)', -report.purchasesTotal),
            _pnlRow('Money Out (Expenses)', -report.expensesTotal),
            const Divider(height: 16),
            _pnlRow('Net Cash Flow', report.netCashFlow,
                bold: true, showSign: true),
          ],
        ),
      ),
    );
  }

  Widget _pnlRow(String label, double value,
      {bool bold = false, bool showSign = false}) {
    final isNegative = value < 0;
    final display =
        isNegative ? '-\$${_fmt(value.abs())}' : '\$${_fmt(value)}';
    final theme = Theme.of(context);
    final color = bold
        ? (isNegative ? theme.colorScheme.error : theme.colorScheme.primary)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: bold ? FontWeight.w600 : null)),
          ),
          Text(display,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w600 : null,
                color: color,
              )),
        ],
      ),
    );
  }

  String _fmt(double value) => value.toStringAsFixed(2);

  Future<void> _exportCsv(ReportData report) async {
    final directory = await getApplicationDocumentsDirectory();
    final stamp = _fileTimestamp();
    final rangeLabel = _range == ReportRange.monthToDate ? 'mtd' : 'ytd';
    final filePath = path.join(
      directory.path,
      'report_${rangeLabel}_$stamp.csv',
    );

    await File(filePath).writeAsString(_buildCsvContent(report));
    if (!mounted) {
      return;
    }
    await _showExportResult('CSV', filePath);
  }

  Future<void> _exportPdf(ReportData report) async {
    final directory = await getApplicationDocumentsDirectory();
    final stamp = _fileTimestamp();
    final rangeLabel = _range == ReportRange.monthToDate ? 'mtd' : 'ytd';
    final filePath = path.join(
      directory.path,
      'report_${rangeLabel}_$stamp.pdf',
    );

    await File(filePath).writeAsBytes(await _buildPdfBytes(report));
    if (!mounted) {
      return;
    }
    await _showExportResult('PDF', filePath);
  }

  Future<void> _shareWhatsapp(ReportData report) async {
    final directory = await getApplicationDocumentsDirectory();
    final stamp = _fileTimestamp();
    final rangeLabel = _range == ReportRange.monthToDate ? 'mtd' : 'ytd';
    final csvPath = path.join(
      directory.path,
      'report_${rangeLabel}_$stamp.csv',
    );
    final pdfPath = path.join(
      directory.path,
      'report_${rangeLabel}_$stamp.pdf',
    );

    await File(csvPath).writeAsString(_buildCsvContent(report));
    await File(pdfPath).writeAsBytes(await _buildPdfBytes(report));

    await Share.shareXFiles(
      [
        XFile(csvPath, mimeType: 'text/csv'),
        XFile(pdfPath, mimeType: 'application/pdf'),
      ],
    );
  }

  String _buildCsvContent(ReportData report) {
    final generated = DateTime.now();
    final stamp =
        '${_formatDate(generated)} ${generated.hour.toString().padLeft(2, '0')}:${generated.minute.toString().padLeft(2, '0')}';
    final grossMarginDisplay = report.salesTotal > 0
        ? '${report.grossMargin.toStringAsFixed(1)}%'
        : 'N/A';

    final rows = <List<dynamic>>[
      ['Monthly Report',
          '${_formatDate(report.start)} to ${_formatDate(report.end)}'],
      ['Generated', stamp],
      [],
      ['FINANCIAL SUMMARY'],
      ['Metric', 'Value'],
      ['Sales Revenue', report.salesTotal.toStringAsFixed(2)],
      ['Cost of Goods Sold (Purchase Cost)',
          report.purchasesTotal.toStringAsFixed(2)],
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
    ];

    if (report.lowStockItems.isNotEmpty ||
        report.expiringAlerts.isNotEmpty) {
      rows.add([]);
      rows.add(['INVENTORY ALERTS']);
      rows.add(['Type', 'Item', 'Quantity', 'Expiry Date', 'Days Left']);
      for (final item in report.lowStockItems) {
        rows.add(['Low Stock', item.name, item.quantity, '', '']);
      }
      for (final alert in report.expiringAlerts) {
        rows.add([
          'Near Expiry',
          alert.itemName,
          '',
          _formatDate(alert.expiryDate),
          alert.daysLeft,
        ]);
      }
    }

    rows.add([]);
    rows.add(['TOP SELLING ITEMS']);
    rows.add(['Item', 'Quantity', 'Revenue']);
    for (final line in report.salesLines) {
      rows.add([line.label, line.quantity, line.total.toStringAsFixed(2)]);
    }

    rows.add([]);
    rows.add(['PURCHASES BY ITEM']);
    rows.add(['Item', 'Quantity', 'Cost']);
    for (final line in report.purchaseLines) {
      rows.add([line.label, line.quantity, line.total.toStringAsFixed(2)]);
    }

    rows.add([]);
    rows.add(['EXPENSES BY CATEGORY']);
    rows.add(['Category', 'Entries', 'Total']);
    for (final line in report.expenseLines) {
      rows.add([line.label, line.quantity, line.total.toStringAsFixed(2)]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<List<int>> _buildPdfBytes(ReportData report) async {
    final doc = pw.Document();
    final rangeText = '${_formatDate(report.start)} - ${_formatDate(report.end)}';
    final generated = DateTime.now();
    final generatedText =
        '${_formatDate(generated)} ${generated.hour.toString().padLeft(2, '0')}:${generated.minute.toString().padLeft(2, '0')}';
    final grossMarginDisplay = report.salesTotal > 0
        ? '${report.grossMargin.toStringAsFixed(1)}%'
        : 'N/A';

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Monthly Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Period: $rangeText'),
          pw.Text('Generated: $generatedText'),
          pw.SizedBox(height: 16),

          pw.Text('Financial Summary',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [
              ['Sales Revenue', report.salesTotal.toStringAsFixed(2)],
              ['Cost of Goods Sold (Purchase Cost)',
                  report.purchasesTotal.toStringAsFixed(2)],
              ['Gross Profit', report.grossProfit.toStringAsFixed(2)],
              ['Gross Margin', grossMarginDisplay],
              ['Operating Expenses', report.expensesTotal.toStringAsFixed(2)],
              ['Net Profit', report.netCashFlow.toStringAsFixed(2)],
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text('Cash Flow',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [
              ['Money In (Sales)', report.totalCashIn.toStringAsFixed(2)],
              ['Money Out (Purchases)',
                  report.purchasesTotal.toStringAsFixed(2)],
              ['Money Out (Expenses)',
                  report.expensesTotal.toStringAsFixed(2)],
              ['Net Cash Flow', report.netCashFlow.toStringAsFixed(2)],
            ],
          ),
          pw.SizedBox(height: 16),

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

          pw.Text('Inventory Summary',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [
              ['Inventory Value',
                  report.inventoryValue.toStringAsFixed(2)],
            ],
          ),

          if (report.lowStockItems.isNotEmpty ||
              report.expiringAlerts.isNotEmpty) ...[
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

  Future<void> _showExportResult(String label, String filePath) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$label export ready'),
          content: const Text('File saved to your app documents folder.'),
          actions: [
            TextButton(
              onPressed: () async {
                await Share.shareXFiles([XFile(filePath)]);
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('Share'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _fileTimestamp() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '${year}${month}${day}_$hour$minute';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    caption,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({
    required this.lines,
    required this.emptyLabel,
    required this.quantityLabel,
  });

  final List<ReportLine> lines;
  final String emptyLabel;
  final String quantityLabel;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Center(child: Text(emptyLabel));
    }
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lines.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final line = lines[index];
          return ListTile(
            title: Text(line.label),
            subtitle: Text('$quantityLabel: ${line.quantity}'),
            trailing: Text(
              line.total.toStringAsFixed(2),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DailyReportList extends StatelessWidget {
  const _DailyReportList({
    required this.reports,
    required this.formatDate,
    this.onTap,
  });

  final List<DailyReport> reports;
  final String Function(DateTime date) formatDate;
  final void Function(DateTime date)? onTap;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Center(child: Text('No daily activity in this range.'));
    }
    return Column(
      children: reports
          .map(
            (report) => Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap != null ? () => onTap!(report.date) : null,
                child: ExpansionTile(
                  title: Text(formatDate(report.date)),
                  subtitle: Text(
                    'Sales ${report.salesTotal.toStringAsFixed(2)} · '
                    'Qty ${report.salesQuantity} · '
                    'Expenses ${report.expensesTotal.toStringAsFixed(2)} · '
                    'Net Profit ${report.profit.toStringAsFixed(2)}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Sales by item',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _ReportList(
                            lines: report.salesLines,
                            emptyLabel: 'No sales for this day.',
                            quantityLabel: 'Units',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Expenses by category',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _ReportList(
                            lines: report.expenseLines,
                            emptyLabel: 'No expenses for this day.',
                            quantityLabel: 'Entries',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AlertItem {
  const _AlertItem({
    required this.name,
    required this.detail,
  });

  final String name;
  final String detail;
}

class _AlertSection extends StatelessWidget {
  const _AlertSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_AlertItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = title.contains('Expiring')
        ? theme.colorScheme.error
        : theme.colorScheme.tertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Card(
          child: Column(
            children: items
                .map((item) => ListTile(
                      dense: true,
                      title: Text(item.name),
                      trailing: Text(item.detail,
                          style: theme.textTheme.bodySmall),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
