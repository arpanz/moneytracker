import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants/app_constants.dart';
import '../../data/local/database_service.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/repositories/split_repository.dart';

// ── Core Services ──

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main');
});

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('DatabaseService must be overridden in main');
});

// ── Repositories ──

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseServiceProvider));
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(databaseServiceProvider));
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseServiceProvider));
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(databaseServiceProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseServiceProvider));
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(databaseServiceProvider));
});

final splitRepositoryProvider = Provider<SplitRepository>((ref) {
  return SplitRepository(ref.watch(databaseServiceProvider));
});

// ── Currency ──────────────────────────────────────────────────────────────────

/// Returns the currency symbol that matches the user's chosen currency code
/// stored in SharedPreferences. Falls back to 'Rs.' for INR.
///
/// FIX #16: AppConstants.currencySymbol was a hardcoded compile-time constant
/// that never reflected the user's onboarding currency selection. This provider
/// reads the pref at runtime so the symbol updates correctly for INR/USD/EUR/GBP.
final currencySymbolProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final code = prefs.getString(AppConstants.prefCurrency) ??
      AppConstants.defaultCurrency;
  switch (code) {
    case 'USD':
      return r'$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    case 'INR':
    default:
      return 'Rs.';
  }
});
