import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../controllers/sales_controller.dart';
import '../models/inventory_item.dart';
import '../models/sales_entry.dart';
import '../models/sales_entry_item.dart';
import 'sales_entry_detail_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({
    super.key,
    required this.controller,
    required this.inventoryController,
  });

  final SalesController controller;
  final InventoryController inventoryController;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  SalesController get _controller => widget.controller;
  InventoryController get _inventoryController =>
      widget.inventoryController;
  DateTime? _startDate;
  DateTime? _endDate;

  SalesEntryItem? _firstLineItem(SalesEntry entry) {
    return _controller.salesEntryItems
        .where((item) => item.salesId == entry.id)
        .firstOrNull;
  }

  Future<void> _showSaleDialog({SalesEntry? existing}) async {
    final items = _inventoryController.allItems;
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add inventory items before recording sales.'),
        ),
      );
      return;
    }

    final existingLineItem =
        existing == null ? null : _firstLineItem(existing);
    int selectedItemId = existingLineItem?.itemId ?? items.first.id;
    final quantityController = TextEditingController(
      text: existingLineItem?.quantity.toString() ?? '',
    );
    final memoController = TextEditingController(text: existing?.memo ?? '');
    DateTime entryDate = existing?.entryDate ?? DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add sale'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedItemId,
                      decoration: const InputDecoration(
                        labelText: 'Item',
                      ),
                      items: items
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedItemId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _StockHint(
                      item: _inventoryController.getItemById(selectedItemId),
                      existingLineItem: existingLineItem,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity sold',
                      ),
                      keyboardType: TextInputType.number,
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
                            if (picked == null) return;
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

    if (result != true) return;

    final quantity = int.tryParse(quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity.'),
        ),
      );
      return;
    }

    final selectedItem = _inventoryController.getItemById(selectedItemId);
    if (selectedItem == null) return;
    final available = selectedItem.quantity +
        (existingLineItem != null && existingLineItem.itemId == selectedItemId
            ? existingLineItem.quantity
            : 0);
    if (quantity > available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $available units available.'),
        ),
      );
      return;
    }

    try {
      if (existing == null) {
        await _controller.addSale(
          itemId: selectedItemId,
          quantity: quantity,
          memo: memoController.text.trim(),
          entryDate: entryDate,
        );
      } else {
        await _controller.updateSale(
          id: existing.id,
          itemId: selectedItemId,
          quantity: quantity,
          memo: memoController.text.trim(),
          entryDate: entryDate,
        );
      }
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
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
    if (range == null) return;
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
      animation: Listenable.merge([
        _controller,
        _inventoryController,
      ]),
      builder: (context, _) {
        final sales = _controller.salesEntries
            .where((entry) => _isWithinRange(entry.entryDate))
            .toList();
        final total = sales.fold<double>(
          0,
          (sum, entry) => sum + _controller.totalForSale(entry.id),
        );
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showSaleDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add sale'),
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
                              title: 'Sales',
                              value: '${sales.length}',
                              caption: 'Entries',
                              icon: Icons.point_of_sale_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              title: 'Total',
                              value: total.toStringAsFixed(2),
                              caption: 'This period',
                              icon: Icons.trending_up,
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
                    if (sales.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('No sales yet. Tap "Add sale".'),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: sales.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = sales[index];
                            final entryTotal =
                                _controller.totalForSale(entry.id);
                            final memo = entry.memo.isEmpty
                                ? 'Sale'
                                : entry.memo;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: const Icon(Icons.point_of_sale_outlined),
                              ),
                              title: Text(
                                _formatDate(entry.entryDate),
                              ),
                              subtitle: Text(
                                '\$${entryTotal.toStringAsFixed(2)} · $memo',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SalesEntryDetailScreen(
                                      sale: entry,
                                      controller: _controller,
                                      inventoryController:
                                          _inventoryController,
                                    ),
                                  ),
                                );
                              },
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

class _StockHint extends StatelessWidget {
  const _StockHint({
    required this.item,
    required this.existingLineItem,
  });

  final InventoryItem? item;
  final SalesEntryItem? existingLineItem;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const SizedBox.shrink();
    }
    final available = item!.quantity +
        (existingLineItem != null && existingLineItem!.itemId == item!.id
            ? existingLineItem!.quantity
            : 0);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Available: $available',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          'Selling price: ${item!.sellingPrice.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
