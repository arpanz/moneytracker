import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vibe_themes.dart';
import 'theme_extensions.dart';
import 'spacing.dart';

class AppTheme {
  AppTheme._();

  static const String _headlineFont = 'Poppins';
  static const String _bodyFont = 'Inter';

  static const double _cardRadius       = 16.0;
  static const double _buttonRadius     = 12.0;
  static const double _chipRadius       = 28.0;
  static const double _inputRadius      = 12.0;
  static const double _fabRadius        = 16.0;
  static const double _bottomSheetRadius = 24.0;
  static const double _dialogRadius     = 20.0;

  // ══ LIGHT ══════════════════════════════════════════════════════════════════
  static ThemeData lightTheme(VibeTheme vibe) {
    final data = vibe.data;
    final colorScheme = ColorScheme.light(
      primary:           data.primaryLight,
      onPrimary:         Colors.white,
      primaryContainer:  data.primaryLight.withValues(alpha: 0.12),
      onPrimaryContainer: data.primaryLight,
      secondary:         data.secondaryLight,
      onSecondary:       Colors.white,
      secondaryContainer: data.secondaryLight.withValues(alpha: 0.12),
      onSecondaryContainer: data.secondaryLight,
      surface:           data.surfaceLight,
      onSurface:         data.onSurfaceLight,
      surfaceContainerLowest:  data.backgroundLight,
      surfaceContainerLow:     data.surfaceLight,
      surfaceContainer:        Color.lerp(data.surfaceLight, data.onSurfaceLight, 0.04)!,
      surfaceContainerHigh:    Color.lerp(data.surfaceLight, data.onSurfaceLight, 0.08)!,
      surfaceContainerHighest: Color.lerp(data.surfaceLight, data.onSurfaceLight, 0.12)!,
      onSurfaceVariant:  data.onSurfaceLight.withValues(alpha: 0.60),
      outline:           data.onSurfaceLight.withValues(alpha: 0.14),
      outlineVariant:    data.onSurfaceLight.withValues(alpha: 0.08),
      error:             const Color(0xFFDC2626),
      onError:           Colors.white,
    );
    return _build(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackground: data.backgroundLight,
      cardGradient: data.cardGradientLight,
      cheddarColors: CheddarColors.light(cardGradient: data.cardGradientLight),
    );
  }

  // ══ DARK ═══════════════════════════════════════════════════════════════════
  static ThemeData darkTheme(VibeTheme vibe) {
    final data = vibe.data;
    // Surface container levels: layered depth above background
    final s0 = data.backgroundDark;
    final s1 = Color.lerp(data.backgroundDark, data.onSurfaceDark, 0.05)!;
    final s2 = Color.lerp(data.backgroundDark, data.onSurfaceDark, 0.08)!;
    final s3 = Color.lerp(data.backgroundDark, data.onSurfaceDark, 0.11)!;
    final s4 = Color.lerp(data.backgroundDark, data.onSurfaceDark, 0.15)!;

    final colorScheme = ColorScheme.dark(
      primary:           data.primaryDark,
      onPrimary:         data.backgroundDark,
      primaryContainer:  data.primaryDark.withValues(alpha: 0.18),
      onPrimaryContainer: data.primaryDark,
      secondary:         data.secondaryDark,
      onSecondary:       data.backgroundDark,
      secondaryContainer: data.secondaryDark.withValues(alpha: 0.15),
      onSecondaryContainer: data.secondaryDark,
      surface:           data.surfaceDark,
      onSurface:         data.onSurfaceDark,
      // Explicit M3 container levels — no more auto-generated dull grays
      surfaceContainerLowest:  s0,
      surfaceContainerLow:     s1,
      surfaceContainer:        s2,
      surfaceContainerHigh:    s3,
      surfaceContainerHighest: s4,
      onSurfaceVariant:  data.onSurfaceDark.withValues(alpha: 0.70),
      outline:           data.onSurfaceDark.withValues(alpha: 0.18),
      outlineVariant:    data.onSurfaceDark.withValues(alpha: 0.10),
      error:             const Color(0xFFFF6B6B),
      onError:           const Color(0xFF1A0A0A),
    );
    return _build(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackground: data.backgroundDark,
      cardGradient: data.cardGradientDark,
      cheddarColors: CheddarColors.dark(cardGradient: data.cardGradientDark),
    );
  }

  // ══ SHARED BUILDER ═════════════════════════════════════════════════════════
  static ThemeData _build({
    required ColorScheme colorScheme,
    required Brightness brightness,
    required Color scaffoldBackground,
    required LinearGradient cardGradient,
    required CheddarColors cheddarColors,
  }) {
    final bool isLight = brightness == Brightness.light;
    final textTheme = _buildTextTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      fontFamily: _bodyFont,
      textTheme: textTheme,
      extensions: [cheddarColors],

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: _headlineFont,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
      ),

