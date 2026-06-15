import 'package:flutter/material.dart';

import '../controllers/expenses_controller.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/purchase_controller.dart';
import '../controllers/sales_controller.dart';
import '../data/inventory_db.dart';
import '../repositories/expenses_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/sales_repository.dart';
import '../services/expenses_service.dart';
import '../services/inventory_service.dart';
import '../services/purchase_service.dart';
import '../services/sales_service.dart';
import 'expenses_screen.dart';
import 'inventory_screen.dart';
import 'purchases_screen.dart';
import 'reporting_screen.dart';
import 'sales_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final InventoryDb _database = InventoryDb();
  late final InventoryRepository _inventoryRepository =
      InventoryRepository(database: _database);
  late final PurchaseRepository _purchaseRepository =
      PurchaseRepository(database: _database);
  late final ExpensesRepository _expensesRepository =
      ExpensesRepository(database: _database);
  late final SalesRepository _salesRepository =
      SalesRepository(database: _database);

  late final InventoryService _inventoryService =
      InventoryService(_inventoryRepository);
  late final PurchaseService _purchaseService =
      PurchaseService(_purchaseRepository, _inventoryService);
  late final InventoryController _inventoryController =
      InventoryController(
        inventoryService: _inventoryService,
        purchaseController: _purchaseController,
      );
  late final PurchaseController _purchaseController =
      PurchaseController(
        purchaseService: _purchaseService,
        onInventoryChanged: () {
          _inventoryController.notifyListeners();
        },
      );
  late final ExpensesController _expensesController = ExpensesController(
    expensesService: ExpensesService(_expensesRepository),
  );
  late final SalesController _salesController = SalesController(
    salesService: SalesService(
      _salesRepository,
      _inventoryService,
      _purchaseService,
    ),
    onInventoryChanged: () {
      _inventoryController.notifyListeners();
      _purchaseController.notifyListeners();
    },
  );
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _inventoryController.dispose();
    _purchaseController.dispose();
    _expensesController.dispose();
    _salesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _inventoryController.loadData(),
      _purchaseController.loadData(),
      _expensesController.loadData(),
      _salesController.loadData(),
    ]);
  }

  List<Widget> get _screens => [
        InventoryScreen(controller: _inventoryController),
        PurchasesScreen(
          controller: _purchaseController,
          inventoryController: _inventoryController,
        ),
        SalesScreen(
          controller: _salesController,
          inventoryController: _inventoryController,
        ),
        ExpensesScreen(controller: _expensesController),
        ReportingScreen(
          inventoryController: _inventoryController,
          purchaseController: _purchaseController,
          expensesController: _expensesController,
          salesController: _salesController,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final title = _index == 0
      ? 'Inventory'
      : _index == 1
        ? 'Purchases'
        : _index == 2
          ? 'Sales'
          : _index == 3
            ? 'Expenses'
            : 'Reports';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Purchases',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
