import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/journal_entry.dart';
import '../models/journal_line.dart';
import '../repositories/expenses_repository.dart';
import '../services/expenses_service.dart';

class ExpensesController extends ChangeNotifier {
  ExpensesController({ExpensesService? expensesService})
      : _service = expensesService ??
            ExpensesService(ExpensesRepository());

  final ExpensesService _service;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  List<JournalEntry> get expenseEntries => _service.expenseEntries;

  List<Account> get expenseAccounts => _service.expenseAccounts;

  List<Account> get accounts => _service.accounts;

  List<JournalLine> get journalLines => _service.journalLines;

  Account? get defaultExpenseAccount => _service.defaultExpenseAccount;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    await _service.load();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addExpense({
    required int expenseAccountId,
    required double amount,
    required String memo,
    required DateTime entryDate,
  }) async {
    await _service.addExpense(
      expenseAccountId: expenseAccountId,
      amount: amount,
      memo: memo,
      entryDate: entryDate,
    );
    notifyListeners();
  }

  Future<void> updateExpense({
    required int entryId,
    required int expenseAccountId,
    required double amount,
    required String memo,
    required DateTime entryDate,
  }) async {
    await _service.updateExpense(
      entryId: entryId,
      expenseAccountId: expenseAccountId,
      amount: amount,
      memo: memo,
      entryDate: entryDate,
    );
    notifyListeners();
  }

  Future<void> deleteExpense(int entryId) async {
    await _service.deleteExpense(entryId);
    notifyListeners();
  }

  Future<Account> addAccount(String name) async {
    final account = await _service.addAccount(name);
    notifyListeners();
    return account;
  }
}
