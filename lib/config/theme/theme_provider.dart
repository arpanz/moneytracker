import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/di/providers.dart';
import '../../config/constants/app_constants.dart';
import 'vibe_themes.dart';

/// Immutable state representing the user's theme preferences.
class ThemeState {
  final VibeTheme vibeTheme;
  final ThemeMode themeMode;

  const ThemeState({
    this.vibeTheme = VibeTheme.midnight,
    this.themeMode = ThemeMode.system,
  });

  ThemeState copyWith({
    VibeTheme? vibeTheme,
    ThemeMode? themeMode,
  }) {
    return ThemeState(
      vibeTheme: vibeTheme ?? this.vibeTheme,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeState &&
          runtimeType == other.runtimeType &&
          vibeTheme == other.vibeTheme &&
          themeMode == other.themeMode;

  @override
  int get hashCode => Object.hash(vibeTheme, themeMode);
}

/// Riverpod provider for the theme state.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ThemeNotifier(prefs);
  },
);

/// Manages theme state and persists preferences to [SharedPreferences].
class ThemeNotifier extends StateNotifier<ThemeState> {
  final SharedPreferences _prefs;

  ThemeNotifier(this._prefs) : super(const ThemeState()) {
    _loadFromPrefs();
  }

  /// Reads persisted theme prefs and updates state.
  void _loadFromPrefs() {
    final vibeIndex = _prefs.getInt(AppConstants.prefVibeTheme);
    final modeIndex = _prefs.getInt(AppConstants.prefThemeMode);

    state = ThemeState(
      vibeTheme: vibeIndex != null && vibeIndex < VibeTheme.values.length
          ? VibeTheme.values[vibeIndex]
          : VibeTheme.midnight,
      themeMode: modeIndex != null && modeIndex < ThemeMode.values.length
          ? ThemeMode.values[modeIndex]
          : ThemeMode.system,
    );
  }

  /// Sets the active [VibeTheme] and persists the choice.
  Future<void> setVibeTheme(VibeTheme theme) async {
    state = state.copyWith(vibeTheme: theme);
    await _prefs.setInt(AppConstants.prefVibeTheme, theme.index);
  }

  /// Sets the [ThemeMode] (light / dark / system) and persists.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setInt(AppConstants.prefThemeMode, mode.index);
  }

  /// Toggles between light and dark. If currently system, switches to dark.
  Future<void> toggleTheme() async {
    final ThemeMode next;
    switch (state.themeMode) {
      case ThemeMode.light:
        next = ThemeMode.dark;
      case ThemeMode.dark:
        next = ThemeMode.light;
      case ThemeMode.system:
        next = ThemeMode.dark;
    }
    await setThemeMode(next);
  }
}
