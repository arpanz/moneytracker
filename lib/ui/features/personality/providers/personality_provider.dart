import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/asset_paths.dart';

// ── Enums ───────────────────────────────────────────────────────────────────

/// The six spending personality archetypes.
enum SpendingPersonality {
  foodie,
  nomad,
  shopaholic,
  saver,
  hustler,
  balanced,
}

// ── Data Classes ────────────────────────────────────────────────────────────

/// Complete personality analysis result for the current month.
class PersonalityData {
  final SpendingPersonality personality;
  final String title;
  final String emoji;
  final String description;
  final String svgPath;
  final Map<String, double> categoryPercentages;
  final double totalSpent;
  final String funFact;

  const PersonalityData({
    required this.personality,
    required this.title,
    required this.emoji,
    required this.description,
    required this.svgPath,
    required this.categoryPercentages,
    required this.totalSpent,
    required this.funFact,
  });

  /// Gradient colors for personality-specific backgrounds.
  List<Color> get gradientColors {
    switch (personality) {
      case SpendingPersonality.foodie:
        return [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)];
      case SpendingPersonality.nomad:
        return [const Color(0xFF0D9488), const Color(0xFF06B6D4)];
      case SpendingPersonality.shopaholic:
        return [const Color(0xFFEC4899), const Color(0xFFF472B6)];
      case SpendingPersonality.saver:
        return [const Color(0xFF22C55E), const Color(0xFF86EFAC)];
      case SpendingPersonality.hustler:
        return [const Color(0xFFF59E0B), const Color(0xFFFBBF24)];
      case SpendingPersonality.balanced:
        return [const Color(0xFF7C3AED), const Color(0xFFA78BFA)];
    }
  }
}

/// Weekly wrap summary data (Spotify Wrapped-style).
class WeeklyWrapData {
  final double totalSpent;
  final double totalIncome;
  final String topCategory;
  final double topCategoryAmount;
  final double topCategoryPercentage;
  final double biggestExpenseAmount;
  final String biggestExpenseName;
  final DateTime biggestExpenseDate;
  final int transactionCount;
  final double dailyAverage;
  final double savingsRate;
  final double comparedToLastWeek;
  final Map<int, double> dailyBreakdown;

  const WeeklyWrapData({
    required this.totalSpent,
    required this.totalIncome,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.topCategoryPercentage,
    required this.biggestExpenseAmount,
    required this.biggestExpenseName,
    required this.biggestExpenseDate,
    required this.transactionCount,
    required this.dailyAverage,
    required this.savingsRate,
    required this.comparedToLastWeek,
    required this.dailyBreakdown,
  });
}

// ── Personality Definitions ─────────────────────────────────────────────────

class _PersonalityDef {
  final String title;
  final String emoji;
  final String description;
  final String svgPath;
  final String funFact;

  const _PersonalityDef({
    required this.title,
    required this.emoji,
    required this.description,
    required this.svgPath,
    required this.funFact,
  });
}

