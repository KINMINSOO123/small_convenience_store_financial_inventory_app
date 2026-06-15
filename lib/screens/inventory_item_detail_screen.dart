import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../models/inventory_item.dart';
import '../models/stock_batch.dart';

class InventoryItemDetailScreen extends StatelessWidget {
  const InventoryItemDetailScreen({
    super.key,
    required this.item,
    required this.controller,
    this.onEdit,
    this.onDelete,
  });

  final InventoryItem item;
  final InventoryController controller;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _expiryLabel(StockBatch batch) {
    final expiry = batch.expiryDate;
    if (expiry == null) return 'No expiry';
    return 'Expires ${_formatDate(expiry)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final batches = controller.stockRotationForItem(item.id);
          final totalValue = controller.stockValueForItem(item.id);
          final theme = Theme.of(context);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Stock Value',
                                  style: theme.textTheme.labelMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  totalValue.toStringAsFixed(2),
                                  style: theme.textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _Pill(label: item.category),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${item.quantity} units',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const Spacer(),
                            Text(
                              '${item.sellingPrice.toStringAsFixed(2)}/unit',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Stock Batches (FEFO/FIFO)',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${batches.length} batches',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: batches.isEmpty
                    ? const Center(
                        child: Text('No stock available for this item.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: batches.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final batch = batches[index];
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Text('${index + 1}'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        index == 0
                                            ? 'Sell first'
                                            : 'Sell next',
                                        style:
                                            theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          _Pill(
                                            label:
                                                '${batch.remainingQuantity} units',
                                          ),
                                          _Pill(
                                            label:
                                                'Unit cost ${batch.unitCost.toStringAsFixed(2)}',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _expiryLabel(batch),
                                        style:
                                            theme.textTheme.bodySmall,
                                      ),
                                      Text(
                                        'Purchased ${_formatDate(batch.receivedAt)}',
                                        style:
                                            theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Value: ${(batch.remainingQuantity * batch.unitCost).toStringAsFixed(2)}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
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
      child:
          Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
