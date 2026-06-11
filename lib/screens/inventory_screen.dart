import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../models/inventory_item.dart';
import '../models/stock_batch.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.controller});

  final InventoryController controller;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  InventoryController get _controller => widget.controller;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _controller.setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCategoryDialog({String? existing}) async {
    final nameController = TextEditingController(text: existing ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Add category' : 'Rename category'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Category name'),
            textInputAction: TextInputAction.done,
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

    if (result != true) {
      return;
    }

    final name = nameController.text.trim();
    final saved = existing == null
        ? await _controller.addCategory(name)
        : await _controller.renameCategory(existing, name);
    if (!mounted) {
      return;
    }
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a unique category name.')),
      );
      return;
    }
    if (existing != null) {
      setState(() => _selectedCategory = name);
    }
  }

  Future<void> _deleteCategory(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete category'),
          content: Text(
            'Delete "$category"? Only empty categories can be deleted.',
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
    if (confirmed != true) {
      return;
    }
    final deleted = await _controller.deleteCategory(category);
    if (!mounted) {
      return;
    }
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete the items in this category first.'),
        ),
      );
      return;
    }
    setState(() => _selectedCategory = null);
  }

  Future<void> _showItemDialog({
    required String category,
    InventoryItem? existing,
  }) async {
    final normalizedCategory = category.trim();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final quantityController = TextEditingController(
      text: existing?.quantity.toString() ?? '',
    );
    final sellingPriceController = TextEditingController(
      text: existing == null ? '' : existing.sellingPrice.toStringAsFixed(2),
    );
    final initialCostController = TextEditingController();
    final thresholdController = TextEditingController(
      text:
          existing?.lowStockThreshold.toString() ??
          _controller.lowStockThreshold.toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Item' : 'Edit Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Category'),
                      child: Text(category),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
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
                    if (existing == null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: initialCostController,
                        decoration: const InputDecoration(
                          labelText: 'Initial unit cost',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: thresholdController,
                      decoration: const InputDecoration(
                        labelText: 'Low stock threshold',
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
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
                  child: Text(existing == null ? 'Add' : 'Save'),
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

    final name = nameController.text.trim();
    final categoryName = normalizedCategory;
    final quantity = int.tryParse(quantityController.text.trim());
    final sellingPrice = double.tryParse(sellingPriceController.text.trim());
    final initialUnitCost = double.tryParse(initialCostController.text.trim());
    final lowStockThreshold = int.tryParse(thresholdController.text.trim());

    if (name.isEmpty ||
        categoryName.isEmpty ||
        quantity == null ||
        quantity < 0 ||
        sellingPrice == null ||
        lowStockThreshold == null ||
        lowStockThreshold <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields with valid values.'),
        ),
      );
      return;
    }

    if (existing == null) {
      if (quantity > 0 && initialUnitCost == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter the initial unit cost for opening stock.'),
          ),
        );
        return;
      }
        try {
          await _controller.addItem(
            name: name,
            category: categoryName,
            quantity: quantity,
            sellingPrice: sellingPrice,
            initialUnitCost: initialUnitCost ?? 0,
            lowStockThreshold: lowStockThreshold,
          );
        } catch (error) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to add item: $error')),
          );
          return;
        }
    } else {
        try {
          await _controller.updateItem(
            InventoryItem(
              id: existing.id,
              name: name,
              category: categoryName,
              quantity: quantity,
              sellingPrice: sellingPrice,
              lowStockThreshold: lowStockThreshold,
            ),
          );
        } catch (error) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to save item: $error')),
          );
          return;
        }
    }
  }

  Future<void> _showStockRotationDialog(InventoryItem item) async {
    final batches = _controller.stockRotationForItem(item.id);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.name),
          content: SizedBox(
            width: double.maxFinite,
            child: batches.isEmpty
                ? const Text('No stock available for this item.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: batches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final batch = batches[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(
                          index == 0 ? 'Sell first' : 'Sell next',
                        ),
                        subtitle: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _Pill(label: '${batch.remainingQuantity} units'),
                            _Pill(label: _expiryLabel(batch)),
                            _Pill(
                              label:
                                  'Purchased ${_formatDate(batch.receivedAt)}',
                            ),
                            _Pill(
                              label:
                                  'Value ${(batch.remainingQuantity * batch.unitCost).toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      );
                    },
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
  }

  Future<bool?> _confirmDeleteItem(String name) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item'),
          content: Text('Delete "$name" and all related data?'),
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

  String _expiryLabel(StockBatch batch) {
    final expiry = batch.expiryDate;
    if (expiry == null) {
      return 'No expiry';
    }
    return 'Expires ${_formatDate(expiry)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final category = _selectedCategory?.trim();
          if (category == null) {
            _showCategoryDialog();
            return;
          }
          _showItemDialog(category: category);
        },
        icon: const Icon(Icons.add),
        label: Text(_selectedCategory == null ? 'Add category' : 'Add item'),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final query = _searchController.text.trim().toLowerCase();
          final lowStockCount = _controller.lowStockItems.length;
          final expiringCount = _controller.expiringSoonItems.length;
          final categories = _controller.categories;
          final selectedCategory = categories.firstWhere(
            (category) =>
                category.trim().toLowerCase() ==
                (_selectedCategory ?? '').trim().toLowerCase(),
            orElse: () => '',
          );
          final activeCategory = selectedCategory.isEmpty ? null : selectedCategory;
          final categoryItems = activeCategory == null
              ? <InventoryItem>[]
              : _controller.itemsForCategory(activeCategory);
          final filteredCategories = categories
              .where((category) => category.toLowerCase().contains(query))
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        title: 'Total Units',
                        value: '${_controller.totalQuantity}',
                        caption: 'All items',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        title: 'Stock Value',
                        value: _controller.totalValue.toStringAsFixed(2),
                        caption: 'FEFO/FIFO based',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (activeCategory == null) ...[
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search category',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (lowStockCount > 0 || expiringCount > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Low stock: $lowStockCount - '
                                'Expiring soon: $expiringCount',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    activeCategory == null
                        ? Text(
                            'Categories',
                            style: Theme.of(context).textTheme.titleMedium,
                          )
                        : TextButton.icon(
                            onPressed: () {
                              setState(() => _selectedCategory = null);
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: Text(activeCategory),
                          ),
                    Text(
                      activeCategory == null
                          ? '${filteredCategories.length} categories'
                          : '${categoryItems.length} items',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : activeCategory == null
                    ? _CategoryList(
                        categories: filteredCategories,
                        controller: _controller,
                        onOpen: (category) {
                          setState(() => _selectedCategory = category);
                        },
                        onRename: (category) =>
                            _showCategoryDialog(existing: category),
                        onDelete: _deleteCategory,
                      )
                    : categoryItems.isEmpty
                    ? const Center(
                        child: Text('No items yet. Tap "Add item" to start.'),
                      )
                    : ListView.separated(
                        itemCount: categoryItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = categoryItems[index];
                          final isLowStock = item.isLowStock;
                          final isExpiringSoon = _controller.isItemExpiringSoon(
                            item.id,
                          );
                          final badgeColor = isLowStock || isExpiringSoon
                              ? Theme.of(context).colorScheme.errorContainer
                              : Theme.of(context).colorScheme.surface;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            title: Text(item.name),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _Pill(label: item.category),
                                  _Pill(label: '${item.quantity} units'),
                                  _Pill(
                                    label: 'Low at ${item.lowStockThreshold}',
                                  ),
                                ],
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: badgeColor,
                              child: Text(
                                item.name.isEmpty
                                    ? '?'
                                    : item.name[0].toUpperCase(),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(item.sellingPrice.toStringAsFixed(2)),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _showItemDialog(
                                    category: item.category,
                                    existing: item,
                                  ),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final confirmed = await _confirmDeleteItem(
                                      item.name,
                                    );
                                    if (confirmed != true) {
                                      return;
                                    }
                                    await _controller.removeItem(item.id);
                                  },
                                  tooltip: 'Remove',
                                ),
                              ],
                            ),
                            onTap: () => _showStockRotationDialog(item),
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

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.controller,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final List<String> categories;
  final InventoryController controller;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onRename;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(
        child: Text('No categories yet. Tap "Add category" to start.'),
      );
    }

    return ListView.separated(
      itemCount: categories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final category = categories[index];
        final itemCount = controller.itemsForCategory(category).length;
        final quantity = controller.quantityForCategory(category);
        final stockValue = controller.stockValueForCategory(category);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(category.isEmpty ? '?' : category[0].toUpperCase()),
          ),
          title: Text(category),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Pill(label: '$itemCount items'),
                _Pill(label: '$quantity units'),
                _Pill(label: 'Value ${stockValue.toStringAsFixed(2)}'),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') {
                onRename(category);
              }
              if (value == 'delete') {
                onDelete(category);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          onTap: () => onOpen(category),
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
