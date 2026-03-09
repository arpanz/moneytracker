import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

// ── State ────────────────────────────────────────────────────────────────────

class LockState {
  final bool isAuthenticated;
  final bool isAuthenticating;
  final String? error;

  const LockState({
    this.isAuthenticated = false,
    this.isAuthenticating = false,
    this.error,
  });

  LockState copyWith({
    bool? isAuthenticated,
    bool? isAuthenticating,
    String? error,
    bool clearError = false,
  }) {
    return LockState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class LockNotifier extends StateNotifier<LockState> {
  final LocalAuthentication _auth;

  LockNotifier(this._auth) : super(const LockState());

  /// Checks whether the device supports biometric authentication and
  /// has at least one biometric enrolled.
  Future<bool> checkBiometricAvailability() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Triggers biometric authentication.
  ///
  /// On success, sets [isAuthenticated] to true.
  /// On failure, stores the error message in [error].
  Future<void> authenticate() async {
    if (state.isAuthenticating) return;

    state = state.copyWith(
      isAuthenticating: true,
      clearError: true,
    );

    try {
      final success = await _auth.authenticate(
        localizedReason: 'Authenticate to access Cheddar',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (success) {
        state = state.copyWith(
          isAuthenticated: true,
          isAuthenticating: false,
        );
      } else {
        state = state.copyWith(
          isAuthenticating: false,
          error: 'Authentication failed. Try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isAuthenticating: false,
        error: 'Biometric error: ${e.toString()}',
      );
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final lockProvider = StateNotifierProvider<LockNotifier, LockState>((ref) {
  return LockNotifier(LocalAuthentication());
});
