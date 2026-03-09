import 'package:isar/isar.dart';

import '../../domain/models/transaction_model.dart';
import '../local/database_service.dart';

/// Repository for managing financial transactions.
///
/// Provides full CRUD operations, filtered queries by date/category/account/type,
/// aggregate calculations, and a real-time watch stream.
class TransactionRepository {
  final DatabaseService _db;

  TransactionRepository(this._db);

  Isar get _isar => _db.isar;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserts a new transaction and returns its auto-generated id.
  Future<int> add(TransactionModel transaction) async {
    return _isar.writeTxn(() async {
      return _isar.transactionModels.put(transaction);
    });
  }

  /// Updates an existing transaction in-place.
  Future<void> update(TransactionModel transaction) async {
    await _isar.writeTxn(() async {
      await _isar.transactionModels.put(transaction);
    });
  }

  /// Deletes a transaction by its id.
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.transactionModels.delete(id);
    });
  }

  /// Retrieves a single transaction by id, or null if not found.
  Future<TransactionModel?> getById(int id) async {
    return _isar.transactionModels.get(id);
  }

  /// Returns all transactions with optional pagination.
  ///
  /// Results are ordered by [date] descending (newest first).
  Future<List<TransactionModel>> getAll({int? limit, int? offset}) async {
    var query = _isar.transactionModels
        .where()
        .sortByDateDesc();

    if (offset != null && offset > 0) {
      query = query.offset(offset);
    }
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }

    return query.findAll();
  }

  // ── FILTERED QUERIES ─────────────────────────────────────────────────────

  /// Returns transactions within the given date range (inclusive).
  Future<List<TransactionModel>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return _isar.transactionModels
        .where()
        .dateBetween(start, end)
        .sortByDateDesc()
        .findAll();
  }

  /// Returns transactions matching a specific category.
  Future<List<TransactionModel>> getByCategory(String category) async {
    return _isar.transactionModels
        .where()
        .categoryEqualTo(category)
        .sortByDateDesc()
        .findAll();
  }

  /// Returns transactions for a specific account.
  Future<List<TransactionModel>> getByAccount(String accountId) async {
    return _isar.transactionModels
        .where()
        .accountIdEqualTo(accountId)
        .sortByDateDesc()
        .findAll();
  }

  /// Returns transactions of a given type (0=income, 1=expense, 2=transfer).
  Future<List<TransactionModel>> getByType(int type) async {
    return _isar.transactionModels
        .where()
        .typeEqualTo(type)
        .sortByDateDesc()
        .findAll();
  }

  /// Full-text search across category, subcategory, note, and tags.
  Future<List<TransactionModel>> search(String query) async {
    final lowerQuery = query.toLowerCase();
    return _isar.transactionModels
        .where()
        .sortByDateDesc()
        .findAll()
        .then((all) => all.where((t) {
              if (t.category.toLowerCase().contains(lowerQuery)) return true;
              if (t.subcategory?.toLowerCase().contains(lowerQuery) == true) {
                return true;
              }
              if (t.note?.toLowerCase().contains(lowerQuery) == true) {
                return true;
              }
              if (t.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))) {
                return true;
              }
              return false;
            }).toList());
  }

  /// Returns all recurring transactions.
  Future<List<TransactionModel>> getRecurring() async {
    return _isar.transactionModels
        .filter()
        .isRecurringEqualTo(true)
        .sortByDateDesc()
        .findAll();
  }

  // ── AGGREGATES ────────────────────────────────────────────────────────────

  /// Calculates the total amount for a given type within a date range.
  ///
  /// Useful for "total income this month" or "total expenses this week".
  Future<double> getTotalByType(
    int type,
    DateTime start,
    DateTime end,
  ) async {
    final transactions = await _isar.transactionModels
        .where()
        .dateBetween(start, end)
        .filter()
        .typeEqualTo(type)
        .findAll();

    return transactions.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Returns a map of category -> total amount for expenses in a date range.
  ///
  /// Only includes expense transactions (type == 1).
  Future<Map<String, double>> getCategoryTotals(
    DateTime start,
    DateTime end,
  ) async {
    final transactions = await _isar.transactionModels
        .where()
        .dateBetween(start, end)
        .filter()
        .typeEqualTo(1)
        .findAll();

    final totals = <String, double>{};
    for (final t in transactions) {
      totals[t.category] = (totals[t.category] ?? 0.0) + t.amount;
    }
    return totals;
  }

  // ── REAL-TIME STREAM ─────────────────────────────────────────────────────

  /// Watches the entire transaction collection for any changes.
  ///
  /// Emits an event whenever a transaction is added, updated, or deleted.
  Stream<void> watchAll() {
    return _isar.transactionModels.watchLazy();
  }
}
