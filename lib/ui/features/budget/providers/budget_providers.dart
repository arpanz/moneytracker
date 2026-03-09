import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../domain/models/budget_model.dart';

// ── Enums & Data Classes ────────────────────────────────────────────────────

/// Status of a budget based on spending relative to its limit.
enum BudgetStatus {
  /// Spending is below 80% of the budget limit.
  underBudget,

  /// Spending is between 80% and 100% of the budget limit.
  warning,

  /// Spending has exceeded the budget limit.
  overBudget,
}

/// Combines a [BudgetModel] with its computed spending data.
class BudgetWithSpending {
  final BudgetModel budget;
  final double spent;
  final double percentage;
  final BudgetStatus status;

  const BudgetWithSpending({
    required this.budget,
    required this.spent,
    required this.percentage,
    required this.status,
  });

  double get remaining => (budget.limitAmount - spent).clamp(0, double.infinity);

  int get daysRemaining {
    final now = DateTime.now();
    final periodEnd = _calculatePeriodEnd(budget);
    final diff = periodEnd.difference(now).inDays;
    return diff.clamp(0, 365);
  }

  double get dailyAverage {
    final now = DateTime.now();
    final periodStart = _calculateCurrentPeriodStart(budget);
    final daysPassed = now.difference(periodStart).inDays.clamp(1, 365);
    return spent / daysPassed;
  }

  double get projectedSpend {
    final totalDays = _totalDaysInPeriod(budget);
    if (totalDays <= 0) return spent;
    final now = DateTime.now();
    final periodStart = _calculateCurrentPeriodStart(budget);
    final daysPassed = now.difference(periodStart).inDays.clamp(1, totalDays);
    return (spent / daysPassed) * totalDays;
  }

  static DateTime _calculateCurrentPeriodStart(BudgetModel budget) {
    final now = DateTime.now();
    var periodStart = budget.startDate;

    switch (budget.period) {
      case 0: // weekly
        while (periodStart.add(const Duration(days: 7)).isBefore(now)) {
          periodStart = periodStart.add(const Duration(days: 7));
        }
      case 1: // monthly
        while (DateTime(periodStart.year, periodStart.month + 1, periodStart.day)
            .isBefore(now)) {
          periodStart = DateTime(
            periodStart.year,
            periodStart.month + 1,
            periodStart.day,
          );
        }
      case 2: // yearly
        while (DateTime(periodStart.year + 1, periodStart.month, periodStart.day)
            .isBefore(now)) {
          periodStart = DateTime(
            periodStart.year + 1,
            periodStart.month,
            periodStart.day,
          );
        }
    }
    return periodStart;
  }

  static DateTime _calculatePeriodEnd(BudgetModel budget) {
    final start = _calculateCurrentPeriodStart(budget);
    switch (budget.period) {
      case 0:
        return start.add(const Duration(days: 7));
      case 1:
        return DateTime(start.year, start.month + 1, start.day);
      case 2:
        return DateTime(start.year + 1, start.month, start.day);
      default:
        return start.add(const Duration(days: 30));
    }
  }

  static int _totalDaysInPeriod(BudgetModel budget) {
    final start = _calculateCurrentPeriodStart(budget);
    final end = _calculatePeriodEnd(budget);
    return end.difference(start).inDays;
  }
}

/// Represents a category with spending but no associated budget.
class UnbudgetedCategory {
  final String category;
  final double totalSpent;

  const UnbudgetedCategory({
    required this.category,
    required this.totalSpent,
  });
}

// ── Providers ───────────────────────────────────────────────────────────────

/// All active budgets from the repository.
final allBudgetsProvider =
    FutureProvider<List<BudgetModel>>((ref) async {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.getActive();
});

/// Retrieves a single budget by its Isar id.
final budgetByIdProvider =
    FutureProvider.family<BudgetModel?, int>((ref, id) async {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.getById(id);
});

