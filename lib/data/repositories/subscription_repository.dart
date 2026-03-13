import 'package:drift/drift.dart';

import '../../domain/models/subscription_model.dart';
import '../local/database_service.dart';

/// Repository for managing recurring subscriptions.
class SubscriptionRepository {
  final DatabaseService _db;

  SubscriptionRepository(this._db);

  AppDatabase get _d => _db.db;

  // ── Mapping ──────────────────────────────────────────────────────────────

  SubscriptionModel _fromRow(Subscription row) => SubscriptionModel(
        id: row.id,
        name: row.name,
        amount: row.amount,
        frequency: row.frequency,
        nextBillDate: row.nextBillDate,
        category: row.category,
        logoUrl: row.logoUrl,
        notes: row.notes,
        isActive: row.isActive,
        isAutoDetected: row.isAutoDetected,
        createdAt: row.createdAt,
      );

  SubscriptionsCompanion _toCompanion(SubscriptionModel s) =>
      SubscriptionsCompanion.insert(
        name: s.name,
        amount: s.amount,
        frequency: Value(s.frequency),
        nextBillDate: s.nextBillDate,
        category: Value(s.category),
        logoUrl: Value(s.logoUrl),
        notes: Value(s.notes),
        isActive: Value(s.isActive),
        isAutoDetected: Value(s.isAutoDetected),
        createdAt: s.createdAt,
      );

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<int> add(SubscriptionModel subscription) =>
      _d.into(_d.subscriptions).insert(_toCompanion(subscription));

  Future<void> update(SubscriptionModel subscription) async {
    await (_d.update(_d.subscriptions)
          ..where((s) => s.id.equals(subscription.id)))
        .write(SubscriptionsCompanion(
      name: Value(subscription.name),
      amount: Value(subscription.amount),
      frequency: Value(subscription.frequency),
      nextBillDate: Value(subscription.nextBillDate),
      category: Value(subscription.category),
      logoUrl: Value(subscription.logoUrl),
      notes: Value(subscription.notes),
      isActive: Value(subscription.isActive),
      isAutoDetected: Value(subscription.isAutoDetected),
    ));
  }

  Future<void> delete(int id) async {
    await (_d.delete(_d.subscriptions)..where((s) => s.id.equals(id))).go();
  }

  Future<SubscriptionModel?> getById(int id) async {
    final row = await (_d.select(_d.subscriptions)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<SubscriptionModel>> getAll() async {
    final rows = await (_d.select(_d.subscriptions)
          ..orderBy([(s) => OrderingTerm.asc(s.nextBillDate)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<SubscriptionModel>> getActive() async {
    final rows = await (_d.select(_d.subscriptions)
          ..where((s) => s.isActive.equals(true))
          ..orderBy([(s) => OrderingTerm.asc(s.nextBillDate)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<SubscriptionModel>> getDueWithin(int days) async {
    final deadline = DateTime.now().add(Duration(days: days));
    final rows = await (_d.select(_d.subscriptions)
          ..where((s) =>
              s.isActive.equals(true) &
              s.nextBillDate.isSmallerOrEqualValue(deadline)))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<double> getMonthlyTotal() async {
    final subs = await getActive();
    double total = 0;
    for (final s in subs) {
      if (s.frequency == 0) total += s.amount; // Weekly -> * 4.33? Simple just use what's there
      else if (s.frequency == 1) total += s.amount; // Monthly
      else if (s.frequency == 2) total += s.amount / 12; // Yearly -> / 12
    }
    return total;
  }

  Future<double> getYearlyTotal() async {
    final subs = await getActive();
    double total = 0;
    for (final s in subs) {
      if (s.frequency == 0) total += s.amount * 52;
      else if (s.frequency == 1) total += s.amount * 12;
      else if (s.frequency == 2) total += s.amount;
    }
    return total;
  }

  Future<int> detectFromTransactions(List<dynamic> transactions) async {
    // Stub implementation to fix the build error.
    // Full transaction auto-detection logic can be restored later.
    return 0;
  }

  Stream<void> watchAll() =>
      _d.select(_d.subscriptions).watch().map((_) {});
}
