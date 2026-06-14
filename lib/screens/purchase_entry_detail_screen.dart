import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../controllers/purchase_controller.dart';
import '../models/purchase_entry.dart';

class PurchaseEntryDetailScreen extends StatelessWidget {
  const PurchaseEntryDetailScreen({
    super.key,
    required this.purchase,
    required this.controller,
    required this.inventoryController,
  });

  final PurchaseEntry purchase;
  final PurchaseController controller;
  final InventoryController inventoryController;

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Purchase ${_formatDate(purchase.purchasedAt)}'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final items =
              controller.purchaseEntryItemsForPurchase(purchase.id);
          final currentTotal = controller.totalForPurchase(purchase.id);

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
                              _formatDate(purchase.purchasedAt),
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
                      inventoryController.getItemById(item.itemId);
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
                          await controller.cancelPurchase(
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
                          await controller.deletePurchaseHard(purchase.id);
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
