import 'package:flutter/material.dart';

import '../controllers/expenses_controller.dart';
import '../models/account.dart';
import '../models/journal_entry.dart';
import '../models/journal_line.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.controller});

  final ExpensesController controller;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  ExpensesController get _controller => widget.controller;
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _showExpenseDialog({JournalEntry? existing}) async {
    final amountController = TextEditingController(
      text: existing == null ? '' : existing.total.toStringAsFixed(2),
    );
    final memoController = TextEditingController(text: existing?.memo ?? '');
    final categoryController = TextEditingController(
      text: existing == null
          ? ''
          : _expenseAccountForEntry(existing)?.name ?? '',
    );
    DateTime entryDate = existing?.date ?? DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add expense' : 'Edit expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Expense category',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: memoController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Date: ${_formatDate(entryDate)}'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: entryDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked == null) {
                              return;
                            }
                            setDialogState(() {
                              entryDate = picked;
                            });
                          },
                          child: const Text('Pick date'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount.'),
        ),
      );
      return;
    }

    final categoryName = categoryController.text.trim();
    if (categoryName.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an expense category.'),
        ),
      );
      return;
    }

    final account = await _controller.addAccount(categoryName);
    if (existing == null) {
      await _controller.addExpense(
        expenseAccountId: account.id,
        amount: amount,
        memo: memoController.text.trim(),
        entryDate: entryDate,
      );
      return;
    }

    await _controller.updateExpense(
      entryId: existing.id,
      expenseAccountId: account.id,
      amount: amount,
      memo: memoController.text.trim(),
      entryDate: entryDate,
    );
  }

  Account? _expenseAccountForEntry(JournalEntry entry) {
    final entryLines = _controller.journalLines
        .where((line) => line.entryId == entry.id)
        .toList();
    final expenseLine = entryLines.firstWhere(
      (line) => line.debit > 0,
      orElse: () => JournalLine(
        id: 0,
        entryId: entry.id,
        accountId: 0,
        debit: 0,
        credit: 0,
      ),
    );
    if (expenseLine.accountId == 0) {
      return _controller.defaultExpenseAccount;
    }
    final account = _controller.accounts
        .where((account) => account.id == expenseLine.accountId)
        .toList();
    return account.isEmpty ? _controller.defaultExpenseAccount : account.first;
  }

  Future<bool?> _confirmDeleteExpense(String label) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete expense'),
          content: Text('Delete expense "$label"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
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

  bool _isWithinRange(DateTime date) {
    final start = _startDate;
    final end = _endDate;
    if (start == null && end == null) {
      return true;
    }
    final normalized = DateTime(date.year, date.month, date.day);
    final startNormalized = start == null
        ? null
        : DateTime(start.year, start.month, start.day);
    final endNormalized =
        end == null ? null : DateTime(end.year, end.month, end.day);
    if (startNormalized != null && normalized.isBefore(startNormalized)) {
      return false;
    }
    if (endNormalized != null && normalized.isAfter(endNormalized)) {
      return false;
    }
    return true;
  }

  String _dateLabel(DateTime? date, String fallback) {
    return date == null ? fallback : _formatDate(date);
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (range == null) {
      return;
    }
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final expenses = _controller.expenseEntries
            .where((entry) => _isWithinRange(entry.date))
            .toList();
        final total = expenses.fold<double>(
          0,
          (sum, entry) => sum + entry.total,
        );
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showExpenseDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              title: 'Expenses',
                              value: '${expenses.length}',
                              caption: 'Entries',
                              icon: Icons.receipt_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              title: 'Total',
                              value: total.toStringAsFixed(2),
                              caption: 'This period',
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _pickDateRange,
                              child: Text(
                                'Range ${_dateLabel(_startDate, 'Any')} - '
                                '${_dateLabel(_endDate, 'Any')}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _clearDateFilter,
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear date filter',
                          ),
                        ],
                      ),
                    ),
                    if (expenses.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('No expenses yet. Tap "Add expense".'),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: expenses.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = expenses[index];
                            final memo = entry.memo.isEmpty
                                ? 'Expense'
                                : entry.memo;
                            final category =
                              _expenseAccountForEntry(entry)?.name ??
                              'Expense';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: const Icon(Icons.payments_outlined),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(category)),
                                  Text(
                                    entry.total.toStringAsFixed(2),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${_formatDate(entry.date)} · $memo',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _showExpenseDialog(existing: entry);
                                  }
                                  if (value == 'delete') {
                                    final confirmed =
                                        await _confirmDeleteExpense(memo);
                                    if (confirmed == true) {
                                      await _controller.deleteExpense(entry.id);
                                    }
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Icon(Icons.more_vert),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
        );
      },
    );
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
