import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../domain/models/goal_model.dart';

// ── Data Classes ────────────────────────────────────────────────────────────

/// Enriched goal with computed progress metrics.
class GoalWithProgress {
  final GoalModel goal;
  final double percentage;
  final double remaining;
  final int daysLeft;
  final double dailySuggestion;
  final double weeklySuggestion;
  final GoalStatus status;

  const GoalWithProgress({
    required this.goal,
    required this.percentage,
    required this.remaining,
    required this.daysLeft,
    required this.dailySuggestion,
    required this.weeklySuggestion,
    required this.status,
  });
}

enum GoalStatus {
  /// On track or ahead of schedule.
  onTrack,

  /// Behind the linear pace to reach the deadline.
  behind,

  /// Deadline has passed and goal is not reached.
  overdue,

  /// Goal reached!
  completed,
}

/// Aggregate stats shown at the top of the goals screen.
class GoalsSummary {
  final int totalGoals;
  final int completedGoals;
  final double totalSaved;
  final double totalTarget;
  final double overallPercentage;

  const GoalsSummary({
    required this.totalGoals,
    required this.completedGoals,
    required this.totalSaved,
    required this.totalTarget,
    required this.overallPercentage,
  });

  static const empty = GoalsSummary(
    totalGoals: 0,
    completedGoals: 0,
    totalSaved: 0,
    totalTarget: 0,
    overallPercentage: 0,
  );
}

// ── Providers ───────────────────────────────────────────────────────────────

/// Real-time stream of all goals.
final goalListProvider = StreamProvider<List<GoalModel>>((ref) async* {
  final repo = ref.watch(goalRepositoryProvider);
  // Emit current data immediately
  yield await repo.getAll();
  // Then re-fetch on every change notification
  await for (final _ in repo.watchAll()) {
    yield await repo.getAll();
  }
});

/// Enriched goals with progress calculations.
final goalsWithProgressProvider = Provider<List<GoalWithProgress>>((ref) {
  final goals = ref.watch(goalListProvider).value ?? [];
  final now = DateTime.now();

  return goals.map((g) {
    final pct = g.targetAmount > 0
        ? (g.currentAmount / g.targetAmount * 100).clamp(0.0, 100.0)
        : 0.0;
    final remaining = (g.targetAmount - g.currentAmount).clamp(0, double.infinity);
    final daysLeft = g.deadline.difference(now).inDays;
    final isComplete = g.currentAmount >= g.targetAmount;

    GoalStatus status;
    if (isComplete) {
      status = GoalStatus.completed;
    } else if (daysLeft < 0) {
      status = GoalStatus.overdue;
    } else {
      // Check if on track: linear pace
      final totalDays = g.deadline.difference(g.createdAt).inDays.clamp(1, 36500);
      final daysPassed = now.difference(g.createdAt).inDays.clamp(1, totalDays);
      final expectedPct = (daysPassed / totalDays) * 100;
      status = pct >= expectedPct * 0.85 ? GoalStatus.onTrack : GoalStatus.behind;
    }

    final daily = daysLeft > 0 ? remaining / daysLeft : remaining;
    final weekly = daysLeft > 7 ? remaining / (daysLeft / 7) : remaining;

    return GoalWithProgress(
      goal: g,
      percentage: pct,
      remaining: remaining,
      daysLeft: daysLeft,
      dailySuggestion: daily,
      weeklySuggestion: weekly,
      status: status,
    );
  }).toList()
    ..sort((a, b) {
      // Completed last, then by deadline
      if (a.status == GoalStatus.completed && b.status != GoalStatus.completed) return 1;
      if (b.status == GoalStatus.completed && a.status != GoalStatus.completed) return -1;
      return a.goal.deadline.compareTo(b.goal.deadline);
    });
});

/// Summary statistics for the goals dashboard.
final goalsSummaryProvider = Provider<GoalsSummary>((ref) {
  final goals = ref.watch(goalsWithProgressProvider);
  if (goals.isEmpty) return GoalsSummary.empty;

  final totalSaved = goals.fold<double>(0, (s, g) => s + g.goal.currentAmount);
  final totalTarget = goals.fold<double>(0, (s, g) => s + g.goal.targetAmount);
  final completed = goals.where((g) => g.status == GoalStatus.completed).length;

  return GoalsSummary(
    totalGoals: goals.length,
    completedGoals: completed,
    totalSaved: totalSaved,
    totalTarget: totalTarget,
    overallPercentage:
        totalTarget > 0 ? (totalSaved / totalTarget * 100).clamp(0, 100) : 0,
  );
});

/// Active (non-completed) goals for quick-add from home screen.
final activeGoalsProvider = Provider<List<GoalWithProgress>>((ref) {
  return ref
      .watch(goalsWithProgressProvider)
      .where((g) => g.status != GoalStatus.completed)
      .toList();
});

/// Single goal by ID for detail screen.
final goalByIdProvider =
    FutureProvider.family<GoalModel?, int>((ref, id) async {
  final repo = ref.watch(goalRepositoryProvider);
  return repo.getById(id);
});
