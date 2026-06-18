import '../models/account.dart';
import '../models/inventory_item.dart';
import '../models/journal_entry.dart';
import '../models/journal_line.dart';
import '../models/purchase_entry.dart';
import '../models/purchase_entry_item.dart';
import '../models/sales_entry.dart';
import '../models/sales_entry_item.dart';
import '../models/stock_batch.dart';
import '../models/supplier_return.dart';
import '../models/supplier_return_item.dart';

class ReportingService {
  ReportData buildReport({
    required DateTime start,
    required DateTime end,
    required List<PurchaseEntry> purchases,
    required List<PurchaseEntryItem> purchaseEntryItems,
    required List<InventoryItem> items,
    required List<JournalEntry> expenses,
    required List<JournalLine> journalLines,
    required List<Account> accounts,
    required List<SalesEntry> sales,
    required List<SalesEntryItem> salesEntryItems,
    required double inventoryValue,
    required List<StockBatch> batches,
    required List<InventoryItem> lowStockItems,
    List<SupplierReturn> supplierReturns = const [],
    List<SupplierReturnItem> supplierReturnItems = const [],
  }) {
    final purchasesInRange = purchases
        .where((purchase) => !purchase.isCancelled && !purchase.isDraft)
        .where((purchase) => _isWithin(purchase.purchaseDate, start, end))
        .toList();

    final expensesInRange = expenses
        .where((entry) => _isWithin(entry.date, start, end))
        .toList();

    final salesInRange = sales
        .where((entry) => !entry.isDraft && !entry.isVoid)
        .where((entry) => _isWithin(entry.salesDate, start, end))
        .toList();

    final purchaseIdsInRange = purchasesInRange.map((p) => p.id).toSet();

    final itemNames = {
      for (final item in items) item.id: item.name,
    };

    final salesTotals = <String, ReportLine>{};
    for (final sale in salesInRange) {
      final saleItems = salesEntryItems.where((i) => i.salesId == sale.id);
      for (final lineItem in saleItems) {
        final label =
            itemNames[lineItem.itemId] ?? 'Item #${lineItem.itemId}';
        salesTotals.update(
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

    final purchaseTotals = <String, ReportLine>{};
    final purchaseItemLabel = <int, String>{};
    for (final purchase in purchasesInRange) {
      final itemsForPurchase =
          purchaseEntryItems.where((i) => i.purchaseId == purchase.id);
      for (final lineItem in itemsForPurchase) {
        final label =
            itemNames[lineItem.itemId] ?? 'Item #${lineItem.itemId}';
        purchaseItemLabel[lineItem.id] = label;
        final total = lineItem.quantity * lineItem.unitCost;
        purchaseTotals.update(
          label,
          (line) => line.copyWith(
            quantity: line.quantity + lineItem.quantity,
            total: line.total + total,
          ),
          ifAbsent: () => ReportLine(
            label: label,
            quantity: lineItem.quantity,
            total: total,
          ),
        );
      }
    }

    // Subtract supplier returns from purchase totals
    final returnIdsInRange = supplierReturns
        .where((r) => purchaseIdsInRange.contains(r.purchaseId))
        .map((r) => r.id)
        .toSet();
    for (final returnItem
        in supplierReturnItems.where((i) => returnIdsInRange.contains(i.returnId))) {
      final label =
          purchaseItemLabel[returnItem.purchaseItemId] ?? 'Unknown';
      final returnTotal = returnItem.quantity * returnItem.unitCost;
      purchaseTotals.update(
        label,
        (line) => line.copyWith(
          quantity: line.quantity - returnItem.quantity,
          total: line.total - returnTotal,
        ),
        ifAbsent: () => ReportLine(
          label: label,
          quantity: -returnItem.quantity,
          total: -returnTotal,
        ),
      );
    }
    purchaseTotals.removeWhere((_, line) => line.quantity <= 0);

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

    final salesLines = salesTotals.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final purchaseLines = purchaseTotals.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final expenseLines = expenseTotals.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final purchasesTotal = purchaseEntryItems
        .where((item) => purchaseIdsInRange.contains(item.purchaseId))
        .fold<double>(0, (sum, item) => sum + (item.quantity * item.unitCost))
        - supplierReturnItems
            .where((i) => returnIdsInRange.contains(i.returnId))
            .fold<double>(0, (sum, i) => sum + i.subtotal);
    final expensesTotal = expensesInRange.fold<double>(
      0,
      (sum, entry) => sum + entry.total,
    );
    final salesTotal = salesInRange.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );

    final grossProfit = salesTotal - purchasesTotal;
    final grossMargin = salesTotal > 0 ? (grossProfit / salesTotal * 100) : 0.0;
    final totalCashIn = salesTotal;
    final totalCashOut = purchasesTotal + expensesTotal;
    final netCashFlow = totalCashIn - totalCashOut;

    final netOutflow = totalCashOut;
    final profit = netCashFlow;

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

    final lowStockCount = lowStockItems.length;
    final expiringSoonCount = expiringAlerts
        .map((e) => e.itemName)
        .toSet()
        .length;

    final dailyReports = _buildDailyReports(
      start: start,
      end: end,
      purchases: purchasesInRange,
      purchaseEntryItems: purchaseEntryItems,
      expenses: expensesInRange,
      sales: salesInRange,
      salesEntryItems: salesEntryItems,
      itemNames: itemNames,
      expenseCategoryByEntryId: expenseCategoryByEntryId,
      supplierReturns: supplierReturns,
      supplierReturnItems: supplierReturnItems,
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
      salesLines: salesLines,
      grossProfit: grossProfit,
      grossMargin: grossMargin,
      totalCashIn: totalCashIn,
      totalCashOut: totalCashOut,
      netCashFlow: netCashFlow,
      lowStockItems: lowStockItems,
      expiringAlerts: expiringAlerts,
    );
  }

  DailyReport buildDailyReport({
    DateTime? date,
    required List<PurchaseEntry> purchases,
    required List<PurchaseEntryItem> purchaseEntryItems,
    required List<InventoryItem> items,
    required List<JournalEntry> expenses,
    required List<JournalLine> journalLines,
    required List<Account> accounts,
    required List<SalesEntry> sales,
    required List<SalesEntryItem> salesEntryItems,
    double inventoryValue = 0,
    List<StockBatch> batches = const [],
    List<InventoryItem> lowStockItems = const [],
    List<SupplierReturn> supplierReturns = const [],
    List<SupplierReturnItem> supplierReturnItems = const [],
  }) {
    final selected = date ?? DateTime.now();
    final start = DateTime(selected.year, selected.month, selected.day);
    final end = start;

    final data = buildReport(
      start: start,
      end: end,
      purchases: purchases,
      purchaseEntryItems: purchaseEntryItems,
      items: items,
      expenses: expenses,
      journalLines: journalLines,
      accounts: accounts,
      sales: sales,
      salesEntryItems: salesEntryItems,
      inventoryValue: inventoryValue,
      batches: batches,
      lowStockItems: lowStockItems,
      supplierReturns: supplierReturns,
      supplierReturnItems: supplierReturnItems,
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

  DailyReportData buildDailyReportData({
    required DateTime date,
    required List<SalesEntry> sales,
    required List<SalesEntryItem> salesEntryItems,
    required List<JournalEntry> expenses,
    required List<JournalLine> journalLines,
    required List<Account> accounts,
    required List<InventoryItem> items,
    required List<StockBatch> batches,
    List<SupplierReturn> supplierReturns = const [],
    List<SupplierReturnItem> supplierReturnItems = const [],
  }) {
    final normalized = _normalizeDate(date);
    final itemNames = {for (final item in items) item.id: item.name};

    final activeSales = sales
        .where((s) =>
            !s.isDraft &&
            !s.isVoid &&
            _normalizeDate(s.salesDate) == normalized)
        .toList();

    double salesRevenue = 0;
    double costOfGoodsSold = 0;
    final itemSales = <String, ReportLine>{};

    for (final sale in activeSales) {
      salesRevenue += sale.amount;
      final saleItems = salesEntryItems.where((i) => i.salesId == sale.id);
      for (final lineItem in saleItems) {
        costOfGoodsSold += lineItem.costOfGoodsSold;
        final label =
            itemNames[lineItem.itemId] ?? 'Item #${lineItem.itemId}';
        itemSales.update(
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

    final todayReturnIds = supplierReturns
        .where((r) => _normalizeDate(r.returnDate) == normalized)
        .map((r) => r.id)
        .toSet();
    final supplierReturnTotal = supplierReturnItems
        .where((i) => todayReturnIds.contains(i.returnId))
        .fold<double>(0, (sum, i) => sum + i.subtotal);

    final grossProfit = salesRevenue - costOfGoodsSold - supplierReturnTotal;

    final todayExpenses = expenses
        .where((e) => _normalizeDate(e.date) == normalized)
        .toList();
    final expensesTotal = todayExpenses.fold<double>(0, (s, e) => s + e.total);
    final netProfit = grossProfit - expensesTotal;

    final expenseCategoryByEntryId =
        _buildExpenseCategoryLookup(accounts, journalLines);
    final expenseLines = <String, ReportLine>{};
    for (final entry in todayExpenses) {
      final label = expenseCategoryByEntryId[entry.id] ?? 'Expenses';
      expenseLines.update(
        label,
        (line) => line.copyWith(
          quantity: line.quantity + 1,
          total: line.total + entry.total,
        ),
        ifAbsent: () =>
            ReportLine(label: label, quantity: 1, total: entry.total),
      );
    }

    final salesLines = itemSales.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final topSellingItems = itemSales.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    final top5 = topSellingItems.take(5).toList();

    final sortedExpenseLines = expenseLines.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final lowStockItems = items.where((item) => item.isLowStock).toList();
    final now = DateTime.now();
    final expiringSoonItems = <InventoryItem>[];
    for (final item in items) {
      final hasExpiringBatch = batches.any(
        (b) =>
            b.itemId == item.id &&
            b.remainingQuantity > 0 &&
            b.expiryDate != null &&
            b.expiryDate!.isAfter(now) &&
            b.expiryDate!.isBefore(now.add(const Duration(days: 30))),
      );
      if (hasExpiringBatch) {
        expiringSoonItems.add(item);
      }
    }

    return DailyReportData(
      date: normalized,
      salesRevenue: salesRevenue,
      costOfGoodsSold: costOfGoodsSold,
      supplierReturnTotal: supplierReturnTotal,
      grossProfit: grossProfit,
      expensesTotal: expensesTotal,
      netProfit: netProfit,
      transactionCount: activeSales.length,
      salesLines: salesLines,
      expenseLines: sortedExpenseLines,
      topSellingItems: top5,
      lowStockItems: lowStockItems,
      expiringSoonItems: expiringSoonItems,
    );
  }

  List<DailyReport> _buildDailyReports({
    required DateTime start,
    required DateTime end,
    required List<PurchaseEntry> purchases,
    required List<PurchaseEntryItem> purchaseEntryItems,
    required List<JournalEntry> expenses,
    required List<SalesEntry> sales,
    required List<SalesEntryItem> salesEntryItems,
    required Map<int, String> itemNames,
    required Map<int, String> expenseCategoryByEntryId,
    List<SupplierReturn> supplierReturns = const [],
    List<SupplierReturnItem> supplierReturnItems = const [],
  }) {
    final purchaseIdToDate = {
      for (final p in purchases) p.id: p.purchaseDate,
    };
    final daily = <DateTime, _DailyAccumulator>{};

    for (final entry in sales) {
      final date = _normalizeDate(entry.salesDate);
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

    for (final item in purchaseEntryItems) {
      final purchaseDate = purchaseIdToDate[item.purchaseId];
      if (purchaseDate == null) continue;
      final date = _normalizeDate(purchaseDate);
      final accumulator = daily.putIfAbsent(
        date,
        () => _DailyAccumulator(date: date),
      );
      accumulator.purchasesTotal += item.quantity * item.unitCost;
    }

    // Subtract returns from daily purchase totals
    final purchaseItemToDate = <int, DateTime>{};
    for (final item in purchaseEntryItems) {
      final purchaseDate = purchaseIdToDate[item.purchaseId];
      if (purchaseDate != null) {
        purchaseItemToDate[item.id] = _normalizeDate(purchaseDate);
      }
    }
    for (final returnItem in supplierReturnItems) {
      final date = purchaseItemToDate[returnItem.purchaseItemId];
      if (date == null) continue;
      final accumulator = daily[date];
      if (accumulator == null) continue;
      accumulator.purchasesTotal -= returnItem.quantity * returnItem.unitCost;
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
    @Deprecated('Use netCashFlow instead') required this.netOutflow,
    required this.profit,
    required this.dailyReports,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.expiringSoonCount,
    required this.salesLines,
    required this.grossProfit,
    required this.grossMargin,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.netCashFlow,
    required this.lowStockItems,
    required this.expiringAlerts,
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

  @Deprecated('Use netCashFlow instead')
  final double netOutflow;

  final double profit;
  final List<DailyReport> dailyReports;
  final double inventoryValue;
  final int lowStockCount;
  final int expiringSoonCount;

  // NEW FIELDS
  final List<ReportLine> salesLines;
  final double grossProfit;
  final double grossMargin;
  final double totalCashIn;
  final double totalCashOut;
  final double netCashFlow;
  final List<InventoryItem> lowStockItems;
  final List<ExpiryAlert> expiringAlerts;
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

class DailyReportData {
  const DailyReportData({
    required this.date,
    required this.salesRevenue,
    required this.costOfGoodsSold,
    required this.supplierReturnTotal,
    required this.grossProfit,
    required this.expensesTotal,
    required this.netProfit,
    required this.transactionCount,
    required this.salesLines,
    required this.expenseLines,
    required this.topSellingItems,
    required this.lowStockItems,
    required this.expiringSoonItems,
  });

  final DateTime date;
  final double salesRevenue;
  final double costOfGoodsSold;
  final double supplierReturnTotal;
  final double grossProfit;
  final double expensesTotal;
  final double netProfit;
  final int transactionCount;
  final List<ReportLine> salesLines;
  final List<ReportLine> expenseLines;
  final List<ReportLine> topSellingItems;
  final List<InventoryItem> lowStockItems;
  final List<InventoryItem> expiringSoonItems;
}
