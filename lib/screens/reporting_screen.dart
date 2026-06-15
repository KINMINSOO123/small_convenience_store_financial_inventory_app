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
import '../services/reporting_service.dart';

class ReportingScreen extends StatefulWidget {
  const ReportingScreen({
    super.key,
    required this.inventoryController,
    required this.purchaseController,
    required this.expensesController,
    required this.salesController,
  });

  final InventoryController inventoryController;
  final PurchaseController purchaseController;
  final ExpensesController expensesController;
  final SalesController salesController;

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

  ReportRange _range = ReportRange.monthToDate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _inventoryController,
        _expensesController,
        _salesController,
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
                            'Sales totals use selling prices. Purchases use unit cost. Profit is cash flow, not FIFO/FEFO COGS.',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              title: 'Sales',
                              value: report.salesTotal.toStringAsFixed(2),
                              caption: 'Selling price · ${report.salesCount} entries',
                              icon: Icons.point_of_sale_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              title: 'Purchases',
                              value: report.purchasesTotal.toStringAsFixed(2),
                              caption: 'Unit cost · ${report.purchaseCount} entries',
                              icon: Icons.shopping_cart_outlined,
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
                              title: 'Profit (cash)',
                              value: report.profit.toStringAsFixed(2),
                              caption: 'Sales - outflow',
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
                              title: 'Net Outflow',
                              value: report.netOutflow.toStringAsFixed(2),
                              caption: 'Purchases + expenses',
                              icon: Icons.trending_down,
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
                      const SizedBox(height: 16),
                      _SectionHeader(
                        title: 'Inventory health',
                        trailing: Text(
                          'Low stock: ${report.lowStockCount} • Expiring soon: ${report.expiringSoonCount}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _HealthRow(
                        lowStockCount: report.lowStockCount,
                        expiringSoonCount: report.expiringSoonCount,
                      ),
                      const SizedBox(height: 16),
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
                                  lowStockCount:
                                      _inventoryController.lowStockItems.length,
                                  expiringSoonCount:
                                      _inventoryController.expiringSoonItems.length,
                                ),
                              ],
                        formatDate: _formatDate,
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
      lowStockCount: _inventoryController.lowStockItems.length,
      expiringSoonCount: _inventoryController.expiringSoonItems.length,
    );
  }

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

    final message =
        'Report ${_formatDate(report.start)} - ${_formatDate(report.end)}';
    await Share.shareXFiles(
      [
        XFile(csvPath, mimeType: 'text/csv'),
        XFile(pdfPath, mimeType: 'application/pdf'),
      ],
      text: message,
    );
  }

  String _buildCsvContent(ReportData report) {
    final rows = <List<dynamic>>[
      [
        'Report range',
        '${_formatDate(report.start)} - ${_formatDate(report.end)}',
      ],
      [],
      ['Summary'],
      ['Metric', 'Value'],
      ['Sales total (selling price)', report.salesTotal.toStringAsFixed(2)],
      ['Purchases total (unit cost)', report.purchasesTotal.toStringAsFixed(2)],
      ['Expenses total', report.expensesTotal.toStringAsFixed(2)],
      ['Net outflow', report.netOutflow.toStringAsFixed(2)],
      ['Profit (cash)', report.profit.toStringAsFixed(2)],
      ['Inventory value', report.inventoryValue.toStringAsFixed(2)],
      ['Low stock items', report.lowStockCount],
      ['Expiring soon items', report.expiringSoonCount],
      [],
      ['Purchases by item (cost)'],
      ['Item', 'Quantity', 'Cost'],
      ...report.purchaseLines.map(
        (line) => [
          line.label,
          line.quantity,
          line.total.toStringAsFixed(2),
        ],
      ),
      [],
      ['Expenses by category'],
      ['Category', 'Entries', 'Total'],
      ...report.expenseLines.map(
        (line) => [
          line.label,
          line.quantity,
          line.total.toStringAsFixed(2),
        ],
      ),
    ];

    return const ListToCsvConverter().convert(rows);
  }

  Future<List<int>> _buildPdfBytes(ReportData report) async {
    final doc = pw.Document();
    final rangeText = '${_formatDate(report.start)} - ${_formatDate(report.end)}';

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Reporting Summary',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Range: $rangeText'),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [
              ['Sales total (selling price)', report.salesTotal.toStringAsFixed(2)],
              ['Purchases total (unit cost)', report.purchasesTotal.toStringAsFixed(2)],
              ['Expenses total', report.expensesTotal.toStringAsFixed(2)],
              ['Net outflow', report.netOutflow.toStringAsFixed(2)],
              ['Profit (cash)', report.profit.toStringAsFixed(2)],
              ['Inventory value', report.inventoryValue.toStringAsFixed(2)],
              ['Low stock items', report.lowStockCount.toString()],
              ['Expiring soon items', report.expiringSoonCount.toString()],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Purchases by item (cost)',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Table.fromTextArray(
            headers: const ['Item', 'Quantity', 'Cost'],
            data: report.purchaseLines
                .take(12)
                .map(
                  (line) => [
                    line.label,
                    line.quantity.toString(),
                    line.total.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Expenses by category',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Table.fromTextArray(
            headers: const ['Category', 'Entries', 'Total'],
            data: report.expenseLines
                .take(12)
                .map(
                  (line) => [
                    line.label,
                    line.quantity.toString(),
                    line.total.toStringAsFixed(2),
                  ],
                )
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
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (trailing != null) trailing!,
      ],
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
  });

  final List<DailyReport> reports;
  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Center(child: Text('No daily activity in this range.'));
    }
    return Column(
      children: reports
          .map(
            (report) => Card(
              child: ExpansionTile(
                title: Text(formatDate(report.date)),
                subtitle: Text(
                  'Sales ${report.salesTotal.toStringAsFixed(2)} · '
                  'Qty ${report.salesQuantity} · '
                  'Expenses ${report.expensesTotal.toStringAsFixed(2)} · '
                  'Profit (cash) ${report.profit.toStringAsFixed(2)}',
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
          )
          .toList(),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.lowStockCount,
    required this.expiringSoonCount,
  });

  final int lowStockCount;
  final int expiringSoonCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HealthTile(
            label: 'Low stock items',
            value: lowStockCount.toString(),
            icon: Icons.warning_amber_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HealthTile(
            label: 'Expiring soon',
            value: expiringSoonCount.toString(),
            icon: Icons.timer_outlined,
          ),
        ),
      ],
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
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
