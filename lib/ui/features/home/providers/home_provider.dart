import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../domain/models/account_model.dart';
import '../../../../domain/models/transaction_model.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

DateTime _monthStart(DateTime m) => DateTime(m.year, m.month);
DateTime _monthEnd(DateTime m) => DateTime(m.year, m.month + 1, 0, 23, 59, 59);

// ── User name ────────────────────────────────────────────────────────────────
// ── Selected Month ────────────────────────────────────────────────────────────

/// The month currently viewed on the home screen. Defaults to the current month.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

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
  ref.watch(accountStreamProvider);
  ref.watch(transactionStreamProvider);
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
  ref.watch(transactionStreamProvider);
  final activeId = ref.watch(activeAccountIdProvider);
  final month = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final start = _monthStart(month);
  final end = _monthEnd(month);
  if (activeId == -1) {
    return repo.getTotalByType(0, start, end);
  }
  final txns = await repo.getByAccount(activeId.toString());
  return txns
      .where(
        (t) => t.type == 0 && !t.date.isBefore(start) && !t.date.isAfter(end),
      )
      .fold<double>(0.0, (s, t) => s + t.amount);
});

// ── Monthly Expense ──────────────────────────────────────────────────────────

final monthlyExpenseProvider = FutureProvider<double>((ref) async {
  ref.watch(transactionStreamProvider);
  final activeId = ref.watch(activeAccountIdProvider);
  final month = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final start = _monthStart(month);
  final end = _monthEnd(month);
  if (activeId == -1) {
    return repo.getTotalByType(1, start, end);
  }
  final txns = await repo.getByAccount(activeId.toString());
  return txns
      .where(
        (t) => t.type == 1 && !t.date.isBefore(start) && !t.date.isAfter(end),
      )
      .fold<double>(0.0, (s, t) => s + t.amount);
});

// ── Recent Transactions ──────────────────────────────────────────────────────

final recentTransactionsProvider = FutureProvider<List<TransactionModel>>((
  ref,
) async {
  ref.watch(transactionStreamProvider);
  final activeId = ref.watch(activeAccountIdProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  if (activeId == -1) {
    return repo.getAll(limit: 5);
  }
  final txns = await repo.getByAccount(activeId.toString());
  return txns.take(5).toList();
});

// ── Category Totals ───────────────────────────────────────────────────────────

final categoryTotalsProvider = FutureProvider<Map<String, double>>((ref) async {
  ref.watch(transactionStreamProvider);
  final activeId = ref.watch(activeAccountIdProvider);
  final month = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final start = _monthStart(month);
  final end = _monthEnd(month);
  if (activeId == -1) {
    return repo.getCategoryTotals(start, end);
  }
  final txns = await repo.getByAccount(activeId.toString());
  final totals = <String, double>{};
  for (final t in txns) {
    if (t.type == 1 && !t.date.isBefore(start) && !t.date.isAfter(end)) {
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
