import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../controllers/sales_controller.dart';
import '../models/sales_entry.dart';

class SalesEntryDetailScreen extends StatelessWidget {
  const SalesEntryDetailScreen({
    super.key,
    required this.sale,
    required this.controller,
    required this.inventoryController,
  });

  final SalesEntry sale;
  final SalesController controller;
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
        title: Text('Sale ${_formatDate(sale.entryDate)}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await _confirmDeleteSale(context);
                if (confirmed == true) {
                  await controller.deleteSale(sale.id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final items = controller.salesEntryItemsForSale(sale.id);
          final currentTotal = controller.totalForSale(sale.id);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(sale.entryDate),
                        style: theme.textTheme.titleLarge,
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
                        '${item.quantity} units × \$${item.unitPrice.toStringAsFixed(2)}',
                      ),
                      trailing: Column(
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
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _confirmDeleteSale(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sale'),
        content: Text(
          'Delete sale for ${_formatDate(sale.entryDate)}?',
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
