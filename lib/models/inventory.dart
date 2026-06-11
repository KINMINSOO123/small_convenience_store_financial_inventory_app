import 'inventory_item.dart';

class Inventory {
  Inventory({List<InventoryItem>? items}) : items = items ?? [];

  final List<InventoryItem> items;

  int get totalQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalValue {
    return items.fold(0, (sum, item) => sum + item.totalValue);
  }
}
