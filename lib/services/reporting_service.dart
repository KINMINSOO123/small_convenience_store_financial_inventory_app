import '../models/account.dart';
import '../models/inventory_item.dart';
import '../models/journal_entry.dart';
import '../models/journal_line.dart';
import '../models/purchase_entry.dart';
import '../models/sales_entry.dart';
import '../models/sales_entry_item.dart';

class ReportingService {
  ReportData buildReport({
    required DateTime start,
    required DateTime end,
    required List<PurchaseEntry> purchases,
    required List<InventoryItem> items,
    required List<JournalEntry> expenses,
    required List<JournalLine> journalLines,
    required List<Account> accounts,
    required List<SalesEntry> sales,
    required List<SalesEntryItem> salesEntryItems,
    required double inventoryValue,
    required int lowStockCount,
    required int expiringSoonCount,
  }) {
    final purchasesInRange = purchases
        .where((purchase) => !purchase.isCancelled)
        .where((purchase) => _isWithin(purchase.purchasedAt, start, end))
        .toList();

    final expensesInRange = expenses
        .where((entry) => _isWithin(entry.date, start, end))
        .toList();

    final salesInRange =
      sales.where((entry) => _isWithin(entry.entryDate, start, end)).toList();

    final itemNames = {
      for (final item in items) item.id: item.name,
    };
    final purchaseTotals = <String, ReportLine>{};
    for (final purchase in purchasesInRange) {
      final label = itemNames[purchase.itemId] ?? 'Item #${purchase.itemId}';
      final total = purchase.quantity * purchase.unitCost;
      purchaseTotals.update(
        label,
        (line) => line.copyWith(
          quantity: line.quantity + purchase.quantity,
          total: line.total + total,
        ),
        ifAbsent: () => ReportLine(
          label: label,
          quantity: purchase.quantity,
          total: total,
        ),
      );
    }

    final expenseTotals = <String, ReportLine>{};
    final expenseCategoryByEntryId =
      _buildExpenseCategoryLookup(accounts, journalLines);
    for (final entry in expensesInRange) {
      final label = expenseCategoryByEntryId[entry.id] ?? 'Expenses';
      expenseTotals.update(
        label,
        (line) => line.copyWith(
          quantity: line.quantity + 1,
          total: line.total + entry.total,
        ),
        ifAbsent: () => ReportLine(
          label: label,
          quantity: 1,
          total: entry.total,
        ),
      );
    }

    final purchaseLines = purchaseTotals.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final expenseLines = expenseTotals.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final purchasesTotal = purchasesInRange.fold<double>(
      0,
      (sum, entry) => sum + (entry.quantity * entry.unitCost),
    );
    final expensesTotal = expensesInRange.fold<double>(
      0,
      (sum, entry) => sum + entry.total,
    );
    final salesTotal = salesInRange.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final netOutflow = purchasesTotal + expensesTotal;
    final profit = salesTotal - netOutflow;

    final dailyReports = _buildDailyReports(
      start: start,
      end: end,
      purchases: purchasesInRange,
      expenses: expensesInRange,
      sales: salesInRange,
      salesEntryItems: salesEntryItems,
      itemNames: itemNames,
      expenseCategoryByEntryId: expenseCategoryByEntryId,
    );

    return ReportData(
      start: start,
      end: end,
      purchaseLines: purchaseLines,
      expenseLines: expenseLines,
      salesCount: salesInRange.length,
      purchaseCount: purchasesInRange.length,
      expenseCount: expensesInRange.length,
      salesTotal: salesTotal,
      purchasesTotal: purchasesTotal,
      expensesTotal: expensesTotal,
      netOutflow: netOutflow,
      profit: profit,
      dailyReports: dailyReports,
      inventoryValue: inventoryValue,
      lowStockCount: lowStockCount,
      expiringSoonCount: expiringSoonCount,
    );
  }

  /// Build a single-day report for [date]. If [date] is null, defaults to today.
  DailyReport buildDailyReport({
    DateTime? date,
    required List<PurchaseEntry> purchases,
    required List<InventoryItem> items,
    required List<JournalEntry> expenses,
    required List<JournalLine> journalLines,
    required List<Account> accounts,
    required List<SalesEntry> sales,
    required List<SalesEntryItem> salesEntryItems,
    double inventoryValue = 0,
    int lowStockCount = 0,
    int expiringSoonCount = 0,
  }) {
    final selected = date ?? DateTime.now();
    final start = DateTime(selected.year, selected.month, selected.day);
    final end = start;

    final data = buildReport(
      start: start,
      end: end,
      purchases: purchases,
      items: items,
      expenses: expenses,
      journalLines: journalLines,
      accounts: accounts,
      sales: sales,
      salesEntryItems: salesEntryItems,
      inventoryValue: inventoryValue,
      lowStockCount: lowStockCount,
      expiringSoonCount: expiringSoonCount,
    );

    final match = data.dailyReports.firstWhere(
      (r) => _normalizeDate(r.date) == _normalizeDate(start),
      orElse: () => DailyReport(
        date: start,
        salesTotal: 0,
        salesQuantity: 0,
        expensesTotal: 0,
        purchasesTotal: 0,
        profit: 0,
        salesLines: const [],
        expenseLines: const [],
      ),
    );
    return match;
  }

