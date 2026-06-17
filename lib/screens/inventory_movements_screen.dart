import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../models/inventory_movement.dart';

class InventoryMovementsScreen extends StatefulWidget {
  const InventoryMovementsScreen({
    super.key,
    required this.inventoryController,
    this.itemId,
  });

  final InventoryController inventoryController;
  final int? itemId;

  @override
  State<InventoryMovementsScreen> createState() =>
      _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState
    extends State<InventoryMovementsScreen> {
  InventoryController get _controller => widget.inventoryController;
  String? _typeFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  List<InventoryMovement> get _filteredMovements {
    var list = widget.itemId != null
        ? _controller.movementsForItem(widget.itemId!)
        : _controller.movements.toList();

    if (_typeFilter != null) {
      list = list.where((m) => m.movementType == _typeFilter).toList();
    }
    if (_startDate != null) {
      list = list.where((m) => !m.movementDate.isBefore(_startDate!)).toList();
    }
    if (_endDate != null) {
      list = list.where((m) => !m.movementDate.isAfter(_endDate!)).toList();
    }

    list.sort((a, b) => b.movementDate.compareTo(a.movementDate));
    return list;
  }

  bool get _hasActiveFilters =>
      _typeFilter != null || _startDate != null || _endDate != null;

  void _clearFilters() {
    setState(() {
      _typeFilter = null;
      _startDate = null;
      _endDate = null;
    });
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateTime(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final itemName = widget.itemId != null
        ? _controller.getItemById(widget.itemId!)?.name ?? 'Item #${widget.itemId}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(itemName != null
            ? 'Movements — $itemName'
            : 'Inventory Movements'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear),
              tooltip: 'Clear filters',
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final movements = _filteredMovements;

          return Column(
            children: [
              _buildFilterBar(theme),
              const Divider(height: 1),
              Expanded(
                child: movements.isEmpty
                    ? Center(
                        child: Text(
                          widget.itemId != null
                              ? 'No movements for this item.'
                              : 'No movements found.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                        itemCount: movements.length,
                        itemBuilder: (context, index) {
                          final m = movements[index];
                          return _buildMovementCard(m, theme);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _typeFilter,
              decoration: const InputDecoration(
                labelText: 'Type',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'PURCHASE', child: Text('Purchase')),
                DropdownMenuItem(value: 'SALE', child: Text('Sale')),
                DropdownMenuItem(
                  value: 'SUPPLIER_RETURN',
                  child: Text('Supplier Return'),
                ),
                DropdownMenuItem(
                  value: 'CANCEL_PURCHASE',
                  child: Text('Cancel Purchase'),
                ),
              ],
              onChanged: (value) => setState(() => _typeFilter = value),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _pickDateRange,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(
              _startDate != null && _endDate != null
                  ? '${_formatDate(_startDate!)} — ${_formatDate(_endDate!)}'
                  : 'Date',
            ),
          ),
        ],
      ),
    );
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

  Widget _buildMovementCard(InventoryMovement m, ThemeData theme) {
    final IconData icon;
    final Color color;
    switch (m.movementType) {
      case 'PURCHASE':
        icon = Icons.add_circle_outline;
        color = theme.colorScheme.primary;
      case 'SALE':
        icon = Icons.remove_circle_outline;
        color = theme.colorScheme.error;
      case 'SUPPLIER_RETURN':
        icon = Icons.replay_outlined;
        color = Colors.orange;
      case 'CANCEL_PURCHASE':
        icon = Icons.cancel_outlined;
        color = theme.colorScheme.error;
      default:
        icon = Icons.swap_horiz;
        color = theme.colorScheme.outline;
    }

    final qtyColor =
        m.quantity < 0 ? theme.colorScheme.error : theme.colorScheme.primary;
    final sign = m.quantity < 0 ? '' : '+';
    final item = _controller.getItemById(m.itemId);
    final itemLabel = item?.name ?? 'Item #${m.itemId}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          itemLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _movementTypeLabel(m.movementType),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(m.movementDate),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$sign${m.quantity} × \$${m.unitCost.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: qtyColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$sign\$${(m.quantity * m.unitCost).toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: qtyColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ref: ${_referenceLabel(m.referenceType)} #${m.referenceId}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _movementTypeLabel(String type) {
    switch (type) {
      case 'PURCHASE':
        return 'Purchase';
      case 'SALE':
        return 'Sale';
      case 'SUPPLIER_RETURN':
        return 'Supplier Return';
      case 'CANCEL_PURCHASE':
        return 'Cancel Purchase';
      default:
        return type;
    }
  }

  String _referenceLabel(String type) {
    switch (type) {
      case 'PURCHASE':
        return 'Purchase';
      case 'SALE':
        return 'Sale';
      case 'SUPPLIER_RETURN':
        return 'Supplier Return';
      default:
        return type;
    }
  }
}
