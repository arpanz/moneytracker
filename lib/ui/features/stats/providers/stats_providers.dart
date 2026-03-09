import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/theme/theme_provider.dart';
import '../../../../config/theme/vibe_themes.dart';

// ── Enums ───────────────────────────────────────────────────────────────────

/// Time period options for statistics display.
enum PeriodType { week, month, year, custom }

// ── Data Classes ────────────────────────────────────────────────────────────

/// Monthly income vs expense comparison data point.
class MonthlyComparison {
  final String monthLabel;
  final double income;
  final double expense;

  const MonthlyComparison({
    required this.monthLabel,
    required this.income,
    required this.expense,
  });
}

/// Category breakdown data for pie chart and ranking.
class CategoryTotal {
  final String category;
  final double amount;
  final double percentage;
  final Color color;

  const CategoryTotal({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.color,
  });
}

// ── Providers ───────────────────────────────────────────────────────────────

/// Currently selected date range for statistics.
final dateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, 1),
    end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
  );
});

/// Currently selected period type.
final periodTypeProvider = StateProvider<PeriodType>((ref) => PeriodType.month);

/// Spending trend data points for the line chart.
/// Returns `List<FlSpot>` where x = day index, y = cumulative/daily spending.
final spendingTrendProvider = FutureProvider<List<FlSpot>>((ref) async {
  final txnRepo = ref.watch(transactionRepositoryProvider);
  final range = ref.watch(dateRangeProvider);

  final transactions = await txnRepo.getByDateRange(range.start, range.end);
  final expenses = transactions.where((t) => t.type == 1).toList();

  // Group by day
  final dailyMap = <int, double>{};
  for (final txn in expenses) {
    final dayIndex = txn.date.difference(range.start).inDays;
    dailyMap[dayIndex] = (dailyMap[dayIndex] ?? 0.0) + txn.amount;
  }

  final totalDays = range.end.difference(range.start).inDays + 1;
  final spots = <FlSpot>[];

  for (int i = 0; i < totalDays; i++) {
    spots.add(FlSpot(i.toDouble(), dailyMap[i] ?? 0.0));
  }

  return spots;
});

/// Category breakdown for the pie chart.
/// Returns `List<CategoryTotal>` sorted by amount descending.
final categoryBreakdownProvider = FutureProvider<List<CategoryTotal>>((
  ref,
) async {
  final txnRepo = ref.watch(transactionRepositoryProvider);
  final range = ref.watch(dateRangeProvider);
  final themeState = ref.watch(themeProvider);

  final totals = await txnRepo.getCategoryTotals(range.start, range.end);
  if (totals.isEmpty) return [];

  final grandTotal = totals.values.fold<double>(0.0, (sum, v) => sum + v);
  final chartColors = themeState.vibeTheme.data.chartColors;

  final categories = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return categories.asMap().entries.map((entry) {
    final i = entry.key;
    final cat = entry.value;
    return CategoryTotal(
      category: cat.key,
      amount: cat.value,
      percentage: grandTotal > 0 ? (cat.value / grandTotal) * 100 : 0,
      color: chartColors[i % chartColors.length],
    );
  }).toList();
});

/// Income vs expense comparison for the last 6 months.
final incomeVsExpenseProvider = FutureProvider<List<MonthlyComparison>>((
  ref,
) async {
  final txnRepo = ref.watch(transactionRepositoryProvider);
  final now = DateTime.now();

  final results = <MonthlyComparison>[];
  final monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  for (int i = 5; i >= 0; i--) {
    final monthDate = DateTime(now.year, now.month - i, 1);
    final monthStart = DateTime(monthDate.year, monthDate.month, 1);
    final monthEnd = DateTime(
      monthDate.year,
      monthDate.month + 1,
      0,
      23,
      59,
      59,
    );

    final income = await txnRepo.getTotalByType(0, monthStart, monthEnd);
    final expense = await txnRepo.getTotalByType(1, monthStart, monthEnd);

    results.add(
      MonthlyComparison(
        monthLabel: monthNames[monthDate.month - 1],
        income: income,
        expense: expense,
      ),
    );
  }

  return results;
});

/// Daily spending map for the heatmap calendar.
/// Returns `Map<DateTime, double>` keyed by day-only dates.
final dailySpendingMapProvider = FutureProvider<Map<DateTime, double>>((
  ref,
) async {
  final txnRepo = ref.watch(transactionRepositoryProvider);
  final range = ref.watch(dateRangeProvider);

  final transactions = await txnRepo.getByDateRange(range.start, range.end);
  final expenses = transactions.where((t) => t.type == 1).toList();

  final dailyMap = <DateTime, double>{};
  for (final txn in expenses) {
    final dayKey = DateTime(txn.date.year, txn.date.month, txn.date.day);
    dailyMap[dayKey] = (dailyMap[dayKey] ?? 0.0) + txn.amount;
  }

  return dailyMap;
});

/// Top spending categories sorted by amount (for horizontal bar chart).
final topCategoriesProvider = FutureProvider<List<CategoryTotal>>((ref) async {
  final allCategories = await ref.watch(categoryBreakdownProvider.future);
  return allCategories.take(8).toList();
});

/// Watches the transaction collection for real-time updates to stats.
final statsTransactionStreamProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAll();
});
