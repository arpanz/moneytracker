import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../domain/models/transaction_model.dart';

// ── Filter State ────────────────────────────────────────────────────────────

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

// ── Filter Notifier ─────────────────────────────────────────────────────────

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

// ── Providers ───────────────────────────────────────────────────────────────

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
///
/// Filtering is done client-side for simplicity. For large datasets
/// the repository query methods could be used instead.
final filteredTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final filter = ref.watch(transactionFilterProvider);

  // If a search query is active, use the repository search method.
  if (filter.searchQuery.isNotEmpty) {
    final results = await repo.search(filter.searchQuery);
    return _applyNonSearchFilters(results, filter);
  }

  // If a date range is set, use the date range query.
  if (filter.dateRange != null) {
    final results = await repo.getByDateRange(
      filter.dateRange!.start,
      filter.dateRange!.end,
    );
    return _applyNonSearchFilters(results, filter);
  }

  // Otherwise fetch all and filter in memory.
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
///
/// Returns a list of `(DateTime date, List<TransactionModel> items)` pairs
/// ordered by date descending. Each date represents midnight of that day.
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

// ── Mutation Providers ──────────────────────────────────────────────────────

/// Adds a new transaction and invalidates the list cache.
final addTransactionProvider =
    FutureProvider.family<int, TransactionModel>((ref, transaction) async {
  final repo = ref.read(transactionRepositoryProvider);
  final id = await repo.add(transaction);
  ref.invalidate(allTransactionsProvider);
  ref.invalidate(filteredTransactionsProvider);
  ref.invalidate(groupedTransactionsProvider);
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
});

/// Deletes a transaction by id and invalidates caches.
final deleteTransactionProvider =
    FutureProvider.family<void, int>((ref, id) async {
  final repo = ref.read(transactionRepositoryProvider);
  await repo.delete(id);
  ref.invalidate(allTransactionsProvider);
  ref.invalidate(filteredTransactionsProvider);
  ref.invalidate(groupedTransactionsProvider);
});

// ── Helpers ─────────────────────────────────────────────────────────────────

/// A date-keyed group of transactions for list display.
class TransactionDateGroup {
  final DateTime date;
  final List<TransactionModel> transactions;

  const TransactionDateGroup({
    required this.date,
    required this.transactions,
  });

  /// Sum of income minus expenses for this day.
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

/// Applies type and category filters (but not search or dateRange)
/// to an already-fetched list.
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
