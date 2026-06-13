import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

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

enum _CsvType { inventory, unknown }

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
      InventoryController(inventoryService: _inventoryService);
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

  Future<void> _showThresholdDialog() async {
    final controller = TextEditingController(
      text: _inventoryController.lowStockThreshold.toString(),
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Low stock threshold'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Units at or below',
            ),
            keyboardType: TextInputType.number,
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

    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number greater than 0.'),
        ),
      );
      return;
    }

    await _inventoryController.setLowStockThreshold(value);
  }

  Future<void> _showExportDialog() async {
    final paths = await _inventoryController.exportCsvFiles();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export CSV files'),
          content: SizedBox(
            width: double.maxFinite,
            child: SelectableText(
              'Inventory CSV:\n${paths['inventory']}\n\n',
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

  Future<void> _showImportDialog() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const ['csv'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    String? inventoryCsv;

    for (final file in result.files) {
      final path = file.path;
      if (path == null) {
        continue;
      }
      final content = await File(path).readAsString();
      final type = _detectCsvType(content);
      if (type == _CsvType.inventory) {
        inventoryCsv = content;
      }
    }

    if (inventoryCsv == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an inventory CSV file.'),
        ),
      );
      return;
    }

    await _inventoryController.importCsvFiles(
      inventoryCsv: inventoryCsv,
      purchasesCsv: '',
    );
  }

  _CsvType _detectCsvType(String csv) {
    final rows = const CsvToListConverter().convert(csv);
    if (rows.isEmpty) {
      return _CsvType.unknown;
    }
    final headers = rows.first
        .map((value) => value.toString().trim().toLowerCase())
        .toList();
    if (headers.contains('category') && headers.contains('unit_cost')) {
      return _CsvType.inventory;
    }
    return _CsvType.unknown;
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
        actions: [
          if (_index == 0)
            IconButton(
              onPressed: _showThresholdDialog,
              icon: const Icon(Icons.tune),
              tooltip: 'Low stock threshold',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _showExportDialog();
              }
              if (value == 'import') {
                _showImportDialog();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export',
                child: Text('Export CSV'),
              ),
              PopupMenuItem(
                value: 'import',
                child: Text('Import CSV'),
              ),
            ],
          ),
        ],
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
