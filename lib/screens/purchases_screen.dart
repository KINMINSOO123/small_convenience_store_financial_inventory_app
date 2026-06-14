import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../controllers/purchase_controller.dart';
import 'purchase_entry_detail_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({
    super.key,
    required this.controller,
    required this.inventoryController,
  });

  final PurchaseController controller;
  final InventoryController inventoryController;

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  PurchaseController get _controller => widget.controller;
  InventoryController get _inventoryController => widget.inventoryController;
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _showAddDialog() async {
    final quantityController = TextEditingController();
    final costController = TextEditingController();
    final sellingPriceController = TextEditingController();
    final itemNameController = TextEditingController();
    final categoryController = TextEditingController();
    final thresholdController = TextEditingController(
      text: _inventoryController.lowStockThreshold.toString(),
    );
    DateTime? expiryDate;
    DateTime purchaseDate = DateTime.now();
    String? selectedCategory =
        _inventoryController.categories.isEmpty
            ? null
            : _inventoryController.categories.first;
    int? selectedItemId;
    bool createNewCategory = _inventoryController.categories.isEmpty;
    bool createNewItem =
        createNewCategory ||
        selectedCategory == null ||
        _inventoryController.itemsForCategory(selectedCategory).isEmpty;
    if (!createNewItem && selectedItemId == null) {
      final categoryItems =
          _inventoryController.itemsForCategory(selectedCategory!);
      if (categoryItems.isNotEmpty) {
        selectedItemId = categoryItems.first.id;
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add purchase'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_inventoryController.categories.isEmpty)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Create new category'),
                        value: createNewCategory,
                        onChanged: (value) {
                          setDialogState(() {
                            createNewCategory = value;
                            if (value) {
                              createNewItem = true;
                              selectedCategory = null;
                              selectedItemId = null;
                            } else if (_inventoryController.categories.isNotEmpty) {
                              selectedCategory =
                                  _inventoryController.categories.first;
                              final categoryItems = _inventoryController
                                  .itemsForCategory(selectedCategory!);
                              createNewItem = categoryItems.isEmpty;
                              selectedItemId = categoryItems.isEmpty
                                  ? null
                                  : categoryItems.first.id;
                            }
                          });
                        },
                      ),
                    if (createNewCategory)
                      TextField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: 'New category name',
                        ),
                        textInputAction: TextInputAction.next,
                      )
                    else if (_inventoryController.categories.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: _inventoryController.categories
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedCategory = value;
                            final categoryItems = _inventoryController
                                .itemsForCategory(value);
                            createNewItem = categoryItems.isEmpty;
                            selectedItemId = categoryItems.isEmpty
                                ? null
                                : categoryItems.first.id;
                          });
                        },
                      ),
                    if (!createNewCategory)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Create new item'),
                        value: createNewItem,
                        onChanged: (value) {
                          final category = selectedCategory;
                          final hasItems =
                              category != null &&
                              _inventoryController
                                  .itemsForCategory(category)
                                  .isNotEmpty;
                          if (!hasItems) return;
                          setDialogState(() {
                            createNewItem = value;
                            if (!value) {
                              selectedItemId = _inventoryController
                                  .itemsForCategory(category!)
                                  .first
                                  .id;
                            }
                          });
                        },
                      ),
                    if (!createNewItem && selectedCategory != null)
                      DropdownButtonFormField<int?>(
                        value: selectedItemId,
                        decoration: const InputDecoration(labelText: 'Item'),
                        items: _inventoryController
                            .itemsForCategory(selectedCategory!)
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedItemId = value;
                          });
                        },
                      ),
                    if (createNewItem) ...[
                      if (!createNewCategory && selectedCategory != null)
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          child: Text(selectedCategory!),
                        ),
                      if (!createNewCategory && selectedCategory != null)
                        const SizedBox(height: 12),
                      TextField(
                        controller: itemNameController,
                        decoration: const InputDecoration(
                          labelText: 'New item name',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: sellingPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Selling price',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: thresholdController,
                        decoration: const InputDecoration(
                          labelText: 'Low stock threshold',
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity purchased',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costController,
                      decoration: const InputDecoration(labelText: 'Unit cost'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expiryDate == null
                                ? 'No expiry date'
                                : 'Expiry: ${_formatDate(expiryDate!)}',
                          ),
                        ),
                        if (expiryDate != null)
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                expiryDate = null;
                              });
                            },
                            child: const Text('Clear'),
                          ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expiryDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              expiryDate = picked;
                            });
                          },
                          child: const Text('Pick date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Purchased: ${_formatDate(purchaseDate)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: purchaseDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              purchaseDate = picked;
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
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final quantity = int.tryParse(quantityController.text.trim());
    final unitCost = double.tryParse(costController.text.trim());

    if (quantity == null || unitCost == null || quantity <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity and cost.'),
        ),
      );
      return;
    }

    if (createNewItem) {
      final name = itemNameController.text.trim();
      final category = createNewCategory
          ? categoryController.text.trim()
          : (selectedCategory ?? '');
      final lowStockThreshold = int.tryParse(thresholdController.text.trim());
      final sellingPrice = double.tryParse(
        sellingPriceController.text.trim(),
      );
      if (name.isEmpty ||
          category.isEmpty ||
          sellingPrice == null ||
          lowStockThreshold == null ||
          lowStockThreshold <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid item details.')),
        );
        return;
      }
      try {
        final newItem = await _inventoryController.addItem(
          name: name,
          category: category,
          sellingPrice: sellingPrice,
          lowStockThreshold: lowStockThreshold,
        );
        await _controller.addPurchase(
          itemId: newItem.id,
          quantity: quantity,
          unitCost: unitCost,
          purchaseDate: purchaseDate,
          expiryDate: expiryDate,
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to add purchase: $error')),
        );
      }
      return;
    }

    final fallbackCategory = selectedCategory;
    final fallbackItems = fallbackCategory == null
        ? null
        : _inventoryController.itemsForCategory(fallbackCategory);
    final itemId =
        selectedItemId ??
        (fallbackItems == null || fallbackItems.isEmpty
            ? null
            : fallbackItems.first.id);
    if (itemId == null) return;

    try {
      await _controller.addPurchase(
        itemId: itemId,
        quantity: quantity,
        unitCost: unitCost,
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
      );
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
    final endNormalized = end == null
        ? null
        : DateTime(end.year, end.month, end.day);
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
      animation: _controller,
      builder: (context, _) {
        final purchases = _controller.purchases
            .where((entry) => _isWithinRange(entry.purchaseDate))
            .toList();
        final totalCost = purchases.fold<double>(
          0,
          (sum, entry) => sum + _controller.totalForPurchase(entry.id),
        );
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add purchase'),
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
                              title: 'Purchases',
                              value: '${purchases.length}',
                              caption: 'Entries',
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              title: 'Total Cost',
                              value: totalCost.toStringAsFixed(2),
                              caption: 'All purchases',
                              icon: Icons.payments_outlined,
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
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<PurchaseFilter>(
                              value: _controller.purchaseFilter,
                              decoration: const InputDecoration(
                                labelText: 'Filter purchases',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: PurchaseFilter.all,
                                  child: Text('All'),
                                ),
                                DropdownMenuItem(
                                  value: PurchaseFilter.active,
                                  child: Text('Active'),
                                ),
                                DropdownMenuItem(
                                  value: PurchaseFilter.cancelled,
                                  child: Text('Cancelled'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                _controller.setPurchaseFilter(value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (purchases.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('No purchases yet. Tap "Add purchase".'),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: purchases.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final purchase = purchases[index];
                            final total =
                                _controller.totalForPurchase(purchase.id);
                            final statusLabel = purchase.isCancelled
                                ? 'Cancelled'
                                : 'Active';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                child: const Icon(Icons.receipt_long_outlined),
                              ),
                              title: Text(
                                _formatDate(purchase.purchaseDate),
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    '\$${total.toStringAsFixed(2)}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: purchase.isCancelled
                                          ? Theme.of(context)
                                              .colorScheme
                                              .errorContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: purchase.isCancelled
                                                ? Theme.of(context).colorScheme
                                                    .onErrorContainer
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PurchaseEntryDetailScreen(
                                      purchase: purchase,
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
                  Text(title, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(caption, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
