import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants/app_constants.dart';
import '../../config/constants/currency_catalog.dart';
import '../../data/local/database_service.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/split_repository.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/repositories/transaction_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main');
});

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('DatabaseService must be overridden in main');
});

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

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepository(ref.watch(databaseServiceProvider));
});

final currencyCodeProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(AppConstants.prefCurrency) ??
      AppConstants.defaultCurrency;
});

final currencySymbolProvider = Provider<String>((ref) {
  final code = ref.watch(currencyCodeProvider);
  return currencySymbolFor(code);
});

final showValuesProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefShowValues) ?? true;
});