  List<DailyReport> _buildDailyReports({
    required DateTime start,
    required DateTime end,
    required List<PurchaseEntry> purchases,
    required List<JournalEntry> expenses,
    required List<SalesEntry> sales,
    required List<SalesEntryItem> salesEntryItems,
    required Map<int, String> itemNames,
    required Map<int, String> expenseCategoryByEntryId,
  }) {
    final daily = <DateTime, _DailyAccumulator>{};

    for (final entry in sales) {
      final date = _normalizeDate(entry.entryDate);
      final accumulator = daily.putIfAbsent(
        date,
        () => _DailyAccumulator(date: date),
      );
      accumulator.salesTotal += entry.amount;
      final saleItems =
          salesEntryItems.where((item) => item.salesId == entry.id);
      for (final saleItem in saleItems) {
        accumulator.salesQuantity += saleItem.quantity;
        final label =
            itemNames[saleItem.itemId] ?? 'Item #${saleItem.itemId}';
        accumulator.salesLines.update(
          label,
          (line) => line.copyWith(
            quantity: line.quantity + saleItem.quantity,
            total: line.total + saleItem.subtotal,
          ),
          ifAbsent: () => ReportLine(
            label: label,
            quantity: saleItem.quantity,
            total: saleItem.subtotal,
          ),
        );
      }
    }

    for (final entry in expenses) {
      final date = _normalizeDate(entry.date);
      final accumulator = daily.putIfAbsent(
        date,
        () => _DailyAccumulator(date: date),
      );
      accumulator.expensesTotal += entry.total;
      final label = expenseCategoryByEntryId[entry.id] ?? 'Expenses';
      accumulator.expenseLines.update(
        label,
        (line) => line.copyWith(
          quantity: line.quantity + 1,
          total: line.total + entry.total,
        ),
        ifAbsent: () => ReportLine(
          label: label,
          quantity: 1,
          total: entry.total,
        ),
      );
    }

    for (final entry in purchases) {
      final date = _normalizeDate(entry.purchasedAt);
      final accumulator = daily.putIfAbsent(
        date,
        () => _DailyAccumulator(date: date),
      );
      accumulator.purchasesTotal += entry.quantity * entry.unitCost;
    }

    final reports = daily.values
        .map((accumulator) => accumulator.toReport())
        .where((report) => _isWithin(report.date, start, end))
        .toList();

    reports.sort((a, b) => b.date.compareTo(a.date));
    return reports;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isWithin(DateTime date, DateTime start, DateTime end) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(start) && !normalized.isAfter(end);
  }

  Map<int, String> _buildExpenseCategoryLookup(
    List<Account> accounts,
    List<JournalLine> journalLines,
  ) {
    final accountsById = {
      for (final account in accounts) account.id: account,
    };
    final lookup = <int, String>{};
    for (final line in journalLines) {
      if (line.debit <= 0) {
        continue;
      }
      final account = accountsById[line.accountId];
      if (account == null || account.type != 'expense') {
        continue;
      }
      lookup[line.entryId] = account.name;
    }
    return lookup;
  }
}

class ReportData {
  const ReportData({
    required this.start,
    required this.end,
    required this.purchaseLines,
    required this.expenseLines,
    required this.salesCount,
    required this.purchaseCount,
    required this.expenseCount,
    required this.salesTotal,
    required this.purchasesTotal,
    required this.expensesTotal,
    required this.netOutflow,
    required this.profit,
    required this.dailyReports,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.expiringSoonCount,
  });

  final DateTime start;
  final DateTime end;
  final List<ReportLine> purchaseLines;
  final List<ReportLine> expenseLines;
  final int salesCount;
  final int purchaseCount;
  final int expenseCount;
  final double salesTotal;
  final double purchasesTotal;
  final double expensesTotal;
  final double netOutflow;
  final double profit;
  final List<DailyReport> dailyReports;
  final double inventoryValue;
  final int lowStockCount;
  final int expiringSoonCount;
}

class DailyReport {
  const DailyReport({
    required this.date,
    required this.salesTotal,
    required this.salesQuantity,
    required this.expensesTotal,
    required this.purchasesTotal,
    required this.profit,
    required this.salesLines,
    required this.expenseLines,
  });

  final DateTime date;
  final double salesTotal;
  final int salesQuantity;
  final double expensesTotal;
  final double purchasesTotal;
  final double profit;
  final List<ReportLine> salesLines;
  final List<ReportLine> expenseLines;
}

class _DailyAccumulator {
  _DailyAccumulator({required this.date});

  final DateTime date;
  double salesTotal = 0;
  int salesQuantity = 0;
  double expensesTotal = 0;
  double purchasesTotal = 0;
  final Map<String, ReportLine> salesLines = {};
  final Map<String, ReportLine> expenseLines = {};

  DailyReport toReport() {
    final profit = salesTotal - expensesTotal - purchasesTotal;
    final sales = salesLines.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final expenses = expenseLines.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return DailyReport(
      date: date,
      salesTotal: salesTotal,
      salesQuantity: salesQuantity,
      expensesTotal: expensesTotal,
      purchasesTotal: purchasesTotal,
      profit: profit,
      salesLines: sales,
      expenseLines: expenses,
    );
  }
}

class ReportLine {
  const ReportLine({
    required this.label,
    required this.quantity,
    required this.total,
  });

  final String label;
  final int quantity;
  final double total;

  ReportLine copyWith({
    String? label,
    int? quantity,
    double? total,
  }) {
    return ReportLine(
      label: label ?? this.label,
      quantity: quantity ?? this.quantity,
      total: total ?? this.total,
    );
  }
}
