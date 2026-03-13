import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../domain/models/account_model.dart';
import '../../../../domain/models/transaction_model.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

DateTime _monthStart(DateTime m) => DateTime(m.year, m.month);
DateTime _monthEnd(DateTime m) => DateTime(m.year, m.month + 1, 0, 23, 59, 59);
DateTime _maxDate() => DateTime(9999, 12, 31, 23, 59, 59);

double _sourceAccountBalanceImpact(TransactionModel t) {
  return t.type == 0 ? t.amount : -t.amount;
}

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
  final month = ref.watch(selectedMonthProvider);
  final accountRepo = ref.watch(accountRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final cutoff = _monthEnd(month);

  final txnsInRange = await transactionRepo.getByDateRange(cutoff, _maxDate());
  final txnsAfterCutoff = txnsInRange.where((t) => t.date.isAfter(cutoff));

  if (activeId == -1) {
    final accounts = await accountRepo.getActive();
    final balances = <int, double>{
      for (final account in accounts) account.id: account.balance,
    };

    for (final t in txnsAfterCutoff) {
      final sourceId = int.tryParse(t.accountId);
      if (sourceId != null && balances.containsKey(sourceId)) {
        balances[sourceId] =
            balances[sourceId]! - _sourceAccountBalanceImpact(t);
      }

      if (t.type == 2 && t.toAccountId != null) {
        final destinationId = int.tryParse(t.toAccountId!);
        if (destinationId != null && balances.containsKey(destinationId)) {
          balances[destinationId] = balances[destinationId]! - t.amount;
        }
      }
    }

    return balances.values.fold<double>(0.0, (sum, b) => sum + b);
  }

  final account = await accountRepo.getById(activeId);
  if (account == null) return 0.0;

  var adjustedBalance = account.balance;
  for (final t in txnsAfterCutoff) {
    final sourceId = int.tryParse(t.accountId);
    if (sourceId == activeId) {
      adjustedBalance -= _sourceAccountBalanceImpact(t);
    }

    if (t.type == 2 && t.toAccountId != null) {
      final destinationId = int.tryParse(t.toAccountId!);
      if (destinationId == activeId) {
        adjustedBalance -= t.amount;
      }
    }
  }

  return adjustedBalance;
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
  final month = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final start = _monthStart(month);
  final end = _monthEnd(month);

  if (activeId == -1) {
    return repo.getByDateRange(start, end);
  }

  final txns = await repo.getByAccount(activeId.toString());
  return txns
      .where((t) => !t.date.isBefore(start) && !t.date.isAfter(end))
      .toList();
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
