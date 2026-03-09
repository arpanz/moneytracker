import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vibe_themes.dart';
import 'theme_extensions.dart';
import 'spacing.dart';

/// Builds complete [ThemeData] instances for light and dark modes,
/// parameterized by the user's chosen [VibeTheme].
class AppTheme {
  AppTheme._();

  // ── Typography constants ──
  static const String _headlineFont = 'Poppins';
  static const String _bodyFont = 'Inter';

  // ── Border radius tokens ──
  static const double _cardRadius = 16.0;
  static const double _buttonRadius = 12.0;
  static const double _chipRadius = 28.0;
  static const double _inputRadius = 12.0;
  static const double _fabRadius = 16.0;
  static const double _bottomSheetRadius = 24.0;
  static const double _dialogRadius = 20.0;

  // ════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ════════════════════════════════════════════════════════════════════════
  static ThemeData lightTheme(VibeTheme vibe) {
    final data = vibe.data;
    final colorScheme = ColorScheme.light(
      primary: data.primaryLight,
      secondary: data.secondaryLight,
      surface: data.surfaceLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: data.onSurfaceLight,
      error: const Color(0xFFDC2626),
      onError: Colors.white,
      outline: data.onSurfaceLight.withValues(alpha: 0.12),
    );

    return _buildThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackground: data.backgroundLight,
      cardGradient: data.cardGradientLight,
      cheddarColors: CheddarColors.light(
        cardGradient: data.cardGradientLight,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ════════════════════════════════════════════════════════════════════════
  static ThemeData darkTheme(VibeTheme vibe) {
    final data = vibe.data;
    final colorScheme = ColorScheme.dark(
      primary: data.primaryDark,
      secondary: data.secondaryDark,
      surface: data.surfaceDark,
      onPrimary: data.backgroundDark,
      onSecondary: data.backgroundDark,
      onSurface: data.onSurfaceDark,
      error: const Color(0xFFF87171),
      onError: const Color(0xFF1E1E1E),
      outline: data.onSurfaceDark.withValues(alpha: 0.12),
    );

    return _buildThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackground: data.backgroundDark,
      cardGradient: data.cardGradientDark,
      cheddarColors: CheddarColors.dark(
        cardGradient: data.cardGradientDark,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SHARED BUILDER
  // ════════════════════════════════════════════════════════════════════════
  static ThemeData _buildThemeData({
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

      // ── Extensions ──
      extensions: [cheddarColors],

      // ── AppBar ──
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

      // ── Card ──
      cardTheme: CardThemeData(
        elevation: isLight ? 2 : 0,
        shadowColor: colorScheme.primary.withValues(alpha: isLight ? 0.08 : 0.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
      ),

      // ── Bottom Navigation Bar ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.45),
        selectedLabelStyle: const TextStyle(
          fontFamily: _bodyFont,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: _bodyFont,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        showUnselectedLabels: true,
      ),

      // ── Navigation Bar (Material 3) ──
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: _bodyFont,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontFamily: _bodyFont,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          );
        }),
      ),

      // ── Elevated Button ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: _bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Filled Button ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: _bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Outlined Button ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
          side: BorderSide(
            color: colorScheme.outline,
            width: 1.5,
          ),
          textStyle: const TextStyle(
            fontFamily: _bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text Button ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: _bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Floating Action Button ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_fabRadius),
        ),
        extendedTextStyle: const TextStyle(
          fontFamily: _bodyFont,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Input Decoration (Text Fields) ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? colorScheme.onSurface.withValues(alpha: 0.04)
            : colorScheme.onSurface.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2.0,
          ),
        ),
        hintStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface.withValues(alpha: 0.45),
        ),
        labelStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface.withValues(alpha: 0.65),
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        prefixIconColor: colorScheme.onSurface.withValues(alpha: 0.55),
        suffixIconColor: colorScheme.onSurface.withValues(alpha: 0.55),
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? colorScheme.onSurface.withValues(alpha: 0.06)
            : colorScheme.onSurface.withValues(alpha: 0.08),
        selectedColor: colorScheme.primary.withValues(alpha: 0.15),
        disabledColor: colorScheme.onSurface.withValues(alpha: 0.04),
        labelStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_chipRadius),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_bottomSheetRadius),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurface.withValues(alpha: 0.2),
        dragHandleSize: const Size(40, 4),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_dialogRadius),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _headlineFont,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),

      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? colorScheme.onSurface.withValues(alpha: 0.9)
            : colorScheme.surface,
        contentTextStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isLight ? Colors.white : colorScheme.onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: colorScheme.onSurface.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ──
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),

      // ── Tab Bar ──
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.5),
        labelStyle: const TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2.5,
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(3),
          ),
        ),
        dividerColor: Colors.transparent,
      ),

      // ── Switch ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.onSurface.withValues(alpha: 0.4);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurface.withValues(alpha: 0.12);
        }),
      ),

      // ── Progress Indicator ──
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primary.withValues(alpha: 0.12),
        circularTrackColor: colorScheme.primary.withValues(alpha: 0.12),
      ),

      // ── Icon ──
      iconTheme: IconThemeData(
        color: colorScheme.onSurface.withValues(alpha: 0.75),
        size: 24,
      ),

      // ── Tooltip ──
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        textStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isLight ? Colors.white : colorScheme.surface,
        ),
      ),

      // ── Page transitions ──
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // TEXT THEME
  // ════════════════════════════════════════════════════════════════════════
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    final Color onSurface = colorScheme.onSurface;

    return TextTheme(
      // ── Display ──
      displayLarge: TextStyle(
        fontFamily: _headlineFont,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: _headlineFont,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      displaySmall: TextStyle(
        fontFamily: _headlineFont,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      // ── Headline ──
      headlineLarge: TextStyle(
        fontFamily: _headlineFont,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: _headlineFont,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: _headlineFont,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      // ── Title ──
      titleLarge: TextStyle(
        fontFamily: _headlineFont,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: _headlineFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: _headlineFont,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      // ── Body ──
      bodyLarge: TextStyle(
        fontFamily: _bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: _bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: _bodyFont,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: onSurface.withValues(alpha: 0.65),
      ),
      // ── Label ──
      labelLarge: TextStyle(
        fontFamily: _bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: _bodyFont,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onSurface.withValues(alpha: 0.75),
      ),
      labelSmall: TextStyle(
        fontFamily: _bodyFont,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: onSurface.withValues(alpha: 0.55),
        letterSpacing: 0.5,
      ),
    );
  }
}
