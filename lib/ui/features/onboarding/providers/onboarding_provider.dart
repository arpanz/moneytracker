import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';

// ── State ──────────────────────────────────────────────────────────────────────

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

// ── Notifier ───────────────────────────────────────────────────────────────────

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final SharedPreferences _prefs;

  OnboardingNotifier(this._prefs) : super(const OnboardingState());

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

  /// Persists all onboarding choices and marks onboarding as complete.
  Future<void> completeOnboarding() async {
    await _prefs.setBool(AppConstants.prefOnboardingComplete, true);
    await _prefs.setString(AppConstants.prefUserName, state.userName);
    await _prefs.setString(AppConstants.prefCurrency, state.currency);
    await _prefs.setBool(AppConstants.prefAppLockEnabled, state.biometricEnabled);
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingNotifier(prefs);
});
