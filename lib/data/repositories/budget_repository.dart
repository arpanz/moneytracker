import 'package:isar/isar.dart';

import '../../domain/models/budget_model.dart';
import '../../domain/models/transaction_model.dart';
import '../local/database_service.dart';

/// Repository for managing category-based spending budgets.
///
/// Provides CRUD operations, active budget queries, and spent-amount
/// calculations that cross-reference the transaction collection.
class BudgetRepository {
  final DatabaseService _db;

  BudgetRepository(this._db);

  Isar get _isar => _db.isar;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserts a new budget and returns its auto-generated id.
  Future<int> add(BudgetModel budget) async {
    return _isar.writeTxn(() async {
      return _isar.budgetModels.put(budget);
    });
  }

  /// Updates an existing budget in-place.
  Future<void> update(BudgetModel budget) async {
    await _isar.writeTxn(() async {
      await _isar.budgetModels.put(budget);
    });
  }

  /// Deletes a budget by its id.
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.budgetModels.delete(id);
    });
  }

  /// Retrieves a single budget by id, or null if not found.
  Future<BudgetModel?> getById(int id) async {
    return _isar.budgetModels.get(id);
  }

  /// Returns all budgets.
  Future<List<BudgetModel>> getAll() async {
    return _isar.budgetModels.where().findAll();
  }

  // ── FILTERED QUERIES ─────────────────────────────────────────────────────

  /// Finds the budget for a specific category (returns first match).
  Future<BudgetModel?> getByCategory(String category) async {
    return _isar.budgetModels
        .where()
        .categoryEqualTo(category)
        .filter()
        .isActiveEqualTo(true)
        .findFirst();
  }

  /// Returns all currently active budgets.
  Future<List<BudgetModel>> getActive() async {
    return _isar.budgetModels
        .filter()
        .isActiveEqualTo(true)
        .findAll();
  }

  // ── SPENT CALCULATION ────────────────────────────────────────────────────

  /// Calculates how much has been spent for a given budget in its current period.
  ///
  /// Determines the period window (weekly/monthly/yearly) from the budget's
  /// [startDate] and [period], then sums all expense transactions (type == 1)
  /// matching the budget's category within that window.
  Future<double> getSpentForBudget(BudgetModel budget) async {
    final now = DateTime.now();
    final periodStart = _calculatePeriodStart(budget, now);
    final periodEnd = _calculatePeriodEnd(periodStart, budget.period);

    final transactions = await _isar.transactionModels
        .where()
        .dateBetween(periodStart, periodEnd)
        .filter()
        .typeEqualTo(1) // expense
        .categoryEqualTo(budget.category)
        .findAll();

    return transactions.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Finds the most recent period start that is <= [now] based on the budget's
  /// start date and period frequency.
  DateTime _calculatePeriodStart(BudgetModel budget, DateTime now) {
    var periodStart = budget.startDate;

    switch (budget.period) {
      case 0: // weekly
        while (periodStart.add(const Duration(days: 7)).isBefore(now)) {
          periodStart = periodStart.add(const Duration(days: 7));
        }
        break;
      case 1: // monthly
        while (DateTime(periodStart.year, periodStart.month + 1, periodStart.day)
            .isBefore(now)) {
          periodStart = DateTime(
            periodStart.year,
            periodStart.month + 1,
            periodStart.day,
          );
        }
        break;
      case 2: // yearly
        while (DateTime(periodStart.year + 1, periodStart.month, periodStart.day)
            .isBefore(now)) {
          periodStart = DateTime(
            periodStart.year + 1,
            periodStart.month,
            periodStart.day,
          );
        }
        break;
    }

    return periodStart;
  }

  /// Returns the end of the period starting at [periodStart].
  DateTime _calculatePeriodEnd(DateTime periodStart, int period) {
    switch (period) {
      case 0: // weekly
        return periodStart.add(const Duration(days: 7));
      case 1: // monthly
        return DateTime(
          periodStart.year,
          periodStart.month + 1,
          periodStart.day,
        );
      case 2: // yearly
        return DateTime(
          periodStart.year + 1,
          periodStart.month,
          periodStart.day,
        );
      default:
        return periodStart.add(const Duration(days: 30));
    }
  }

  // ── REAL-TIME STREAM ─────────────────────────────────────────────────────

  /// Watches the entire budget collection for any changes.
  Stream<void> watchAll() {
    return _isar.budgetModels.watchLazy();
  }
}
