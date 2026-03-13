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
    await (_d.update(_d.budgets)..where((b) => b.id.equals(budget.id)))
        .write(BudgetsCompanion(
      category: Value(budget.category),
      limitAmount: Value(budget.limitAmount),
      period: Value(budget.period),
      startDate: Value(budget.startDate),
      isActive: Value(budget.isActive),
    ));
  }

  Future<void> delete(int id) async {
    await (_d.delete(_d.budgets)..where((b) => b.id.equals(id))).go();
  }

  Future<BudgetModel?> getById(int id) async {
    final row = await (_d.select(_d.budgets)..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<BudgetModel>> getAll() async {
    final rows = await _d.select(_d.budgets).get();
    return rows.map(_fromRow).toList();
  }

  Future<List<BudgetModel>> getActive() async {
    final rows = await (_d.select(_d.budgets)
          ..where((b) => b.isActive.equals(true)))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<BudgetModel?> getByCategory(String category, int period) async {
    final row = await (_d.select(_d.budgets)
          ..where((b) =>
              b.category.equals(category) &
              b.period.equals(period) &
              b.isActive.equals(true)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<double> getSpentForBudget(BudgetModel budget) async {
    // Stub implementation. Proper join with transactions required for real tally.
    return 0.0;
  }

  Stream<void> watchAll() =>
      _d.select(_d.budgets).watch().map((_) {});
}
