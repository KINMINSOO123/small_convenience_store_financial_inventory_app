import '../data/inventory_db.dart';
import '../models/account.dart';
import '../models/journal_entry.dart';
import '../models/journal_line.dart';

class ExpensesRepository {
  ExpensesRepository({InventoryDb? database})
      : _database = database ?? InventoryDb();

  final InventoryDb _database;

  Future<void> init() async {
    await _database.init();
  }

  Future<List<Account>> fetchAccounts() async {
    final rows = await _database.fetchAccounts();
    return rows.map(Account.fromMap).toList();
  }

  Future<int> insertAccount(Account account) async {
    return _database.insertAccount(account.toMap());
  }

  Future<List<JournalEntry>> fetchJournalEntries() async {
    final rows = await _database.fetchJournalEntries();
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<List<JournalLine>> fetchJournalLines() async {
    final rows = await _database.fetchJournalLines();
    return rows.map(JournalLine.fromMap).toList();
  }

  Future<int> insertJournalEntry(JournalEntry entry) async {
    return _database.insertJournalEntry(entry.toMap());
  }

  Future<void> updateJournalEntry(JournalEntry entry) async {
    await _database.updateJournalEntry(entry.toMap(), entry.id);
  }

  Future<void> deleteJournalEntry(int id) async {
    await _database.deleteJournalEntry(id);
  }

  Future<int> insertJournalLine(JournalLine line) async {
    return _database.insertJournalLine(line.toMap());
  }

  Future<void> updateJournalLine(JournalLine line) async {
    await _database.updateJournalLine(line.toMap(), line.id);
  }

  Future<void> deleteJournalLinesByEntryId(int entryId) async {
    await _database.deleteJournalLinesByEntryId(entryId);
  }
}
