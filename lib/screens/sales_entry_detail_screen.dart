import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../controllers/sales_controller.dart';
import '../models/sales_entry.dart';

class SalesEntryDetailScreen extends StatefulWidget {
  const SalesEntryDetailScreen({
    super.key,
    required this.sale,
    required this.controller,
    required this.inventoryController,
  });

  final SalesEntry sale;
  final SalesController controller;
  final InventoryController inventoryController;

  @override
  State<SalesEntryDetailScreen> createState() =>
      _SalesEntryDetailScreenState();
}

class _SalesEntryDetailScreenState extends State<SalesEntryDetailScreen> {
  SalesController get _controller => widget.controller;
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

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedItem =
                _inventoryController.getItemById(selectedItemId);
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
                    if (selectedItem != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Available: ${selectedItem.quantity}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Price: \$${selectedItem.sellingPrice.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity sold',
                      ),
                      keyboardType: TextInputType.number,
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
    if (quantity > selectedItem.quantity) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${selectedItem.quantity} units available.'),
        ),
      );
      return;
    }

    try {
      await _controller.addLineItemToSale(
        saleId: widget.sale.id,
        itemId: selectedItemId,
        quantity: quantity,
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _editMemo() async {
    final sale = _controller.salesEntries
        .firstWhere((s) => s.id == widget.sale.id);
    final controller = TextEditingController(text: sale.memo);
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
    await _controller.updateSalesEntryMemo(widget.sale.id, result);
  }

  Future<void> _editLineItem(int lineItemId, int currentItemId,
      int currentQuantity) async {
    final items = _inventoryController.allItems;
    if (items.isEmpty) return;

    int selectedItemId = currentItemId;
    final quantityController =
        TextEditingController(text: currentQuantity.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedItem =
                _inventoryController.getItemById(selectedItemId);
            return AlertDialog(
              title: const Text('Edit item'),
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
                    if (selectedItem != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Available: ${selectedItem.quantity}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Price: \$${selectedItem.sellingPrice.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity sold',
                      ),
                      keyboardType: TextInputType.number,
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
    final available = selectedItem.quantity;
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
      await _controller.updateLineItemInSale(
        saleId: widget.sale.id,
        lineItemId: lineItemId,
        itemId: selectedItemId,
        quantity: quantity,
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _deleteLineItem(int lineItemId) async {
    final confirmed = await _confirmDeleteLineItem(context);
    if (confirmed != true) return;
    try {
      await _controller.deleteLineItemFromSale(
        widget.sale.id,
        lineItemId,
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<bool?> _confirmDeleteLineItem(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item'),
        content: const Text(
          'Remove this item from the sale? '
          'Its stock effect will be reversed.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sale ${_formatDate(widget.sale.salesDate)}'),
        actions: [
          if (widget.sale.isDraft) ...[
            IconButton(
              onPressed: _editMemo,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit memo',
            ),
            IconButton(
              onPressed: () async {
                final confirmed = await _confirmDeleteSale(context);
                if (confirmed == true) {
                  await _controller.deleteSale(widget.sale.id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete draft',
            ),
          ],
        ],
      ),
      floatingActionButton: widget.sale.isDraft
          ? FloatingActionButton.extended(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            )
          : null,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final sale = _controller.salesEntries
              .firstWhere((s) => s.id == widget.sale.id);
          final items = _controller.salesEntryItemsForSale(sale.id);
          final currentTotal = _controller.totalForSale(sale.id);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
                              _formatDate(sale.salesDate),
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: sale.isDraft
                                  ? theme.colorScheme.tertiaryContainer
                                  : sale.isVoid
                                      ? theme.colorScheme.errorContainer
                                      : theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              sale.isDraft
                                  ? 'Draft'
                                  : sale.isVoid
                                      ? 'Void'
                                      : 'Completed',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: sale.isDraft
                                    ? theme.colorScheme.onTertiaryContainer
                                    : sale.isVoid
                                        ? theme.colorScheme.onErrorContainer
                                        : theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (sale.memo.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(sale.memo, style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Total: \$${currentTotal.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium,
                      ),
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
              const SizedBox(height: 24),
              if (sale.isDraft)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _controller.completeSale(sale.id);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Complete Sale'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed =
                              await _confirmDeleteDraftSale(context);
                          if (confirmed != true) return;
                          await _controller.deleteSale(sale.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Draft'),
                      ),
                    ),
                  ],
                )
              else if (!sale.isVoid)
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed =
                          await _confirmVoidSale(context);
                      if (confirmed != true) return;
                      await _controller.voidSale(sale.id);
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Void Sale'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed =
                              await _confirmReactivateSale(context);
                          if (confirmed != true) return;
                          await _controller.reactivateSale(sale.id);
                        },
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Reactivate'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed =
                              await _confirmDeleteSale(context);
                          if (confirmed != true) return;
                          await _controller.deleteSale(sale.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete permanently'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
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
                        '${item.quantity} units × \$${item.unitPrice.toStringAsFixed(2)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${item.subtotal.toStringAsFixed(2)}',
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                'COGS: \$${item.costOfGoodsSold.toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          if (sale.isDraft)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editLineItem(
                                    item.id,
                                    item.itemId,
                                    item.quantity,
                                  );
                                } else if (value == 'delete') {
                                  _deleteLineItem(item.id);
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
                            ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _confirmDeleteDraftSale(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete draft'),
        content: const Text(
          'This permanently deletes the draft sale and its line items.',
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

  Future<bool?> _confirmVoidSale(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void sale'),
        content: const Text(
          'This will reverse all stock effects of this sale. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Void'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmReactivateSale(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivate sale'),
        content: const Text(
          'This will re-consume stock and record sale movements. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDeleteSale(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sale'),
        content: Text(
          'Delete sale for ${_formatDate(widget.sale.salesDate)}?',
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