/// Combines each active budget with its spent amount and status.
final budgetWithSpendingProvider =
    FutureProvider<List<BudgetWithSpending>>((ref) async {
  final budgetRepo = ref.watch(budgetRepositoryProvider);
  final budgets = await ref.watch(allBudgetsProvider.future);

  final results = <BudgetWithSpending>[];
  for (final budget in budgets) {
    final spent = await budgetRepo.getSpentForBudget(budget);
    final percentage =
        budget.limitAmount > 0 ? spent / budget.limitAmount : 0.0;

    final BudgetStatus status;
    if (percentage >= 1.0) {
      status = BudgetStatus.overBudget;
    } else if (percentage >= 0.8) {
      status = BudgetStatus.warning;
    } else {
      status = BudgetStatus.underBudget;
    }

    results.add(BudgetWithSpending(
      budget: budget,
      spent: spent,
      percentage: percentage,
      status: status,
    ));
  }

  // Sort: over-budget first, then warning, then under-budget
  results.sort((a, b) => b.percentage.compareTo(a.percentage));
  return results;
});

/// Categories with spending in the current month but no active budget.
final unbudgetedSpendingProvider =
    FutureProvider<List<UnbudgetedCategory>>((ref) async {
  final txnRepo = ref.watch(transactionRepositoryProvider);
  final budgets = await ref.watch(allBudgetsProvider.future);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  final categoryTotals = await txnRepo.getCategoryTotals(monthStart, monthEnd);
  final budgetedCategories = budgets.map((b) => b.category).toSet();

  final unbudgeted = <UnbudgetedCategory>[];
  for (final entry in categoryTotals.entries) {
    if (!budgetedCategories.contains(entry.key)) {
      unbudgeted.add(UnbudgetedCategory(
        category: entry.key,
        totalSpent: entry.value,
      ));
    }
  }

  unbudgeted.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
  return unbudgeted;
});

/// Daily spending breakdown for a specific budget's category within its period.
/// Returns `Map<DateTime, double>` (day-only keys) for chart display.
final dailySpendingForBudgetProvider =
    FutureProvider.family<Map<DateTime, double>, int>(
        (ref, budgetId) async {
  final budgetRepo = ref.watch(budgetRepositoryProvider);
  final txnRepo = ref.watch(transactionRepositoryProvider);

  final budget = await budgetRepo.getById(budgetId);
  if (budget == null) return {};

  final now = DateTime.now();
  final periodStart = BudgetWithSpending._calculateCurrentPeriodStart(budget);
  final periodEnd = BudgetWithSpending._calculatePeriodEnd(budget);
  final endDate = now.isBefore(periodEnd) ? now : periodEnd;

  final transactions = await txnRepo.getByDateRange(periodStart, endDate);
  final filtered = transactions
      .where((t) => t.type == 1 && t.category == budget.category)
      .toList();

  final dailyMap = <DateTime, double>{};
  for (final txn in filtered) {
    final dayKey = DateTime(txn.date.year, txn.date.month, txn.date.day);
    dailyMap[dayKey] = (dailyMap[dayKey] ?? 0.0) + txn.amount;
  }

  return dailyMap;
});

/// Watches the budget collection for real-time updates.
final budgetStreamProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.watchAll();
});

// ── Mutation Providers ──────────────────────────────────────────────────────

/// Adds a new budget and invalidates caches.
final addBudgetProvider =
    FutureProvider.family<int, BudgetModel>((ref, budget) async {
  final repo = ref.read(budgetRepositoryProvider);
  final id = await repo.add(budget);
  ref.invalidate(allBudgetsProvider);
  ref.invalidate(budgetWithSpendingProvider);
  ref.invalidate(unbudgetedSpendingProvider);
  return id;
});

/// Updates an existing budget and invalidates caches.
final updateBudgetProvider =
    FutureProvider.family<void, BudgetModel>((ref, budget) async {
  final repo = ref.read(budgetRepositoryProvider);
  await repo.update(budget);
  ref.invalidate(allBudgetsProvider);
  ref.invalidate(budgetWithSpendingProvider);
  ref.invalidate(unbudgetedSpendingProvider);
  ref.invalidate(budgetByIdProvider(budget.id));
  ref.invalidate(dailySpendingForBudgetProvider(budget.id));
});

/// Deletes a budget by id and invalidates caches.
final deleteBudgetProvider =
    FutureProvider.family<void, int>((ref, id) async {
  final repo = ref.read(budgetRepositoryProvider);
  await repo.delete(id);
  ref.invalidate(allBudgetsProvider);
  ref.invalidate(budgetWithSpendingProvider);
  ref.invalidate(unbudgetedSpendingProvider);
});
