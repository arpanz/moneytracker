import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../domain/models/account_model.dart';
import '../../../../domain/models/transaction_model.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

DateTime _monthStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}

DateTime _monthEnd() {
  final now = DateTime.now();
  return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
}

// ── User name ────────────────────────────────────────────────────────────────

final userNameProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(AppConstants.prefUserName) ?? '';
});

// ── Accounts list ────────────────────────────────────────────────────────────

/// All non-archived accounts.
final accountsListProvider = FutureProvider<List<AccountModel>>((ref) async {
  ref.watch(accountStreamProvider);
  final repo = ref.watch(accountRepositoryProvider);
  return repo.getActive();
});

/// Stream that fires whenever accounts change, used to refresh derived providers.
final accountStreamProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.watchAll();
});

// ── Active Account ───────────────────────────────────────────────────────────

/// -1 means "All Accounts". Otherwise the Isar id of the selected account.
final activeAccountIdProvider = StateProvider<int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getInt(AppConstants.prefActiveAccountId) ?? -1;
});

// ── Total Balance ────────────────────────────────────────────────────────────

final totalBalanceProvider = FutureProvider<double>((ref) async {
  final activeId = ref.watch(activeAccountIdProvider);
  final repo = ref.watch(accountRepositoryProvider);
  if (activeId == -1) {
    return repo.getTotalBalance();
  }
  final account = await repo.getById(activeId);
  return account?.balance ?? 0.0;
});

// ── Monthly Income ───────────────────────────────────────────────────────────

final monthlyIncomeProvider = FutureProvider<double>((ref) async {
  final activeId = ref.watch(activeAccountIdProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  if (activeId == -1) {
    return repo.getTotalByType(0, _monthStart(), _monthEnd());
  }
  final txns = await repo.getByAccount(activeId.toString());
  return txns
      .where((t) =>
          t.type == 0 &&
          !t.date.isBefore(_monthStart()) &&
          !t.date.isAfter(_monthEnd()))
      .fold(0.0, (s, t) => s + t.amount);
});

// ── Monthly Expense ──────────────────────────────────────────────────────────

final monthlyExpenseProvider = FutureProvider<double>((ref) async {
  final activeId = ref.watch(activeAccountIdProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  if (activeId == -1) {
    return repo.getTotalByType(1, _monthStart(), _monthEnd());
  }
  final txns = await repo.getByAccount(activeId.toString());
  return txns
      .where((t) =>
          t.type == 1 &&
          !t.date.isBefore(_monthStart()) &&
          !t.date.isAfter(_monthEnd()))
      .fold(0.0, (s, t) => s + t.amount);
});

// ── Recent Transactions ──────────────────────────────────────────────────────

final recentTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final activeId = ref.watch(activeAccountIdProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  if (activeId == -1) {
    return repo.getAll(limit: 5);
  }
  final txns = await repo.getByAccount(activeId.toString());
  return txns.take(5).toList();
});

// ── Category Totals ───────────────────────────────────────────────────────────

final categoryTotalsProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final activeId = ref.watch(activeAccountIdProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  if (activeId == -1) {
    return repo.getCategoryTotals(_monthStart(), _monthEnd());
  }
  final txns = await repo.getByAccount(activeId.toString());
  final totals = <String, double>{};
  for (final t in txns) {
    if (t.type == 1 &&
        !t.date.isBefore(_monthStart()) &&
        !t.date.isAfter(_monthEnd())) {
      totals[t.category] = (totals[t.category] ?? 0.0) + t.amount;
    }
  }
  return totals;
});

// ── Stream refresh trigger ────────────────────────────────────────────────────

final transactionStreamProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAll();
});
