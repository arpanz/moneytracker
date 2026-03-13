import 'app_database.dart';

export 'app_database.dart';

/// Thin wrapper around [AppDatabase] so existing provider code that
/// depends on [DatabaseService] can stay unchanged.
class DatabaseService {
  late AppDatabase _db;

  AppDatabase get db => _db;

  Future<void> initialize() async {
    _db = AppDatabase();
  }

  /// Deletes all rows from every table inside a single transaction.
  /// Uses explicit table references to avoid unsafe dynamic casts.
  Future<void> clearAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.accounts).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.goals).go();
      await _db.delete(_db.subscriptions).go();
      await _db.delete(_db.splits).go();
      await _db.delete(_db.loans).go();
    });
  }

  Future<void> close() async {
    await _db.close();
  }
}
