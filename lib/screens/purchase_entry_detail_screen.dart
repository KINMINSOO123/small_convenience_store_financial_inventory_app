import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../controllers/purchase_controller.dart';
import '../controllers/supplier_return_controller.dart';
import '../models/purchase_entry.dart';
import '../services/supplier_return_service.dart';

class PurchaseEntryDetailScreen extends StatefulWidget {
  const PurchaseEntryDetailScreen({
    super.key,
    required this.purchase,
    required this.controller,
    required this.inventoryController,
    required this.supplierReturnController,
  });

  final PurchaseEntry purchase;
  final PurchaseController controller;
  final InventoryController inventoryController;
  final SupplierReturnController supplierReturnController;

  @override
  State<PurchaseEntryDetailScreen> createState() =>
      _PurchaseEntryDetailScreenState();
}

class _PurchaseEntryDetailScreenState
    extends State<PurchaseEntryDetailScreen> {
  PurchaseController get _controller => widget.controller;
  InventoryController get _inventoryController => widget.inventoryController;
  SupplierReturnController get _returnController =>
      widget.supplierReturnController;

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

  Future<void> _editLineItem(int lineItemId, int currentItemId,
      int currentQuantity, double currentUnitCost, DateTime? currentExpiry) async {
    final items = _inventoryController.allItems;
    if (items.isEmpty) return;

    int selectedItemId = currentItemId;
    final quantityController =
        TextEditingController(text: currentQuantity.toString());
    final costController =
        TextEditingController(text: currentUnitCost.toStringAsFixed(2));
    DateTime? expiryDate = currentExpiry;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      decoration:
                          const InputDecoration(labelText: 'Unit cost'),
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
      await _controller.updateLineItemInPurchase(
        purchaseId: widget.purchase.id,
        lineItemId: lineItemId,
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

  Future<void> _deleteLineItem(int lineItemId) async {
    final confirmed = await _confirmDeleteLineItem(context);
    if (confirmed != true) return;
    try {
      await _controller.deleteLineItemFromPurchase(
        widget.purchase.id,
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
          'Remove this item from the purchase?',
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

  Widget _buildReturnsSection(
    BuildContext context,
    ThemeData theme,
    int purchaseId,
  ) {
    final returns = _returnController.returnsForPurchase(purchaseId);
    if (returns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Returns (${returns.length})',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...returns.map((r) {
          final total = r.totalAmount;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.errorContainer,
                child: const Icon(Icons.replay_outlined),
              ),
              title: Text(_formatDate(r.returnDate)),
              subtitle: r.memo != null && r.memo!.isNotEmpty
                  ? Text(r.memo!)
                  : null,
              trailing: Text(
                '-\$${total.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showReturnDetailDialog(context, r.id),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showReturnDialog(
    BuildContext context,
    int purchaseId,
  ) async {
    final items =
        _controller.purchaseEntryItemsForPurchase(purchaseId);
    if (items.isEmpty) return;

    final returnDateNotifier = ValueNotifier<DateTime>(DateTime.now());
    final memoController = TextEditingController();
    final quantityControllers = <int, TextEditingController>{};
    for (final item in items) {
      quantityControllers[item.id] = TextEditingController(text: '0');
    }

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Return to Supplier'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<DateTime>(
                      valueListenable: returnDateNotifier,
                      builder: (context, date, _) {
                        return Row(
                          children: [
                            Text('Return date: ${_formatDate(date)}'),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: date,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  returnDateNotifier.value = picked;
                                }
                              },
                              child: const Text('Pick date'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: memoController,
                      decoration: const InputDecoration(
                        labelText: 'Memo (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...items.map((item) {
                      final invItem =
                          _inventoryController.getItemById(item.itemId);
                      final name = invItem?.name ?? 'Item #${item.itemId}';
                      final available = _controller
                          .availableQuantityForPurchaseItem(item.id);
                      final ctrl = quantityControllers[item.id]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$name  (Purchased: ${item.quantity}, '
                              'In stock: $available)',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: ctrl,
                              decoration: const InputDecoration(
                                labelText: 'Return qty',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(true),
                  child: const Text('Return'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) return;

    final drafts = <SupplierReturnItemDraft>[];
    for (final item in items) {
      final ctrl = quantityControllers[item.id]!;
      final qty = int.tryParse(ctrl.text.trim());
      if (qty == null || qty <= 0) continue;
      if (qty > _controller.availableQuantityForPurchaseItem(item.id)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough stock for '
              '${_inventoryController.getItemById(item.itemId)?.name ?? 'item'}.',
            ),
          ),
        );
        return;
      }
      drafts.add(SupplierReturnItemDraft(
        purchaseItemId: item.id,
        itemId: item.itemId,
        quantity: qty,
      ));
    }

    if (drafts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least one item to return.'),
        ),
      );
      return;
    }

    try {
      await _returnController.createReturn(
        purchaseId: purchaseId,
        returnDate: returnDateNotifier.value,
        memo: memoController.text.trim().isEmpty
            ? null
            : memoController.text.trim(),
        items: drafts,
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _showReturnDetailDialog(
    BuildContext context,
    int returnId,
  ) async {
    final returnEntry =
        _returnController.returns.firstWhere((r) => r.id == returnId);
    final items =
        _returnController.returnItemsForReturn(returnId);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Return Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: ${_formatDate(returnEntry.returnDate)}'),
                    if (returnEntry.memo != null &&
                        returnEntry.memo!.isNotEmpty)
                      Text('Memo: ${returnEntry.memo}'),
                    const SizedBox(height: 8),
                    Text(
                      'Total: -\$${returnEntry.totalAmount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...items.map((item) {
                      final invItem =
                          _inventoryController.getItemById(item.itemId);
                      final name = invItem?.name ?? 'Item #${item.itemId}';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '$name  ${item.quantity} × '
                          '\$${item.unitCost.toStringAsFixed(2)} = '
                          '\$${item.subtotal.toStringAsFixed(2)}',
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        final confirmed =
                            await _confirmDeleteReturn(context);
                        if (confirmed != true) return;
                        await _returnController.deleteReturn(returnId);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete return'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmDeleteReturn(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete return'),
        content: const Text(
          'This will reverse the stock effect of the return. Continue?',
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
        title: Text('Purchase ${_formatDate(widget.purchase.purchaseDate)}'),
        actions: [
          if (widget.purchase.isDraft)
            IconButton(
              onPressed: _editMemo,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit memo',
            ),
        ],
      ),
      floatingActionButton: widget.purchase.isDraft
          ? FloatingActionButton.extended(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            )
          : null,
      body: AnimatedBuilder(
        animation: Listenable.merge([_controller, _returnController]),
        builder: (context, _) {
          final purchase = _controller.allPurchases
              .firstWhere((p) => p.id == widget.purchase.id);
          final items =
              _controller.purchaseEntryItemsForPurchase(purchase.id);
          final currentTotal = _controller.totalForPurchase(purchase.id);

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
                              color: purchase.isDraft
                                  ? theme.colorScheme.tertiaryContainer
                                  : purchase.isCancelled
                                      ? theme.colorScheme.errorContainer
                                      : theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              purchase.isDraft
                                  ? 'Draft'
                                  : purchase.isCancelled
                                      ? 'Cancelled'
                                      : 'Completed',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: purchase.isDraft
                                    ? theme.colorScheme.onTertiaryContainer
                                    : purchase.isCancelled
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${item.subtotal.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (purchase.isDraft) ...[
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editLineItem(
                                    item.id,
                                    item.itemId,
                                    item.quantity,
                                    item.unitCost,
                                    item.expiryDate,
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
                        ],
                      ),
                          ),
                        );
                    }),
              const SizedBox(height: 16),
              _buildReturnsSection(context, theme, purchase.id),
              const SizedBox(height: 24),
              if (purchase.isDraft)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _controller.completePurchase(purchase.id);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Complete Purchase'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed =
                              await _confirmDeleteDraftPurchase(context);
                          if (confirmed != true) return;
                          await _controller.deleteDraftPurchase(purchase.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Draft'),
                      ),
                    ),
                  ],
                )
              else if (!purchase.isCancelled)
                Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: !_controller.canCancelPurchase(purchase.id)
                            ? 'Cannot cancel — stock has been consumed. '
                                'Use Return to Supplier.'
                            : '',
                        child: OutlinedButton.icon(
                          onPressed: !_controller
                                  .canCancelPurchase(purchase.id)
                              ? null
                              : () async {
                                  final reason =
                                      await _promptCancelReason(context);
                                  if (reason == null) return;
                                  await _controller.cancelPurchase(
                                    purchase.id,
                                    reason: reason,
                                  );
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel purchase'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showReturnDialog(context, purchase.id),
                        icon: const Icon(Icons.replay_outlined),
                        label: const Text('Return to supplier'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed =
                              await _confirmReactivatePurchase(context);
                          if (confirmed != true) return;
                          await _controller.reactivatePurchase(purchase.id);
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

  Future<bool?> _confirmDeleteDraftPurchase(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete draft'),
        content: const Text(
          'This permanently deletes the draft purchase and its line items. '
          'This cannot be undone.',
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

  Future<bool?> _confirmReactivatePurchase(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivate purchase'),
        content: const Text(
          'This will restore the purchase to active status '
          'and add its stock back to inventory. Continue?',
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
}

