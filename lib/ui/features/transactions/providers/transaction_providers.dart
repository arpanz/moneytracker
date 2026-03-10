import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../domain/models/transaction_model.dart';
import '../../home/providers/home_provider.dart';

// ── Filter State ──────────────────────────────────────────────────────────────────

/// Immutable filter state applied to the transaction list.
class TransactionFilter {
  /// Transaction type: 0 = income, 1 = expense, 2 = transfer, null = all.
  final int? type;

  /// Category name filter. Null means all categories.
  final String? category;

  /// Date range filter. Null means no date constraint.
  final DateTimeRange? dateRange;

  /// Free-text search across category, note, and tags.
  final String searchQuery;

  const TransactionFilter({
    this.type,
    this.category,
    this.dateRange,
    this.searchQuery = '',
  });

  TransactionFilter copyWith({
    int? Function()? type,
    String? Function()? category,
    DateTimeRange? Function()? dateRange,
    String? searchQuery,
  }) {
    return TransactionFilter(
      type: type != null ? type() : this.type,
      category: category != null ? category() : this.category,
      dateRange: dateRange != null ? dateRange() : this.dateRange,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get isActive =>
      type != null ||
      category != null ||
      dateRange != null ||
      searchQuery.isNotEmpty;
}

// ── Filter Notifier ─────────────────────────────────────────────────────────────────

class TransactionFilterNotifier extends StateNotifier<TransactionFilter> {
  TransactionFilterNotifier() : super(const TransactionFilter());

  void setType(int? type) {
    state = state.copyWith(type: () => type);
  }

  void setCategory(String? category) {
    state = state.copyWith(category: () => category);
  }

  void setDateRange(DateTimeRange? dateRange) {
    state = state.copyWith(dateRange: () => dateRange);
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearAll() {
    state = const TransactionFilter();
  }
}

// ── Providers ───────────────────────────────────────────────────────────────────

/// Notifier that manages the current filter state.
final transactionFilterProvider =
    StateNotifierProvider<TransactionFilterNotifier, TransactionFilter>(
  (ref) => TransactionFilterNotifier(),
);

/// Fetches all transactions from the repository (newest first).
final allTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getAll();
});

/// Applies the current [TransactionFilter] to the full transaction list.
final filteredTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final filter = ref.watch(transactionFilterProvider);

  if (filter.searchQuery.isNotEmpty) {
    final results = await repo.search(filter.searchQuery);
    return _applyNonSearchFilters(results, filter);
  }

  if (filter.dateRange != null) {
    final results = await repo.getByDateRange(
      filter.dateRange!.start,
      filter.dateRange!.end,
    );
    return _applyNonSearchFilters(results, filter);
  }

  final all = await repo.getAll();
  return _applyNonSearchFilters(all, filter);
});

/// Retrieves a single transaction by its Isar id.
final transactionByIdProvider =
    FutureProvider.family<TransactionModel?, int>((ref, id) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getById(id);
});

/// Groups filtered transactions by date for section-header display.
final groupedTransactionsProvider =
    FutureProvider<List<TransactionDateGroup>>((ref) async {
  final transactions = await ref.watch(filteredTransactionsProvider.future);

  final groups = <DateTime, List<TransactionModel>>{};
  for (final txn in transactions) {
    final dayKey = DateTime(txn.date.year, txn.date.month, txn.date.day);
    groups.putIfAbsent(dayKey, () => []).add(txn);
  }

  final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return sortedKeys
      .map((key) => TransactionDateGroup(date: key, transactions: groups[key]!))
      .toList();
});

// ── Mutation Providers ────────────────────────────────────────────────────────────────

/// Adds a new transaction, updates account balance(s), and invalidates caches.
final addTransactionProvider =
    FutureProvider.family<int, TransactionModel>((ref, transaction) async {
  final txnRepo = ref.read(transactionRepositoryProvider);
  final accRepo = ref.read(accountRepositoryProvider);

  final id = await txnRepo.add(transaction);

  final srcId = int.tryParse(transaction.accountId);
  if (srcId != null) {
    final src = await accRepo.getById(srcId);
    if (src != null) {
      final double delta;
      switch (transaction.type) {
        case 0:
          delta = transaction.amount;
          break;
        case 2:
          delta = -transaction.amount;
          break;
        default:
          delta = -transaction.amount;
      }
      await accRepo.updateBalance(srcId, src.balance + delta);
    }
  }

  if (transaction.type == 2 && transaction.toAccountId != null) {
    final dstId = int.tryParse(transaction.toAccountId!);
    if (dstId != null) {
      final dst = await accRepo.getById(dstId);
      if (dst != null) {
        await accRepo.updateBalance(dstId, dst.balance + transaction.amount);
      }
    }
  }

  ref.invalidate(allTransactionsProvider);
  ref.invalidate(filteredTransactionsProvider);
  ref.invalidate(groupedTransactionsProvider);
  // FIX: invalidate home providers so home screen syncs immediately.
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(totalBalanceProvider);
  ref.invalidate(monthlyIncomeProvider);
  ref.invalidate(monthlyExpenseProvider);
  ref.invalidate(categoryTotalsProvider);
  return id;
});

/// Updates an existing transaction and invalidates caches.
final updateTransactionProvider =
    FutureProvider.family<void, TransactionModel>((ref, transaction) async {
  final repo = ref.read(transactionRepositoryProvider);
  await repo.update(transaction);
  ref.invalidate(allTransactionsProvider);
  ref.invalidate(filteredTransactionsProvider);
  ref.invalidate(groupedTransactionsProvider);
  ref.invalidate(transactionByIdProvider(transaction.id));
  // FIX: also invalidate home screen providers so recent transactions
  // and balance reflect edits immediately without needing a manual refresh.
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(totalBalanceProvider);
  ref.invalidate(monthlyIncomeProvider);
  ref.invalidate(monthlyExpenseProvider);
  ref.invalidate(categoryTotalsProvider);
});

/// Deletes a transaction by id and invalidates caches.
final deleteTransactionProvider =
    FutureProvider.family<void, int>((ref, id) async {
  final repo = ref.read(transactionRepositoryProvider);
  await repo.delete(id);
  ref.invalidate(allTransactionsProvider);
  ref.invalidate(filteredTransactionsProvider);
  ref.invalidate(groupedTransactionsProvider);
  // FIX: invalidate home providers on delete too.
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(totalBalanceProvider);
  ref.invalidate(monthlyIncomeProvider);
  ref.invalidate(monthlyExpenseProvider);
  ref.invalidate(categoryTotalsProvider);
});

// ── Helpers ───────────────────────────────────────────────────────────────────────

/// A date-keyed group of transactions for list display.
class TransactionDateGroup {
  final DateTime date;
  final List<TransactionModel> transactions;

  const TransactionDateGroup({
    required this.date,
    required this.transactions,
  });

  double get dayTotal {
    double total = 0;
    for (final txn in transactions) {
      if (txn.type == 0) {
        total += txn.amount;
      } else if (txn.type == 1) {
        total -= txn.amount;
      }
    }
    return total;
  }
}

/// Applies type and category filters to an already-fetched list.
List<TransactionModel> _applyNonSearchFilters(
  List<TransactionModel> transactions,
  TransactionFilter filter,
) {
  var result = transactions;
  if (filter.type != null) {
    result = result.where((t) => t.type == filter.type).toList();
  }
  if (filter.category != null) {
    result = result.where((t) => t.category == filter.category).toList();
  }
  return result;
}
