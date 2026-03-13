import 'package:drift/drift.dart';

import '../../domain/models/budget_model.dart';
import '../local/database_service.dart';

/// Repository for managing spending budgets.
class BudgetRepository {
  final DatabaseService _db;

  BudgetRepository(this._db);

  AppDatabase get _d => _db.db;

  // ── Mapping ──────────────────────────────────────────────────────────────

  BudgetModel _fromRow(Budget row) => BudgetModel(
    id: row.id,
    category: row.category,
    limitAmount: row.limitAmount,
    period: row.period,
    startDate: row.startDate,
    isActive: row.isActive,
    createdAt: row.createdAt,
  );

  BudgetsCompanion _toCompanion(BudgetModel b) => BudgetsCompanion.insert(
    category: b.category,
    limitAmount: b.limitAmount,
    period: Value(b.period),
    startDate: b.startDate,
    isActive: Value(b.isActive),
    createdAt: b.createdAt,
  );

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<int> add(BudgetModel budget) =>
      _d.into(_d.budgets).insert(_toCompanion(budget));

  Future<void> update(BudgetModel budget) async {
    await (_d.update(_d.budgets)..where((b) => b.id.equals(budget.id))).write(
      BudgetsCompanion(
        category: Value(budget.category),
        limitAmount: Value(budget.limitAmount),
        period: Value(budget.period),
        startDate: Value(budget.startDate),
        isActive: Value(budget.isActive),
      ),
    );
  }

  Future<void> delete(int id) async {
    await (_d.delete(_d.budgets)..where((b) => b.id.equals(id))).go();
  }

  Future<BudgetModel?> getById(int id) async {
    final row = await (_d.select(
      _d.budgets,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<BudgetModel>> getAll() async {
    final rows = await _d.select(_d.budgets).get();
    return rows.map(_fromRow).toList();
  }

  Future<List<BudgetModel>> getActive() async {
    final rows = await (_d.select(
      _d.budgets,
    )..where((b) => b.isActive.equals(true))).get();
    return rows.map(_fromRow).toList();
  }

  Future<BudgetModel?> getByCategory(String category, int period) async {
    final row =
        await (_d.select(_d.budgets)..where(
              (b) =>
                  b.category.equals(category) &
                  b.period.equals(period) &
                  b.isActive.equals(true),
            ))
            .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<double> getSpentForBudget(BudgetModel budget) async {
    final start = _currentPeriodStart(budget);
    final end = _currentPeriodEnd(budget);

    final rows =
        await (_d.select(_d.transactions)
              ..where(
                (t) => t.type.equals(1) & t.date.isBetweenValues(start, end),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();

    final normalizedCategory = budget.category.trim().toLowerCase();
    return rows
        .where((txn) => txn.category.trim().toLowerCase() == normalizedCategory)
        .fold<double>(0.0, (sum, txn) => sum + txn.amount);
  }

  Stream<void> watchAll() => _d.select(_d.budgets).watch().map((_) {});

  DateTime _currentPeriodStart(BudgetModel budget) {
    final now = DateTime.now();
    var periodStart = DateTime(
      budget.startDate.year,
      budget.startDate.month,
      budget.startDate.day,
    );

    while (_nextPeriodStart(periodStart, budget.period).isBefore(now)) {
      periodStart = _nextPeriodStart(periodStart, budget.period);
    }

    return periodStart;
  }

  DateTime _currentPeriodEnd(BudgetModel budget) {
    final start = _currentPeriodStart(budget);
    return _nextPeriodStart(
      start,
      budget.period,
    ).subtract(const Duration(seconds: 1));
  }

  DateTime _nextPeriodStart(DateTime start, int period) {
    switch (period) {
      case 0:
        return start.add(const Duration(days: 7));
      case 1:
        return _dateWithClampedDay(start.year, start.month + 1, start.day);
      case 2:
        return _dateWithClampedDay(start.year + 1, start.month, start.day);
      default:
        return _dateWithClampedDay(start.year, start.month + 1, start.day);
    }
  }

  DateTime _dateWithClampedDay(int year, int month, int day) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDayOfMonth));
  }
}
