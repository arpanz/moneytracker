import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/transaction_model.dart';
import '../local/database_service.dart';

/// Repository for managing financial transactions.
class TransactionRepository {
  final DatabaseService _db;

  TransactionRepository(this._db);

  AppDatabase get _d => _db.db;

  // ── Mapping ──────────────────────────────────────────────────────────────

  TransactionModel _fromRow(Transaction row) => TransactionModel(
    id: row.id,
    amount: row.amount,
    category: row.category,
    subcategory: row.subcategory,
    note: row.note,
    date: row.date,
    type: row.type,
    isRecurring: row.isRecurring,
    recurringRule: row.recurringRule,
    splitId: row.splitId,
    tags: List<String>.from(jsonDecode(row.tags) as List),
    accountId: row.accountId,
    toAccountId: row.toAccountId,
    createdAt: row.createdAt,
  );

  TransactionsCompanion _toCompanion(TransactionModel t) =>
      TransactionsCompanion.insert(
        amount: t.amount,
        category: t.category,
        subcategory: Value(t.subcategory),
        note: Value(t.note),
        date: t.date,
        type: Value(t.type),
        isRecurring: Value(t.isRecurring),
        recurringRule: Value(t.recurringRule),
        splitId: Value(t.splitId),
        tags: Value(jsonEncode(t.tags)),
        accountId: t.accountId,
        toAccountId: Value(t.toAccountId),
        createdAt: t.createdAt,
      );

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<int> add(TransactionModel transaction) =>
      _d.into(_d.transactions).insert(_toCompanion(transaction));

  Future<void> update(TransactionModel transaction) async {
    await (_d.update(
      _d.transactions,
    )..where((t) => t.id.equals(transaction.id))).write(
      TransactionsCompanion(
        amount: Value(transaction.amount),
        category: Value(transaction.category),
        subcategory: Value(transaction.subcategory),
        note: Value(transaction.note),
        date: Value(transaction.date),
        type: Value(transaction.type),
        isRecurring: Value(transaction.isRecurring),
        recurringRule: Value(transaction.recurringRule),
        splitId: Value(transaction.splitId),
        tags: Value(jsonEncode(transaction.tags)),
        accountId: Value(transaction.accountId),
        toAccountId: Value(transaction.toAccountId),
      ),
    );
  }

  Future<void> delete(int id) async {
    await (_d.delete(_d.transactions)..where((t) => t.id.equals(id))).go();
  }

  Future<TransactionModel?> getById(int id) async {
    final row = await (_d.select(
      _d.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Fetches transactions with optional SQL-level [limit] and [offset].
  /// Both are applied directly on the Drift query — no in-memory slicing.
  Future<List<TransactionModel>> getAll({int? limit, int? offset}) async {
    final q = _d.select(_d.transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    if (limit != null || offset != null) {
      q.limit(limit ?? -1, offset: offset ?? 0);
    }
    final rows = await q.get();
    return rows.map(_fromRow).toList();
  }

  // ── Filtered Queries ─────────────────────────────────────────────────────

  Future<List<TransactionModel>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final rows =
        await (_d.select(_d.transactions)
              ..where((t) => t.date.isBetweenValues(start, end))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<TransactionModel>> getByCategory(String category) async {
    final rows =
        await (_d.select(_d.transactions)
              ..where((t) => t.category.equals(category))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<TransactionModel>> getByAccount(String accountId) async {
    final rows =
        await (_d.select(_d.transactions)
              ..where((t) => t.accountId.equals(accountId))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<TransactionModel>> getByType(int type) async {
    final rows =
        await (_d.select(_d.transactions)
              ..where((t) => t.type.equals(type))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<TransactionModel>> search(String query) async {
    final lowerQuery = query.toLowerCase();
    final all = await getAll();
    return all.where((t) {
      if (t.category.toLowerCase().contains(lowerQuery)) return true;
      if (t.subcategory?.toLowerCase().contains(lowerQuery) == true)
        return true;
      if (t.note?.toLowerCase().contains(lowerQuery) == true) return true;
      if (t.tags.any((tag) => tag.toLowerCase().contains(lowerQuery)))
        return true;
      return false;
    }).toList();
  }

  Future<List<TransactionModel>> getRecurring() async {
    final rows =
        await (_d.select(_d.transactions)
              ..where((t) => t.isRecurring.equals(true))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  // ── Aggregates ───────────────────────────────────────────────────────────

  Future<double> getTotalByType(int type, DateTime start, DateTime end) async {
    final txns =
        await (_d.select(_d.transactions)..where(
              (t) => t.type.equals(type) & t.date.isBetweenValues(start, end),
            ))
            .get();
    return txns.fold<double>(0.0, (s, t) => s + t.amount);
  }

  Future<Map<String, double>> getCategoryTotals(
    DateTime start,
    DateTime end,
  ) async {
    final txns =
        await (_d.select(_d.transactions)..where(
              (t) => t.type.equals(1) & t.date.isBetweenValues(start, end),
            ))
            .get();
    final totals = <String, double>{};
    for (final t in txns) {
      totals[t.category] = (totals[t.category] ?? 0.0) + t.amount;
    }
    return totals;
  }

  // ── Real-Time Stream ─────────────────────────────────────────────────────

  Stream<void> watchAll() => _d.select(_d.transactions).watch().map((_) {});
}
