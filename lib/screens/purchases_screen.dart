import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../controllers/purchase_controller.dart';
import '../models/purchase_entry.dart';

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

  Future<void> _showPurchaseDialog({PurchaseEntry? existing}) async {
    final quantityController = TextEditingController(
      text: existing?.quantity.toString() ?? '',
    );
    final costController = TextEditingController(
      text: existing == null ? '' : existing.unitCost.toStringAsFixed(2),
    );
    final sellingPriceController = TextEditingController();
    final itemNameController = TextEditingController();
    final categoryController = TextEditingController();
    final thresholdController = TextEditingController(
      text: _inventoryController.lowStockThreshold.toString(),
    );
    DateTime? expiryDate = existing?.expiryDate;
    DateTime purchaseDate = existing?.purchasedAt ?? DateTime.now();
    final existingItem = existing == null
        ? null
        : _inventoryController.getItemById(existing.itemId);
    String? selectedCategory =
        existingItem?.category ??
        (_inventoryController.categories.isEmpty ? null : _inventoryController.categories.first);
    int? selectedItemId = existing?.itemId;
    bool createNewCategory = existing == null && _inventoryController.categories.isEmpty;
    bool createNewItem =
        existing == null &&
        (createNewCategory ||
            selectedCategory == null ||
            _inventoryController.itemsForCategory(selectedCategory).isEmpty);
    final allowNewItem = existing == null;
    if (!createNewItem && selectedCategory != null && selectedItemId == null) {
      final categoryItems = _inventoryController.itemsForCategory(selectedCategory);
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
              title: Text(existing == null ? 'Add purchase' : 'Edit purchase'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (existing?.isCancelled ?? false)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'This purchase is cancelled. Editing is disabled.',
                        ),
                      ),
                    if (existing?.isCancelled ?? false)
                      const SizedBox(height: 12),
                    if (allowNewItem)
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
                              selectedCategory = _inventoryController.categories.first;
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
                    if (createNewCategory && allowNewItem)
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
                        onChanged: allowNewItem
                            ? (value) {
                                if (value == null) {
                                  return;
                                }
                                setDialogState(() {
                                  selectedCategory = value;
                                  final categoryItems = _inventoryController
                                      .itemsForCategory(value);
                                  createNewItem = categoryItems.isEmpty;
                                  selectedItemId = categoryItems.isEmpty
                                      ? null
                                      : categoryItems.first.id;
                                });
                              }
                            : null,
                      ),
                    if (allowNewItem && !createNewCategory)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Create new item'),
                        value: createNewItem,
                        onChanged: (value) {
                          final category = selectedCategory;
                          final hasItems =
                              category != null &&
                              _inventoryController.itemsForCategory(category).isNotEmpty;
                          if (!hasItems) {
                            return;
                          }
                          setDialogState(() {
                            createNewItem = value;
                            if (!value) {
                              selectedItemId = _inventoryController
                                  .itemsForCategory(category)
                                  .first
                                  .id;
                            }
                          });
                        },
                      ),
                    if (!createNewItem && selectedCategory != null)
                      DropdownButtonFormField<int?>(
                        value:
                            selectedItemId ??
                            (_inventoryController
                                    .itemsForCategory(selectedCategory!)
                                    .isEmpty
                                ? null
                                : _inventoryController
                                      .itemsForCategory(selectedCategory!)
                                      .first
                                      .id),
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
                    if (createNewItem && allowNewItem) ...[
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
                            if (picked == null) {
                              return;
                            }
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
                            if (picked == null) {
                              return;
                            }
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
                if (existing != null)
                  TextButton(
                    onPressed: existing.isCancelled
                        ? null
                        : () async {
                            final reason = await _promptCancelReason();
                            if (reason == null) {
                              return;
                            }
                            await _controller.cancelPurchase(
                              existing.id,
                              reason: reason,
                            );
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.of(context).pop(false);
                          },
                    child: const Text('Cancel purchase'),
                  ),
                if (existing != null)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await _confirmDeletePurchase();
                      if (confirmed != true) {
                        return;
                      }
                      await _controller.deletePurchaseHard(existing.id);
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Delete permanently'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: (existing?.isCancelled ?? false)
                      ? null
                      : () => Navigator.of(context).pop(true),
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
    final quantity = int.tryParse(quantityController.text.trim());
    final unitCost = double.tryParse(costController.text.trim());

    if (quantity == null || unitCost == null || quantity <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity and cost.'),
        ),
      );
      return;
    }

    if (createNewItem && allowNewItem) {
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
        if (!mounted) {
          return;
        }
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
          purchasedAt: purchaseDate,
          expiryDate: expiryDate,
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
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
    if (itemId == null) {
      return;
    }
    try {
      if (existing == null) {
        await _controller.addPurchase(
          itemId: itemId,
          quantity: quantity,
          unitCost: unitCost,
          purchasedAt: purchaseDate,
          expiryDate: expiryDate,
        );
      } else if (!existing.isCancelled) {
        await _controller.updatePurchase(
          existing: existing,
          itemId: itemId,
          quantity: quantity,
          unitCost: unitCost,
          purchasedAt: purchaseDate,
          expiryDate: expiryDate,
        );
      }
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<String?> _promptCancelReason() async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel purchase'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
            textInputAction: TextInputAction.done,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Dismiss'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Cancel purchase'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmDeletePurchase() async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete purchase'),
          content: const Text(
            'This permanently deletes the purchase and its stock effect. Continue?',
          ),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final purchases = _controller.purchases;
        final totalCost = purchases.fold<double>(
          0,
          (sum, entry) => sum + (entry.quantity * entry.unitCost),
        );
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showPurchaseDialog(),
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
                    const SizedBox(height: 8),
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
                                if (value == null) {
                                  return;
                                }
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
                            final item = _inventoryController.getItemById(
                              purchase.itemId,
                            );
                            final name = item?.name ?? 'Unknown item';
                            final expiryLabel = purchase.expiryDate == null
                                ? 'No expiry'
                                : 'Exp: ${_formatDate(purchase.expiryDate!)}';
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
                                child: Text(
                                  name.isEmpty ? '?' : name[0].toUpperCase(),
                                ),
                              ),
                              title: Text(name),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _Pill(label: '${purchase.quantity} units'),
                                    _Pill(label: expiryLabel),
                                    _Pill(
                                      label: _formatDate(purchase.purchasedAt),
                                    ),
                                    _Pill(label: statusLabel),
                                    if (purchase.cancelReason != null &&
                                        purchase.cancelReason!.isNotEmpty)
                                      _Pill(
                                        label:
                                            'Reason: ${purchase.cancelReason}',
                                      ),
                                  ],
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(purchase.unitCost.toStringAsFixed(2)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: purchase.isCancelled
                                        ? null
                                        : () async {
                                            final reason =
                                                await _promptCancelReason();
                                            if (reason == null) {
                                              return;
                                            }
                                            await _controller.cancelPurchase(
                                              purchase.id,
                                              reason: reason,
                                            );
                                          },
                                  ),
                                ],
                              ),
                              onTap: () =>
                                  _showPurchaseDialog(existing: purchase),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
