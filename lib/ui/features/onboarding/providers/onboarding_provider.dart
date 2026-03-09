import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../data/local/database_service.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../domain/models/account_model.dart';

// ── State ────────────────────────────────────────────────────────────────────

class OnboardingState {
  final int currentPage;
  final String userName;
  final String currency;
  final bool biometricEnabled;

  const OnboardingState({
    this.currentPage = 0,
    this.userName = '',
    this.currency = AppConstants.defaultCurrency,
    this.biometricEnabled = false,
  });

  OnboardingState copyWith({
    int? currentPage,
    String? userName,
    String? currency,
    bool? biometricEnabled,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      userName: userName ?? this.userName,
      currency: currency ?? this.currency,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final SharedPreferences _prefs;
  final DatabaseService _databaseService;

  OnboardingNotifier(this._prefs, this._databaseService)
      : super(const OnboardingState());

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void setUserName(String name) {
    state = state.copyWith(userName: name);
  }

  void setCurrency(String currency) {
    state = state.copyWith(currency: currency);
  }

  void toggleBiometric() {
    state = state.copyWith(biometricEnabled: !state.biometricEnabled);
  }

  /// Persists all onboarding choices, creates a default account, and marks
  /// onboarding as complete.
  Future<void> completeOnboarding() async {
    await _prefs.setBool(AppConstants.prefOnboardingComplete, true);
    await _prefs.setString(AppConstants.prefUserName, state.userName);
    await _prefs.setString(AppConstants.prefCurrency, state.currency);
    await _prefs.setBool(
        AppConstants.prefAppLockEnabled, state.biometricEnabled);

    // FIX: Create a default "Cash" account so the user can immediately
    // add transactions after onboarding. Without an account,
    // TransactionModel.accountId has nothing to reference and the
    // add-transaction screen shows an empty account selector.
    final accountRepo = AccountRepository(_databaseService);
    final existingAccounts = await accountRepo.getAll();
    if (existingAccounts.isEmpty) {
      final defaultAccount = AccountModel()
        ..name = 'Cash'
        ..accountType = 3 // cash
        ..balance = 0.0
        ..currency = state.currency
        ..icon = 'wallet'
        ..color = 0xFF4CAF50
        ..isArchived = false
        ..createdAt = DateTime.now();
      await accountRepo.add(defaultAccount);
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  return OnboardingNotifier(prefs, databaseService);
});
