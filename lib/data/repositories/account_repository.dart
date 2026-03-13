import 'package:drift/drift.dart';

import '../../domain/models/account_model.dart';
import '../local/database_service.dart';

/// Repository for managing financial accounts.
class AccountRepository {
  final DatabaseService _db;

  AccountRepository(this._db);

  AppDatabase get _d => _db.db;

  // ── Mapping ──────────────────────────────────────────────────────────────

  AccountModel _fromRow(Account row) => AccountModel(
        id: row.id,
        name: row.name,
        accountType: row.accountType,
        balance: row.balance,
        creditLimit: row.creditLimit,
        currency: row.currency,
        icon: row.icon,
        color: row.color,
        isArchived: row.isArchived,
        createdAt: row.createdAt,
      );

  AccountsCompanion _toCompanion(AccountModel a) =>
      AccountsCompanion.insert(
        name: a.name,
        accountType: Value(a.accountType),
        balance: Value(a.balance),
        creditLimit: Value(a.creditLimit),
        currency: Value(a.currency),
        icon: Value(a.icon),
        color: Value(a.color),
        isArchived: Value(a.isArchived),
        createdAt: a.createdAt,
      );

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<int> add(AccountModel account) =>
      _d.into(_d.accounts).insert(_toCompanion(account));

  Future<void> update(AccountModel account) async {
    await (_d.update(_d.accounts)
          ..where((a) => a.id.equals(account.id)))
        .write(AccountsCompanion(
      name: Value(account.name),
      accountType: Value(account.accountType),
      balance: Value(account.balance),
      creditLimit: Value(account.creditLimit),
      currency: Value(account.currency),
      icon: Value(account.icon),
      color: Value(account.color),
      isArchived: Value(account.isArchived),
    ));
  }

  Future<void> delete(int id) async {
    await (_d.delete(_d.accounts)..where((a) => a.id.equals(id))).go();
  }

  Future<AccountModel?> getById(int id) async {
    final row = await (_d.select(_d.accounts)
          ..where((a) => a.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<AccountModel>> getAll() async {
    final rows = await (_d.select(_d.accounts)
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  // ── Filtered Queries ─────────────────────────────────────────────────────

  Future<List<AccountModel>> getByType(int type) async {
    final rows = await (_d.select(_d.accounts)
          ..where((a) => a.accountType.equals(type))
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<AccountModel>> getActive() async {
    final rows = await (_d.select(_d.accounts)
          ..where((a) => a.isArchived.equals(false))
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  // ── Balance Operations ────────────────────────────────────────────────────

  Future<double> getTotalBalance() async {
    final accounts = await getActive();
    return accounts.fold<double>(0.0, (sum, a) => sum + a.balance);
  }

  Future<double> getNetWorth() async {
    final accounts = await getActive();
    double netWorth = 0.0;
    for (final a in accounts) {
      if (a.accountType == 2) {
        netWorth -= a.balance.abs();
      } else {
        netWorth += a.balance;
      }
    }
    return netWorth;
  }

  Future<void> updateBalance(int id, double newBalance) async {
    await (_d.update(_d.accounts)..where((a) => a.id.equals(id)))
        .write(AccountsCompanion(balance: Value(newBalance)));
  }

  Future<void> archive(int id) async {
    await (_d.update(_d.accounts)..where((a) => a.id.equals(id)))
        .write(const AccountsCompanion(isArchived: Value(true)));
  }

  // ── Real-Time Stream ─────────────────────────────────────────────────────

  Stream<void> watchAll() =>
      _d.select(_d.accounts).watch().map((_) {});
}
