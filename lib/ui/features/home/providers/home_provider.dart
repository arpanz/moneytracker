import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
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

/// Reads the stored user name from SharedPreferences.
final userNameProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(AppConstants.prefUserName) ?? '';
});

// ── Total Balance ────────────────────────────────────────────────────────────

/// Provides the aggregate balance across all non-archived accounts.
final totalBalanceProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.getTotalBalance();
});

// ── Monthly Income ───────────────────────────────────────────────────────────

/// Total income (type 0) for the current calendar month.
final monthlyIncomeProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getTotalByType(0, _monthStart(), _monthEnd());
});

// ── Monthly Expense ──────────────────────────────────────────────────────────

/// Total expenses (type 1) for the current calendar month.
final monthlyExpenseProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getTotalByType(1, _monthStart(), _monthEnd());
});

// ── Recent Transactions ──────────────────────────────────────────────────────

/// The 5 most recent transactions (newest first).
final recentTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getAll(limit: 5);
});

// ── Category Totals (for pie chart) ──────────────────────────────────────────

/// Expense totals grouped by category for the current month.
/// Used by the mini spending pie chart on the home dashboard.
final categoryTotalsProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getCategoryTotals(_monthStart(), _monthEnd());
});

// ── Stream-based refresh trigger ─────────────────────────────────────────────

/// Watches the transaction collection for any changes.
/// UI can listen to this and invalidate the above providers to refresh data.
final transactionStreamProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAll();
});
