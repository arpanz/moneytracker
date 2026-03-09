import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../domain/models/subscription_model.dart';

// ── Data Classes ────────────────────────────────────────────────────────────

/// Groups a subscription with its computed monthly-normalised cost.
class SubscriptionWithCost {
  final SubscriptionModel subscription;
  final double monthlyCost;
  final int daysUntilNextBill;

  const SubscriptionWithCost({
    required this.subscription,
    required this.monthlyCost,
    required this.daysUntilNextBill,
  });

  double get yearlyCost => monthlyCost * 12;

  /// Human-readable frequency label.
  String get frequencyLabel {
    switch (subscription.frequency) {
      case 0:
        return 'Weekly';
      case 1:
        return 'Monthly';
      case 2:
        return 'Quarterly';
      case 3:
        return 'Yearly';
      default:
        return 'Monthly';
    }
  }

  /// True when the next bill is within 3 days.
  bool get isBillingSoon => daysUntilNextBill <= 3 && daysUntilNextBill >= 0;
}

/// Summary stats for the subscription dashboard header.
class SubscriptionSummary {
  final double totalMonthly;
  final double totalYearly;
  final int activeCount;
  final int upcomingBillsCount;
  final double avgMonthlyCost;

  const SubscriptionSummary({
    required this.totalMonthly,
    required this.totalYearly,
    required this.activeCount,
    required this.upcomingBillsCount,
    required this.avgMonthlyCost,
  });

  static const empty = SubscriptionSummary(
    totalMonthly: 0,
    totalYearly: 0,
    activeCount: 0,
    upcomingBillsCount: 0,
    avgMonthlyCost: 0,
  );
}

/// Insight about a potentially wasteful subscription.
class SubscriptionInsight {
  final SubscriptionModel subscription;
  final String reason;
  final double potentialSavings;

  const SubscriptionInsight({
    required this.subscription,
    required this.reason,
    required this.potentialSavings,
  });
}

// ── Providers ───────────────────────────────────────────────────────────────

/// Stream of all active subscriptions, kept in sync with the DB.
final subscriptionListProvider =
    StreamProvider<List<SubscriptionModel>>((ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.watchAll();
});

/// Enriched subscription list with computed costs and days-until-bill.
final subscriptionsWithCostProvider =
    Provider<List<SubscriptionWithCost>>((ref) {
  final subs = ref.watch(subscriptionListProvider).valueOrNull ?? [];
  final now = DateTime.now();

  return subs.map((s) {
    final monthly = _normaliseMonthlyCost(s.amount, s.frequency);
    final daysUntil = s.nextBillDate.difference(now).inDays;
    return SubscriptionWithCost(
      subscription: s,
      monthlyCost: monthly,
      daysUntilNextBill: daysUntil,
    );
  }).toList()
    ..sort((a, b) => a.daysUntilNextBill.compareTo(b.daysUntilNextBill));
});

/// Dashboard summary derived from the enriched list.
final subscriptionSummaryProvider = Provider<SubscriptionSummary>((ref) {
  final items = ref.watch(subscriptionsWithCostProvider);
  if (items.isEmpty) return SubscriptionSummary.empty;

  final totalMonthly =
      items.fold<double>(0, (sum, i) => sum + i.monthlyCost);
  final upcoming = items.where((i) => i.daysUntilNextBill <= 7).length;

  return SubscriptionSummary(
    totalMonthly: totalMonthly,
    totalYearly: totalMonthly * 12,
    activeCount: items.length,
    upcomingBillsCount: upcoming,
    avgMonthlyCost: totalMonthly / items.length,
  );
});

/// Subscriptions with the next bill coming up within 7 days.
final upcomingBillsProvider =
    Provider<List<SubscriptionWithCost>>((ref) {
  return ref
      .watch(subscriptionsWithCostProvider)
      .where((i) => i.daysUntilNextBill >= 0 && i.daysUntilNextBill <= 7)
      .toList();
});

/// Potentially wasteful subscriptions.
/// Heuristic: high-cost subs that were auto-detected, or subs costing
/// more than the average monthly cost.
final subscriptionInsightsProvider =
    Provider<List<SubscriptionInsight>>((ref) {
  final items = ref.watch(subscriptionsWithCostProvider);
  final summary = ref.watch(subscriptionSummaryProvider);
  if (items.isEmpty) return [];

  final insights = <SubscriptionInsight>[];

  for (final item in items) {
    // Flag auto-detected subs the user hasn't explicitly confirmed.
    if (item.subscription.isAutoDetected) {
      insights.add(SubscriptionInsight(
        subscription: item.subscription,
        reason: 'Auto-detected — verify this is still needed',
        potentialSavings: item.monthlyCost,
      ));
      continue;
    }

    // Flag subs that cost more than 2x the average.
    if (summary.avgMonthlyCost > 0 &&
        item.monthlyCost > summary.avgMonthlyCost * 2) {
      insights.add(SubscriptionInsight(
        subscription: item.subscription,
        reason: 'Costs ${(item.monthlyCost / summary.avgMonthlyCost).toStringAsFixed(1)}x your average subscription',
        potentialSavings: item.monthlyCost - summary.avgMonthlyCost,
      ));
    }
  }

  return insights;
});

/// Auto-detection trigger: scans recent transactions for recurring patterns.
final autoDetectSubscriptionsProvider =
    FutureProvider<List<SubscriptionModel>>((ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.detectFromTransactions(
    ref.watch(transactionRepositoryProvider),
  );
});

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Normalises any frequency to a monthly cost.
double _normaliseMonthlyCost(double amount, int frequency) {
  switch (frequency) {
    case 0: // weekly
      return amount * 4.33;
    case 1: // monthly
      return amount;
    case 2: // quarterly
      return amount / 3;
    case 3: // yearly
      return amount / 12;
    default:
      return amount;
  }
}