const _personalityDefinitions = <SpendingPersonality, _PersonalityDef>{
  SpendingPersonality.foodie: _PersonalityDef(
    title: 'The Foodie',
    emoji: '🍕',
    description: 'Your taste buds run your wallet! Restaurants, takeout, '
        'and gourmet groceries dominate your spending.',
    svgPath: AssetPaths.personalityFoodie,
    funFact: 'You spend more on food than 80% of Cheddar users. '
        'Maybe meal prep could save you a bundle?',
  ),
  SpendingPersonality.nomad: _PersonalityDef(
    title: 'The Nomad',
    emoji: '✈️',
    description: 'Adventure calls and you answer! Travel and transport '
        'are your biggest expenses this month.',
    svgPath: AssetPaths.personalityNomad,
    funFact: 'Your travel spending could fund a weekend getaway '
        'every month. Living the dream!',
  ),
  SpendingPersonality.shopaholic: _PersonalityDef(
    title: 'The Shopaholic',
    emoji: '🛍️',
    description: 'Retail therapy is your love language. Shopping '
        "makes up the lion's share of your expenses.",
    svgPath: AssetPaths.personalityShopaholic,
    funFact: 'Try the 48-hour rule: wait 2 days before any '
        'non-essential purchase. Your wallet will thank you!',
  ),
  SpendingPersonality.saver: _PersonalityDef(
    title: 'The Saver',
    emoji: '🐷',
    description: "Your piggy bank is your best friend! You're putting "
        'away an impressive chunk toward savings and goals.',
    svgPath: AssetPaths.personalitySaver,
    funFact: "At this rate, you'll hit your savings goals ahead "
        'of schedule. Keep up the amazing discipline!',
  ),
  SpendingPersonality.hustler: _PersonalityDef(
    title: 'The Hustler',
    emoji: '💰',
    description: 'Money flows in like a river! Your income is growing '
        "and you're clearly making moves.",
    svgPath: AssetPaths.personalityHustler,
    funFact: 'Your income growth outpaces most. Channel that '
        'extra cash into investments for compound gains!',
  ),
  SpendingPersonality.balanced: _PersonalityDef(
    title: 'The Balanced One',
    emoji: '⚖️',
    description: "You're the zen master of money! No single category "
        'dominates -- you spread your spending wisely.',
    svgPath: AssetPaths.mascot,
    funFact: 'Balanced spenders tend to have the healthiest '
        "financial habits. You're doing great!",
  ),
};

// ── Providers ───────────────────────────────────────────────────────────────

/// Analyzes the current month's spending to determine spending personality.
final personalityProvider = FutureProvider<PersonalityData>((ref) async {
  final txnRepo = ref.watch(transactionRepositoryProvider);
  final goalRepo = ref.watch(goalRepositoryProvider);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Fetch category totals for expenses this month
  final categoryTotals = await txnRepo.getCategoryTotals(monthStart, monthEnd);
  final totalExpense = categoryTotals.values.fold<double>(
    0.0,
    (sum, v) => sum + v,
  );

  // Calculate income for this month
  final totalIncome = await txnRepo.getTotalByType(0, monthStart, monthEnd);

  // Calculate previous month income for growth comparison
  final prevMonthStart = DateTime(now.year, now.month - 1, 1);
  final prevMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
  final prevIncome =
      await txnRepo.getTotalByType(0, prevMonthStart, prevMonthEnd);

  // Total saved in goals this month
  final activeGoals = await goalRepo.getActive();
  double goalContributions = 0.0;
  for (final goal in activeGoals) {
    for (final c in goal.contributions) {
      if (c.date.isAfter(monthStart) && c.date.isBefore(monthEnd)) {
        goalContributions += c.amount;
      }
    }
  }

  // Calculate category percentages
  final categoryPercentages = <String, double>{};
  for (final entry in categoryTotals.entries) {
    categoryPercentages[entry.key] =
        totalExpense > 0 ? (entry.value / totalExpense) * 100 : 0;
  }

  // Determine personality based on thresholds
  final foodPct = _getCategoryPct(categoryPercentages, ['Food', 'Groceries']);
  final travelPct =
      _getCategoryPct(categoryPercentages, ['Travel', 'Transport']);
  final shoppingPct = _getCategoryPct(categoryPercentages, ['Shopping']);
  final savingsRatio = totalIncome > 0
      ? (goalContributions + (totalIncome - totalExpense)) / totalIncome
      : 0.0;
  final incomeGrowth =
      prevIncome > 0 ? ((totalIncome - prevIncome) / prevIncome) * 100 : 0.0;

  SpendingPersonality personality;
  if (foodPct > 35) {
    personality = SpendingPersonality.foodie;
  } else if (travelPct > 25) {
    personality = SpendingPersonality.nomad;
  } else if (shoppingPct > 30) {
    personality = SpendingPersonality.shopaholic;
  } else if (savingsRatio > 0.40) {
    personality = SpendingPersonality.saver;
  } else if (incomeGrowth > 20) {
    personality = SpendingPersonality.hustler;
  } else {
    personality = SpendingPersonality.balanced;
  }

  final def = _personalityDefinitions[personality]!;

  return PersonalityData(
    personality: personality,
    title: def.title,
    emoji: def.emoji,
    description: def.description,
    svgPath: def.svgPath,
    categoryPercentages: categoryPercentages,
    totalSpent: totalExpense,
    funFact: def.funFact,
  );
});

