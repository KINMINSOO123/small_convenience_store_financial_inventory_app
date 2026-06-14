import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../controllers/purchase_controller.dart';
import '../models/purchase_entry.dart';

class PurchaseEntryDetailScreen extends StatefulWidget {
  const PurchaseEntryDetailScreen({
    super.key,
    required this.purchase,
    required this.controller,
    required this.inventoryController,
  });

  final PurchaseEntry purchase;
  final PurchaseController controller;
  final InventoryController inventoryController;

  @override
  State<PurchaseEntryDetailScreen> createState() =>
      _PurchaseEntryDetailScreenState();
}

class _PurchaseEntryDetailScreenState
    extends State<PurchaseEntryDetailScreen> {
  PurchaseController get _controller => widget.controller;
  InventoryController get _inventoryController => widget.inventoryController;

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _addItem() async {
    final items = _inventoryController.allItems;
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items available.')),
      );
      return;
    }

    int selectedItemId = items.first.id;
    final quantityController = TextEditingController();
    final costController = TextEditingController();
    DateTime? expiryDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedItemId,
                      decoration: const InputDecoration(labelText: 'Item'),
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

    try {
      await _controller.addLineItemToPurchase(
        purchaseId: widget.purchase.id,
        itemId: selectedItemId,
        quantity: quantity,
        unitCost: unitCost,
        expiryDate: expiryDate,
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _editMemo() async {
    final purchase = _controller.allPurchases
        .firstWhere((p) => p.id == widget.purchase.id);
    final controller = TextEditingController(text: purchase.memo ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit memo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Memo'),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await _controller.updatePurchaseEntryMemo(widget.purchase.id,
        result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Purchase ${_formatDate(widget.purchase.purchaseDate)}'),
        actions: [
          if (!widget.purchase.isCancelled)
            IconButton(
              onPressed: _editMemo,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit memo',
            ),
        ],
      ),
      floatingActionButton: widget.purchase.isCancelled
          ? null
          : FloatingActionButton.extended(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final purchase = _controller.allPurchases
              .firstWhere((p) => p.id == widget.purchase.id);
          final items =
              _controller.purchaseEntryItemsForPurchase(purchase.id);
          final currentTotal = _controller.totalForPurchase(purchase.id);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatDate(purchase.purchaseDate),
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: purchase.isCancelled
                                  ? theme.colorScheme.errorContainer
                                  : theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              purchase.isCancelled ? 'Cancelled' : 'Active',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: purchase.isCancelled
                                    ? theme.colorScheme.onErrorContainer
                                    : theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (purchase.memo != null &&
                          purchase.memo!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          purchase.memo!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Total: \$${currentTotal.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (purchase.cancelReason != null &&
                          purchase.cancelReason!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Reason: ${purchase.cancelReason}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Items (${items.length})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Center(child: Text('No items.'))
              else
                ...items.map((item) {
                  final invItem =
                      _inventoryController.getItemById(item.itemId);
                  final name = invItem?.name ?? 'Item #${item.itemId}';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(
                        '${item.quantity} units × \$${item.unitCost.toStringAsFixed(2)}',
                      ),
                      trailing: Text(
                        '\$${item.subtotal.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
              if (!purchase.isCancelled)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final reason = await _promptCancelReason(context);
                          if (reason == null) return;
                          await _controller.cancelPurchase(
                            purchase.id,
                            reason: reason,
                          );
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel purchase'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed =
                              await _confirmDeletePurchase(context);
                          if (confirmed != true) return;
                          await _controller.deletePurchaseHard(purchase.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete permanently'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _promptCancelReason(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel purchase'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Cancel purchase'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDeletePurchase(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
    );
  }
}

