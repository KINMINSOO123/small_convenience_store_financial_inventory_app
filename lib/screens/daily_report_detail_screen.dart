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

class DailyReportDetailScreen extends StatefulWidget {
  const DailyReportDetailScreen({
    super.key,
    required this.inventoryController,
    required this.purchaseController,
    required this.expensesController,
    required this.salesController,
    this.supplierReturnController,
    this.initialDate,
  });

  final InventoryController inventoryController;
  final PurchaseController purchaseController;
  final ExpensesController expensesController;
  final SalesController salesController;
  final SupplierReturnController? supplierReturnController;
  final DateTime? initialDate;

  @override
  State<DailyReportDetailScreen> createState() =>
      _DailyReportDetailScreenState();
}

class _DailyReportDetailScreenState extends State<DailyReportDetailScreen> {
  final _reportingService = ReportingService();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  DailyReportData _buildData() {
    return _reportingService.buildDailyReportData(
      date: _selectedDate,
      sales: widget.salesController.salesEntries,
      salesEntryItems: widget.salesController.salesEntryItems,
      expenses: widget.expensesController.expenseEntries,
      journalLines: widget.expensesController.journalLines,
      accounts: widget.expensesController.accounts,
      items: widget.inventoryController.items,
      batches: widget.purchaseController.batches,
      supplierReturns:
          widget.supplierReturnController?.returns ?? [],
      supplierReturnItems:
          widget.supplierReturnController?.returnItems ?? [],
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _fmt(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _buildData();

    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Report — ${_formatDate(_selectedDate)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Profit & Loss Summary', [
              _pnlRow('Sales Revenue', data.salesRevenue, positive: true),
              _pnlRow('Cost of Goods Sold', -data.costOfGoodsSold),
              if (data.supplierReturnTotal > 0)
                _pnlRow('Supplier Returns', -data.supplierReturnTotal),
              const Divider(height: 24),
              _pnlRow('Gross Profit', data.grossProfit,
                  bold: true, positive: true),
              _pnlRow('Expenses', -data.expensesTotal),
              const Divider(height: 24),
              _pnlRow('Net Profit', data.netProfit, bold: true),
            ]),
            const SizedBox(height: 16),
            _section('Sales Breakdown', [
              Text('Transactions: ${data.transactionCount}',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              ...data.salesLines.map((line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(line.label)),
                        Text('${line.quantity} × \$${_fmt(line.total)}'),
                      ],
                    ),
                  )),
            ]),
            if (data.topSellingItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              _section('Top Selling Products', [
                ...data.topSellingItems.map((line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(line.label)),
                          Text('${line.quantity}'),
                        ],
                      ),
                    )),
              ]),
            ],
            if (data.expenseLines.isNotEmpty) ...[
              const SizedBox(height: 16),
              _section('Expense Breakdown', [
                ...data.expenseLines.map((line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(line.label)),
                          Text('\$${_fmt(line.total)}'),
                        ],
                      ),
                    )),
                const Divider(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Total',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text('\$${_fmt(data.expensesTotal)}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ]),
            ],
            if (data.lowStockItems.isNotEmpty ||
                data.expiringSoonItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              _section('Inventory Alerts', [
                if (data.lowStockItems.isNotEmpty) ...[
                  Text('Low Stock Items',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  ...data.lowStockItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.name)),
                            Text('${item.quantity} left'),
                          ],
                        ),
                      )),
                ],
                if (data.expiringSoonItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Near Expiry',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  ...data.expiringSoonItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(item.name),
                      )),
                ],
              ]),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _exportCsv(data),
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Export CSV'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportPdf(data),
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
                onPressed: () => _shareWhatsapp(data),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share via WhatsApp'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _pnlRow(String label, double value,
      {bool bold = false, bool positive = false}) {
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

  Future<void> _exportCsv(DailyReportData data) async {
    final directory = await getApplicationDocumentsDirectory();
    final stamp = _fileTimestamp();
    final filePath = path.join(
      directory.path,
      'daily_report_${_formatDate(_selectedDate)}_$stamp.csv',
    );

    await File(filePath).writeAsString(_buildCsvContent(data));
    if (!mounted) return;
    await _showExportResult('CSV', filePath);
  }

  Future<void> _exportPdf(DailyReportData data) async {
    final directory = await getApplicationDocumentsDirectory();
    final stamp = _fileTimestamp();
    final filePath = path.join(
      directory.path,
      'daily_report_${_formatDate(_selectedDate)}_$stamp.pdf',
    );

    await File(filePath).writeAsBytes(await _buildPdfBytes(data));
    if (!mounted) return;
    await _showExportResult('PDF', filePath);
  }

  Future<void> _shareWhatsapp(DailyReportData data) async {
    final directory = await getApplicationDocumentsDirectory();
    final stamp = _fileTimestamp();
    final dateStr = _formatDate(_selectedDate);
    final csvPath = path.join(
      directory.path,
      'daily_report_${dateStr}_$stamp.csv',
    );
    final pdfPath = path.join(
      directory.path,
      'daily_report_${dateStr}_$stamp.pdf',
    );

    await File(csvPath).writeAsString(_buildCsvContent(data));
    await File(pdfPath).writeAsBytes(await _buildPdfBytes(data));

    await Share.shareXFiles(
      [
        XFile(csvPath, mimeType: 'text/csv'),
        XFile(pdfPath, mimeType: 'application/pdf'),
      ],
    );
  }

  String _buildCsvContent(DailyReportData data) {
    final dateStr = _formatDate(_selectedDate);
    final rows = <List<dynamic>>[
      ['Daily Report', dateStr],
      [],
      ['Profit & Loss Summary'],
      ['Metric', 'Value'],
      ['Sales Revenue', data.salesRevenue.toStringAsFixed(2)],
      ['Cost of Goods Sold', data.costOfGoodsSold.toStringAsFixed(2)],
      ['Supplier Returns', data.supplierReturnTotal.toStringAsFixed(2)],
      ['Gross Profit', data.grossProfit.toStringAsFixed(2)],
      ['Expenses', data.expensesTotal.toStringAsFixed(2)],
      ['Net Profit', data.netProfit.toStringAsFixed(2)],
      [],
      ['Sales Breakdown'],
      ['Item', 'Quantity', 'Total'],
      ...data.salesLines.map(
        (line) => [
          line.label,
          line.quantity,
          line.total.toStringAsFixed(2),
        ],
      ),
      [],
      ['Top Selling Products'],
      ['Item', 'Quantity'],
      ...data.topSellingItems.map(
        (line) => [line.label, line.quantity],
      ),
      [],
      ['Expense Breakdown'],
      ['Category', 'Entries', 'Total'],
      ...data.expenseLines.map(
        (line) => [line.label, line.quantity, line.total.toStringAsFixed(2)],
      ),
    ];

    if (data.lowStockItems.isNotEmpty || data.expiringSoonItems.isNotEmpty) {
      rows.add([]);
      rows.add(['Inventory Alerts']);
      rows.add(['Type', 'Item', 'Details']);
      for (final item in data.lowStockItems) {
        rows.add(['Low Stock', item.name, '${item.quantity} left']);
      }
      for (final item in data.expiringSoonItems) {
        rows.add(['Near Expiry', item.name, 'Expiring soon']);
      }
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<List<int>> _buildPdfBytes(DailyReportData data) async {
    final doc = pw.Document();
    final dateStr = _formatDate(_selectedDate);

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Daily Report — $dateStr',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Profit & Loss Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Table.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [
              ['Sales Revenue', '\$${data.salesRevenue.toStringAsFixed(2)}'],
              ['Cost of Goods Sold',
                  '\$${data.costOfGoodsSold.toStringAsFixed(2)}'],
              ['Supplier Returns',
                  '\$${data.supplierReturnTotal.toStringAsFixed(2)}'],
              ['Gross Profit', '\$${data.grossProfit.toStringAsFixed(2)}'],
              ['Expenses', '\$${data.expensesTotal.toStringAsFixed(2)}'],
              ['Net Profit', '\$${data.netProfit.toStringAsFixed(2)}'],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Sales Breakdown',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Transactions: ${data.transactionCount}'),
          pw.Table.fromTextArray(
            headers: const ['Item', 'Quantity', 'Total'],
            data: data.salesLines
                .map(
                  (line) => [
                    line.label,
                    line.quantity.toString(),
                    '\$${line.total.toStringAsFixed(2)}',
                  ],
                )
                .toList(),
          ),
          if (data.topSellingItems.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Top Selling Products',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Table.fromTextArray(
              headers: const ['Item', 'Quantity'],
              data: data.topSellingItems
                  .map((line) => [line.label, line.quantity.toString()])
                  .toList(),
            ),
          ],
          if (data.expenseLines.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Expense Breakdown',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Table.fromTextArray(
              headers: const ['Category', 'Entries', 'Total'],
              data: [
                ...data.expenseLines.map(
                  (line) => [
                    line.label,
                    line.quantity.toString(),
                    '\$${line.total.toStringAsFixed(2)}',
                  ],
                ),
                [
                  'Total',
                  '',
                  '\$${data.expensesTotal.toStringAsFixed(2)}',
                ],
              ],
            ),
          ],
          if (data.lowStockItems.isNotEmpty ||
              data.expiringSoonItems.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Inventory Alerts',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            if (data.lowStockItems.isNotEmpty) ...[
              pw.Text('Low Stock Items',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ...data.lowStockItems.map(
                (item) => pw.Text('${item.name} — ${item.quantity} left'),
              ),
            ],
            if (data.expiringSoonItems.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Near Expiry',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ...data.expiringSoonItems.map(
                (item) => pw.Text(item.name),
              ),
            ],
          ],
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
                if (!context.mounted) return;
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

  String _fileTimestamp() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '${y}${m}${d}_$h$min';
  }
}