      cardTheme: CardThemeData(
        elevation: isLight ? 2 : 4,
        shadowColor: isLight
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withValues(alpha: isLight ? 0.45 : 0.50),
        selectedLabelStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 11, fontWeight: FontWeight.w500),
        showUnselectedLabels: true,
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: isLight ? 0.12 : 0.20),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontFamily: _bodyFont, fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary);
          }
          return TextStyle(fontFamily: _bodyFont, fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.55));
        }),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
          textStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
          textStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
          side: BorderSide(color: colorScheme.outline, width: 1.5),
          textStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
          textStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_fabRadius)),
        extendedTextStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w600),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? colorScheme.onSurface.withValues(alpha: 0.04)
            : colorScheme.onSurface.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.md),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(_inputRadius), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_inputRadius), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 2.0),
        ),
        hintStyle: TextStyle(fontFamily: _bodyFont, fontSize: 14, fontWeight: FontWeight.w400, color: colorScheme.onSurface.withValues(alpha: 0.45)),
        labelStyle: TextStyle(fontFamily: _bodyFont, fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.65)),
        floatingLabelStyle: TextStyle(fontFamily: _bodyFont, fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary),
        prefixIconColor: colorScheme.onSurface.withValues(alpha: 0.55),
        suffixIconColor: colorScheme.onSurface.withValues(alpha: 0.55),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? colorScheme.onSurface.withValues(alpha: 0.06)
            : colorScheme.onSurface.withValues(alpha: 0.10),
        selectedColor: colorScheme.primary.withValues(alpha: isLight ? 0.15 : 0.22),
        disabledColor: colorScheme.onSurface.withValues(alpha: 0.04),
        labelStyle: TextStyle(fontFamily: _bodyFont, fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(fontFamily: _bodyFont, fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_chipRadius)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? colorScheme.surface : colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_bottomSheetRadius)),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurface.withValues(alpha: isLight ? 0.2 : 0.35),
        dragHandleSize: const Size(40, 4),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? colorScheme.surface : colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_dialogRadius)),
        titleTextStyle: TextStyle(fontFamily: _headlineFont, fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        contentTextStyle: TextStyle(fontFamily: _bodyFont, fontSize: 14, fontWeight: FontWeight.w400, color: colorScheme.onSurface.withValues(alpha: 0.80)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? colorScheme.onSurface.withValues(alpha: 0.92)
            : colorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(
          fontFamily: _bodyFont, fontSize: 14, fontWeight: FontWeight.w500,
          color: isLight ? Colors.white : colorScheme.onSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
        insetPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.onSurface.withValues(alpha: isLight ? 0.08 : 0.12),
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
        titleTextStyle: TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
        subtitleTextStyle: TextStyle(fontFamily: _bodyFont, fontSize: 13, fontWeight: FontWeight.w400, color: colorScheme.onSurface.withValues(alpha: 0.65)),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.50),
        labelStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 14, fontWeight: FontWeight.w500),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: colorScheme.primary, width: 2.5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
        dividerColor: Colors.transparent,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.onPrimary;
          return colorScheme.onSurface.withValues(alpha: 0.4);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.onSurface.withValues(alpha: 0.14);
        }),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primary.withValues(alpha: 0.12),
        circularTrackColor: colorScheme.primary.withValues(alpha: 0.12),
      ),

      iconTheme: IconThemeData(
        color: colorScheme.onSurface.withValues(alpha: isLight ? 0.75 : 0.90),
        size: 24,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        textStyle: TextStyle(
          fontFamily: _bodyFont, fontSize: 12, fontWeight: FontWeight.w500,
          color: isLight ? Colors.white : colorScheme.surface,
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ══ TEXT THEME ═════════════════════════════════════════════════════════════
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    final Color on = colorScheme.onSurface;
    return TextTheme(
      displayLarge:  TextStyle(fontFamily: _headlineFont, fontSize: 32, fontWeight: FontWeight.w700, color: on, letterSpacing: -0.5),
      displayMedium: TextStyle(fontFamily: _headlineFont, fontSize: 28, fontWeight: FontWeight.w700, color: on, letterSpacing: -0.3),
      displaySmall:  TextStyle(fontFamily: _headlineFont, fontSize: 24, fontWeight: FontWeight.w600, color: on),
      headlineLarge:  TextStyle(fontFamily: _headlineFont, fontSize: 22, fontWeight: FontWeight.w600, color: on),
      headlineMedium: TextStyle(fontFamily: _headlineFont, fontSize: 20, fontWeight: FontWeight.w600, color: on),
      headlineSmall:  TextStyle(fontFamily: _headlineFont, fontSize: 18, fontWeight: FontWeight.w600, color: on),
      titleLarge:  TextStyle(fontFamily: _headlineFont, fontSize: 18, fontWeight: FontWeight.w600, color: on),
      titleMedium: TextStyle(fontFamily: _headlineFont, fontSize: 16, fontWeight: FontWeight.w600, color: on),
      titleSmall:  TextStyle(fontFamily: _headlineFont, fontSize: 14, fontWeight: FontWeight.w500, color: on),
      bodyLarge:   TextStyle(fontFamily: _bodyFont, fontSize: 16, fontWeight: FontWeight.w400, color: on),
      bodyMedium:  TextStyle(fontFamily: _bodyFont, fontSize: 14, fontWeight: FontWeight.w400, color: on),
      bodySmall:   TextStyle(fontFamily: _bodyFont, fontSize: 12, fontWeight: FontWeight.w400, color: on.withValues(alpha: 0.70)),
      labelLarge:  TextStyle(fontFamily: _bodyFont, fontSize: 14, fontWeight: FontWeight.w600, color: on),
      labelMedium: TextStyle(fontFamily: _bodyFont, fontSize: 12, fontWeight: FontWeight.w500, color: on.withValues(alpha: 0.80)),
      labelSmall:  TextStyle(fontFamily: _bodyFont, fontSize: 10, fontWeight: FontWeight.w500, color: on.withValues(alpha: 0.60), letterSpacing: 0.5),
    );
  }
}
