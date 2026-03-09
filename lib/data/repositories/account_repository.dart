import 'package:isar/isar.dart';

import '../../domain/models/account_model.dart';
import '../local/database_service.dart';

/// Repository for managing financial accounts.
///
/// Provides CRUD operations, balance calculations, net worth,
/// archiving, and a real-time watch stream.
class AccountRepository {
  final DatabaseService _db;

  AccountRepository(this._db);

  Isar get _isar => _db.isar;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserts a new account and returns its auto-generated id.
  Future<int> add(AccountModel account) async {
    return _isar.writeTxn(() async {
      return _isar.accountModels.put(account);
    });
  }

  /// Updates an existing account in-place.
  Future<void> update(AccountModel account) async {
    await _isar.writeTxn(() async {
      await _isar.accountModels.put(account);
    });
  }

  /// Deletes an account by its id.
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.accountModels.delete(id);
    });
  }

  /// Retrieves a single account by id, or null if not found.
  Future<AccountModel?> getById(int id) async {
    return _isar.accountModels.get(id);
  }

  /// Returns all accounts ordered by name.
  Future<List<AccountModel>> getAll() async {
    return _isar.accountModels
        .where()
        .sortByName()
        .findAll();
  }

  // ── FILTERED QUERIES ─────────────────────────────────────────────────────

  /// Returns accounts of a given type (0=checking, 1=savings, etc.).
  Future<List<AccountModel>> getByType(int type) async {
    return _isar.accountModels
        .where()
        .accountTypeEqualTo(type)
        .sortByName()
        .findAll();
  }

  /// Returns all non-archived (active) accounts.
  Future<List<AccountModel>> getActive() async {
    return _isar.accountModels
        .filter()
        .isArchivedEqualTo(false)
        .sortByName()
        .findAll();
  }

  // ── BALANCE OPERATIONS ───────────────────────────────────────────────────

  /// Calculates the sum of all active account balances.
  ///
  /// Excludes archived accounts.
  Future<double> getTotalBalance() async {
    final accounts = await getActive();
    return accounts.fold<double>(0.0, (sum, a) => sum + a.balance);
  }

  /// Calculates net worth: total assets minus credit card balances.
  ///
  /// Credit accounts (type 2) are treated as liabilities. All other
  /// non-archived accounts are treated as assets.
  Future<double> getNetWorth() async {
    final accounts = await getActive();
    double netWorth = 0.0;
    for (final account in accounts) {
      if (account.accountType == 2) {
        // Credit card: negative balance is debt owed
        netWorth -= account.balance.abs();
      } else {
        netWorth += account.balance;
      }
    }
    return netWorth;
  }

  /// Directly updates the balance of a specific account.
  Future<void> updateBalance(int id, double newBalance) async {
    await _isar.writeTxn(() async {
      final account = await _isar.accountModels.get(id);
      if (account != null) {
        account.balance = newBalance;
        await _isar.accountModels.put(account);
      }
    });
  }

  /// Archives an account so it no longer appears in active lists.
  Future<void> archive(int id) async {
    await _isar.writeTxn(() async {
      final account = await _isar.accountModels.get(id);
      if (account != null) {
        account.isArchived = true;
        await _isar.accountModels.put(account);
      }
    });
  }

  // ── REAL-TIME STREAM ─────────────────────────────────────────────────────

  /// Watches the entire account collection for any changes.
  Stream<void> watchAll() {
    return _isar.accountModels.watchLazy();
  }
}