/// Weekly wrap data provider for the past 7 days.
final weeklyWrapProvider = FutureProvider<WeeklyWrapData>((ref) async {
  final txnRepo = ref.watch(transactionRepositoryProvider);

  final now = DateTime.now();
  final weekStart =
      DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final weekEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

  // Previous week for comparison
  final prevWeekStart = weekStart.subtract(const Duration(days: 7));
  final prevWeekEnd = weekStart.subtract(const Duration(seconds: 1));

  // Current week data
  final transactions = await txnRepo.getByDateRange(weekStart, weekEnd);
  final expenses = transactions.where((t) => t.type == 1).toList();
  final incomes = transactions.where((t) => t.type == 0).toList();

  final totalSpent = expenses.fold<double>(0.0, (s, t) => s + t.amount);
  final totalIncome = incomes.fold<double>(0.0, (s, t) => s + t.amount);

  // Previous week spending for comparison
  final prevTxns = await txnRepo.getByDateRange(prevWeekStart, prevWeekEnd);
  final prevSpent =
      prevTxns.where((t) => t.type == 1).fold<double>(0.0, (s, t) => s + t.amount);

  // Category breakdown
  final catTotals = <String, double>{};
  for (final t in expenses) {
    catTotals[t.category] = (catTotals[t.category] ?? 0.0) + t.amount;
  }

  String topCategory = 'None';
  double topCatAmount = 0;
  for (final entry in catTotals.entries) {
    if (entry.value > topCatAmount) {
      topCatAmount = entry.value;
      topCategory = entry.key;
    }
  }
  final topCatPct = totalSpent > 0 ? (topCatAmount / totalSpent) * 100 : 0.0;

  // Biggest single expense
  double biggestAmount = 0;
  String biggestName = 'None';
  DateTime biggestDate = now;
  for (final t in expenses) {
    if (t.amount > biggestAmount) {
      biggestAmount = t.amount;
      biggestName = t.note ?? t.category;
      biggestDate = t.date;
    }
  }

  // Daily breakdown (0 = first day of the week window, 6 = today)
  final dailyBreakdown = <int, double>{};
  for (int i = 0; i < 7; i++) {
    dailyBreakdown[i] = 0.0;
  }
  for (final t in expenses) {
    final dayIndex = t.date.difference(weekStart).inDays.clamp(0, 6);
    dailyBreakdown[dayIndex] = (dailyBreakdown[dayIndex] ?? 0.0) + t.amount;
  }

  final dailyAverage = totalSpent / 7.0;
  final savingsRate =
      totalIncome > 0 ? ((totalIncome - totalSpent) / totalIncome) * 100 : 0.0;
  final comparedToLastWeek =
      prevSpent > 0 ? ((totalSpent - prevSpent) / prevSpent) * 100 : 0.0;

  return WeeklyWrapData(
    totalSpent: totalSpent,
    totalIncome: totalIncome,
    topCategory: topCategory,
    topCategoryAmount: topCatAmount,
    topCategoryPercentage: topCatPct,
    biggestExpenseAmount: biggestAmount,
    biggestExpenseName: biggestName,
    biggestExpenseDate: biggestDate,
    transactionCount: transactions.length,
    dailyAverage: dailyAverage,
    savingsRate: savingsRate,
    comparedToLastWeek: comparedToLastWeek,
    dailyBreakdown: dailyBreakdown,
  );
});

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Sums percentages for multiple related category names.
double _getCategoryPct(
  Map<String, double> percentages,
  List<String> categoryNames,
) {
  double total = 0.0;
  for (final entry in percentages.entries) {
    for (final name in categoryNames) {
      if (entry.key.toLowerCase().contains(name.toLowerCase())) {
        total += entry.value;
      }
    }
  }
  return total;
}
