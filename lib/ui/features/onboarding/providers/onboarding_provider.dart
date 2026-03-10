import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../data/local/database_service.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../domain/models/account_model.dart';

class OnboardingState {
  final int currentPage;
  final String userName;
  final String currency;
  final bool biometricEnabled;
  final String accountName;
  final int accountType;
  final double openingBalance;

  const OnboardingState({
    this.currentPage = 0,
    this.userName = '',
    this.currency = AppConstants.defaultCurrency,
    this.biometricEnabled = false,
    this.accountName = 'Cash',
    this.accountType = 3,
    this.openingBalance = 0,
  });

  OnboardingState copyWith({
    int? currentPage,
    String? userName,
    String? currency,
    bool? biometricEnabled,
    String? accountName,
    int? accountType,
    double? openingBalance,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      userName: userName ?? this.userName,
      currency: currency ?? this.currency,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      openingBalance: openingBalance ?? this.openingBalance,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final SharedPreferences _prefs;
  final DatabaseService _databaseService;

  OnboardingNotifier(this._prefs, this._databaseService)
    : super(
        OnboardingState(
          userName: _prefs.getString(AppConstants.prefUserName) ?? '',
          currency:
              _prefs.getString(AppConstants.prefCurrency) ??
              AppConstants.defaultCurrency,
        ),
      );

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

  void setAccountName(String name) {
    state = state.copyWith(accountName: name);
  }

  void setAccountType(int type) {
    state = state.copyWith(accountType: type);
  }

  void setOpeningBalance(double balance) {
    state = state.copyWith(openingBalance: balance);
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(AppConstants.prefOnboardingComplete, true);
    await _prefs.setString(AppConstants.prefUserName, state.userName.trim());
    await _prefs.setString(AppConstants.prefCurrency, state.currency);
    await _prefs.setBool(
      AppConstants.prefAppLockEnabled,
      state.biometricEnabled,
    );

    final accountRepo = AccountRepository(_databaseService);
    final existingAccounts = await accountRepo.getAll();

    if (existingAccounts.isEmpty) {
      final defaultAccount = AccountModel()
        ..name = state.accountName.trim().isEmpty
            ? 'Cash'
            : state.accountName.trim()
        ..accountType = state.accountType
        ..balance = state.openingBalance
        ..currency = state.currency
        ..icon = _iconForAccountType(state.accountType)
        ..color = _colorForAccountType(state.accountType)
        ..isArchived = false
        ..createdAt = DateTime.now();

      final id = await accountRepo.add(defaultAccount);
      await _prefs.setString(AppConstants.prefDefaultAccount, id.toString());
    } else {
      await _prefs.setString(
        AppConstants.prefDefaultAccount,
        existingAccounts.first.id.toString(),
      );
    }
  }

  String _iconForAccountType(int type) {
    switch (type) {
      case 0:
        return 'building-columns';
      case 1:
        return 'wallet';
      case 2:
        return 'credit-card';
      case 3:
      default:
        return 'money-bill';
    }
  }

  int _colorForAccountType(int type) {
    switch (type) {
      case 0:
        return 0xFF2563EB;
      case 1:
        return 0xFF7C3AED;
      case 2:
        return 0xFFF97316;
      case 3:
      default:
        return 0xFF16A34A;
    }
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final databaseService = ref.watch(databaseServiceProvider);
      return OnboardingNotifier(prefs, databaseService);
    });
