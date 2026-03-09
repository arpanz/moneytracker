import 'package:isar/isar.dart';

import '../../domain/models/subscription_model.dart';
import '../../domain/models/transaction_model.dart';
import '../local/database_service.dart';

/// Repository for managing recurring subscriptions and bills.
///
/// Provides CRUD operations, upcoming bill queries, cost projections,
/// basic auto-detection from transaction patterns, and a real-time watch stream.
class SubscriptionRepository {
  final DatabaseService _db;

  SubscriptionRepository(this._db);

  Isar get _isar => _db.isar;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserts a new subscription and returns its auto-generated id.
  Future<int> add(SubscriptionModel subscription) async {
    return _isar.writeTxn(() async {
      return _isar.subscriptionModels.put(subscription);
    });
  }

  /// Updates an existing subscription in-place.
  Future<void> update(SubscriptionModel subscription) async {
    await _isar.writeTxn(() async {
      await _isar.subscriptionModels.put(subscription);
    });
  }

  /// Deletes a subscription by its id.
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.subscriptionModels.delete(id);
    });
  }

  /// Retrieves a single subscription by id, or null if not found.
  Future<SubscriptionModel?> getById(int id) async {
    return _isar.subscriptionModels.get(id);
  }

  /// Returns all subscriptions ordered by next bill date.
  Future<List<SubscriptionModel>> getAll() async {
    return _isar.subscriptionModels
        .where()
        .sortByNextBillDate()
        .findAll();
  }

  // ── FILTERED QUERIES ─────────────────────────────────────────────────────

  /// Returns all active subscriptions.
  Future<List<SubscriptionModel>> getActive() async {
    return _isar.subscriptionModels
        .where()
        .isActiveEqualTo(true)
        .sortByNextBillDate()
        .findAll();
  }

  /// Returns active subscriptions with a bill due within the next [days] days.
  Future<List<SubscriptionModel>> getUpcoming(int days) async {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));

    return _isar.subscriptionModels
        .where()
        .isActiveEqualTo(true)
        .filter()
        .nextBillDateBetween(now, cutoff)
        .sortByNextBillDate()
        .findAll();
  }

  // ── COST PROJECTIONS ─────────────────────────────────────────────────────

  /// Calculates the total monthly cost of all active subscriptions.
  ///
  /// Normalizes each subscription's amount to a monthly equivalent:
  /// - Weekly: amount * 4.33
  /// - Monthly: amount * 1
  /// - Quarterly: amount / 3
  /// - Yearly: amount / 12
  Future<double> getMonthlyTotal() async {
    final subs = await getActive();
    double total = 0.0;
    for (final sub in subs) {
      total += _toMonthly(sub.amount, sub.frequency);
    }
    return total;
  }

  /// Calculates the total yearly cost of all active subscriptions.
  Future<double> getYearlyTotal() async {
    final monthly = await getMonthlyTotal();
    return monthly * 12;
  }

  /// Converts a subscription amount to its monthly equivalent.
  double _toMonthly(double amount, int frequency) {
    switch (frequency) {
      case 0: // weekly
        return amount * 4.33;
      case 1: // monthly
        return amount;
      case 2: // quarterly
        return amount / 3.0;
      case 3: // yearly
        return amount / 12.0;
      default:
        return amount;
    }
  }

  // ── AUTO-DETECTION ───────────────────────────────────────────────────────

  /// Attempts to detect recurring subscriptions from transaction history.
  ///
  /// Groups transactions by note/category, identifies those that appear
  /// at roughly monthly intervals with consistent amounts, and creates
  /// subscription entries for any detected patterns.
  ///
  /// Detected subscriptions are marked with [isAutoDetected] = true.
  Future<void> detectFromTransactions(
    List<TransactionModel> transactions,
  ) async {
    // Only consider expense transactions with a note
    final expenses = transactions
        .where((t) => t.type == 1 && t.note != null && t.note!.isNotEmpty)
        .toList();

    // Group by note (normalized to lowercase)
    final grouped = <String, List<TransactionModel>>{};
    for (final t in expenses) {
      final key = t.note!.toLowerCase().trim();
      grouped.putIfAbsent(key, () => []).add(t);
    }

    final detected = <SubscriptionModel>[];

    for (final entry in grouped.entries) {
      final txns = entry.value;
      if (txns.length < 2) continue;

      // Sort by date ascending
      txns.sort((a, b) => a.date.compareTo(b.date));

      // Check for consistent amounts (within 5% tolerance)
      final amounts = txns.map((t) => t.amount).toList();
      final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
      final isConsistentAmount = amounts.every(
        (a) => (a - avgAmount).abs() / avgAmount < 0.05,
      );
      if (!isConsistentAmount) continue;

      // Check for roughly monthly intervals (25-35 days)
      final intervals = <int>[];
      for (int i = 1; i < txns.length; i++) {
        intervals.add(txns[i].date.difference(txns[i - 1].date).inDays);
      }
      final avgInterval =
          intervals.reduce((a, b) => a + b) / intervals.length;

      int detectedFrequency;
      if (avgInterval >= 5 && avgInterval <= 9) {
        detectedFrequency = 0; // weekly
      } else if (avgInterval >= 25 && avgInterval <= 35) {
        detectedFrequency = 1; // monthly
      } else if (avgInterval >= 80 && avgInterval <= 100) {
        detectedFrequency = 2; // quarterly
      } else if (avgInterval >= 350 && avgInterval <= 380) {
        detectedFrequency = 3; // yearly
      } else {
        continue; // not a recognizable pattern
      }

      // Check if subscription already exists
      final existing = await _isar.subscriptionModels
          .filter()
          .nameEqualTo(entry.key, caseSensitive: false)
          .findFirst();
      if (existing != null) continue;

      // Project next bill date from last transaction + interval
      final lastDate = txns.last.date;
      final nextBill = lastDate.add(Duration(days: avgInterval.round()));

      final sub = SubscriptionModel()
        ..name = txns.first.note!
        ..amount = avgAmount
        ..frequency = detectedFrequency
        ..nextBillDate = nextBill
        ..category = txns.first.category
        ..isActive = true
        ..isAutoDetected = true
        ..createdAt = DateTime.now();

      detected.add(sub);
    }

    if (detected.isNotEmpty) {
      await _isar.writeTxn(() async {
        await _isar.subscriptionModels.putAll(detected);
      });
    }
  }

  // ── REAL-TIME STREAM ─────────────────────────────────────────────────────

  /// Watches the entire subscription collection for any changes.
  Stream<void> watchAll() {
    return _isar.subscriptionModels.watchLazy();
  }
}
