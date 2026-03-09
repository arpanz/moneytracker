import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../domain/models/split_model.dart';

// ── Data Classes ────────────────────────────────────────────────────────────

/// Balance summary for a single participant across all splits.
class ParticipantBalance {
  final String name;
  final String? contact;
  final double totalOwed;
  final double totalSettled;
  final int splitCount;

  const ParticipantBalance({
    required this.name,
    this.contact,
    required this.totalOwed,
    required this.totalSettled,
    required this.splitCount,
  });

  double get outstanding => totalOwed - totalSettled;
  bool get isSettled => outstanding <= 0.01;
}

/// Aggregate stats for the split dashboard.
class SplitSummary {
  final int totalSplits;
  final int activeSplits;
  final double totalOwedToYou;
  final double totalSettled;

  const SplitSummary({
    required this.totalSplits,
    required this.activeSplits,
    required this.totalOwedToYou,
    required this.totalSettled,
  });

  static const empty = SplitSummary(
    totalSplits: 0,
    activeSplits: 0,
    totalOwedToYou: 0,
    totalSettled: 0,
  );
}

// ── Providers ───────────────────────────────────────────────────────────────

/// Real-time stream of all splits.
final splitListProvider = StreamProvider<List<SplitModel>>((ref) {
  final repo = ref.watch(splitRepositoryProvider);
  return repo.watchAll();
});

/// Active (unsettled) splits.
final activeSplitsProvider = Provider<List<SplitModel>>((ref) {
  final splits = ref.watch(splitListProvider).valueOrNull ?? [];
  return splits.where((s) => !s.isFullySettled).toList();
});

/// Settled splits for history.
final settledSplitsProvider = Provider<List<SplitModel>>((ref) {
  final splits = ref.watch(splitListProvider).valueOrNull ?? [];
  return splits.where((s) => s.isFullySettled).toList();
});

/// Dashboard summary.
final splitSummaryProvider = Provider<SplitSummary>((ref) {
  final splits = ref.watch(splitListProvider).valueOrNull ?? [];
  if (splits.isEmpty) return SplitSummary.empty;

  final active = splits.where((s) => !s.isFullySettled).length;
  double totalOwed = 0;
  double totalSettled = 0;

  for (final split in splits) {
    for (final p in split.participants) {
      totalOwed += p.amount;
      if (p.isSettled) totalSettled += p.amount;
    }
  }

  return SplitSummary(
    totalSplits: splits.length,
    activeSplits: active,
    totalOwedToYou: totalOwed - totalSettled,
    totalSettled: totalSettled,
  );
});

/// Aggregated balances per participant across all splits.
final participantBalancesProvider = Provider<List<ParticipantBalance>>((ref) {
  final splits = ref.watch(splitListProvider).valueOrNull ?? [];
  final Map<String, _BalanceAccumulator> balances = {};

  for (final split in splits) {
    for (final p in split.participants) {
      final key = p.name.toLowerCase().trim();
      final acc = balances.putIfAbsent(
        key,
        () => _BalanceAccumulator(name: p.name, contact: p.contact),
      );
      acc.totalOwed += p.amount;
      if (p.isSettled) acc.totalSettled += p.amount;
      acc.splitCount++;
    }
  }

  return balances.values
      .map((a) => ParticipantBalance(
            name: a.name,
            contact: a.contact,
            totalOwed: a.totalOwed,
            totalSettled: a.totalSettled,
            splitCount: a.splitCount,
          ))
      .toList()
    ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
});

/// Single split by ID.
final splitByIdProvider =
    FutureProvider.family<SplitModel?, int>((ref, id) async {
  final repo = ref.watch(splitRepositoryProvider);
  return repo.getById(id);
});

// ── Internal ────────────────────────────────────────────────────────────────

class _BalanceAccumulator {
  final String name;
  final String? contact;
  double totalOwed = 0;
  double totalSettled = 0;
  int splitCount = 0;

  _BalanceAccumulator({required this.name, this.contact});
}
