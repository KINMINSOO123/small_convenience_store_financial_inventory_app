import '../models/account.dart';
import '../models/journal_entry.dart';
import '../models/journal_line.dart';
import '../repositories/expenses_repository.dart';

class ExpensesService {
  ExpensesService(this._repository);

  final ExpensesRepository _repository;
  final List<Account> _accounts = [];
  final List<JournalEntry> _entries = [];
  final List<JournalLine> _lines = [];

  List<Account> get accounts => List.unmodifiable(_accounts);

  List<JournalEntry> get expenseEntries => List.unmodifiable(
        _entries.where((entry) => entry.type == 'EXPENSE'),
      );

  List<JournalLine> get journalLines => List.unmodifiable(_lines);

  List<Account> get expenseAccounts => List.unmodifiable(
        _accounts.where((account) => account.type == 'expense'),
      );

  Account? get defaultExpenseAccount {
    return expenseAccounts.isNotEmpty ? expenseAccounts.first : null;
  }

  Future<void> load() async {
    await _repository.init();
    final accountRows = await _repository.fetchAccounts();
    final journalRows = await _repository.fetchJournalEntries();
    final lineRows = await _repository.fetchJournalLines();

    _accounts
      ..clear()
      ..addAll(accountRows);
    if (_accounts.isEmpty) {
      await _seedDefaultAccounts();
    }

    _entries
      ..clear()
      ..addAll(journalRows);
    _lines
      ..clear()
      ..addAll(lineRows);
  }

  Future<void> addExpense({
    required int expenseAccountId,
    required double amount,
    required String memo,
    required DateTime entryDate,
  }) async {
    final entry = JournalEntry(
      id: 0,
      date: entryDate,
      memo: memo,
      total: amount,
      type: 'EXPENSE',
    );
    final entryId = await _repository.insertJournalEntry(entry);
    final storedEntry = JournalEntry(
      id: entryId,
      date: entryDate,
      memo: memo,
      total: amount,
      type: 'EXPENSE',
    );
    _entries.insert(0, storedEntry);

    await _replaceLinesForEntry(
      entryId: entryId,
      expenseAccountId: expenseAccountId,
      amount: amount,
    );
  }

  Future<void> updateExpense({
    required int entryId,
    required int expenseAccountId,
    required double amount,
    required String memo,
    required DateTime entryDate,
  }) async {
    final index = _entries.indexWhere((entry) => entry.id == entryId);
    if (index == -1) {
      return;
    }

    final updated = JournalEntry(
      id: entryId,
      date: entryDate,
      memo: memo,
      total: amount,
      type: 'EXPENSE',
    );
    await _repository.updateJournalEntry(updated);
    _entries[index] = updated;

    await _replaceLinesForEntry(
      entryId: entryId,
      expenseAccountId: expenseAccountId,
      amount: amount,
    );
  }

  Future<void> deleteExpense(int entryId) async {
    await _repository.deleteJournalLinesByEntryId(entryId);
    await _repository.deleteJournalEntry(entryId);
    _entries.removeWhere((entry) => entry.id == entryId);
    _lines.removeWhere((line) => line.entryId == entryId);
  }

  Future<Account> addAccount(String name) async {
    for (final a in _accounts) {
      if (a.name.toLowerCase() == name.toLowerCase()) return a;
    }
    final account = Account(id: 0, name: name, type: 'expense');
    final id = await _repository.insertAccount(account);
    final stored = Account(id: id, name: name, type: 'expense');
    _accounts.add(stored);
    return stored;
  }

  Future<void> _seedDefaultAccounts() async {
    final defaults = <Account>[
      Account(id: 0, name: 'Cash', type: 'asset'),
      Account(id: 0, name: 'Inventory', type: 'asset'),
      Account(id: 0, name: 'Expenses', type: 'expense'),
    ];
    for (final account in defaults) {
      final id = await _repository.insertAccount(account);
      _accounts.add(Account(id: id, name: account.name, type: account.type));
    }
  }

  Account _cashAccount() {
    return _accounts.firstWhere(
      (account) => account.name.toLowerCase() == 'cash',
      orElse: () => _accounts.first,
    );
  }

  Future<void> _replaceLinesForEntry({
    required int entryId,
    required int expenseAccountId,
    required double amount,
  }) async {
    await _repository.deleteJournalLinesByEntryId(entryId);
    _lines.removeWhere((line) => line.entryId == entryId);

    final cashAccount = _cashAccount();
    final lines = [
      JournalLine(
        id: 0,
        entryId: entryId,
        accountId: expenseAccountId,
        debit: amount,
        credit: 0,
      ),
      JournalLine(
        id: 0,
        entryId: entryId,
        accountId: cashAccount.id,
        debit: 0,
        credit: amount,
      ),
    ];
    for (final line in lines) {
      final lineId = await _repository.insertJournalLine(line);
      _lines.add(
        JournalLine(
          id: lineId,
          entryId: entryId,
          accountId: line.accountId,
          debit: line.debit,
          credit: line.credit,
        ),
      );
    }
  }
}
