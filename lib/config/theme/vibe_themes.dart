import 'package:flutter/material.dart';

/// The available vibe themes in Cheddar.
enum VibeTheme { midnight, matcha, sunset, lavender, ocean, monochrome }

/// Complete color data for a single vibe theme, with both light and dark variants.
class VibeThemeData {
  final String name;
  final String emoji;

  // Light mode colors
  final Color primaryLight;
  final Color secondaryLight;
  final Color surfaceLight;
  final Color backgroundLight;
  final Color onSurfaceLight;

  // Dark mode colors
  final Color primaryDark;
  final Color secondaryDark;
  final Color surfaceDark;
  final Color backgroundDark;
  final Color onSurfaceDark;

  // Accent colors (shared across modes)
  final Color accent;
  final Color accentAlt;

  // Card gradients
  final LinearGradient cardGradientLight;
  final LinearGradient cardGradientDark;

  // Chart colors (8 colors for pie/bar charts)
  final List<Color> chartColors;

  const VibeThemeData({
    required this.name,
    required this.emoji,
    required this.primaryLight,
    required this.secondaryLight,
    required this.surfaceLight,
    required this.backgroundLight,
    required this.onSurfaceLight,
    required this.primaryDark,
    required this.secondaryDark,
    required this.surfaceDark,
    required this.backgroundDark,
    required this.onSurfaceDark,
    required this.accent,
    required this.accentAlt,
    required this.cardGradientLight,
    required this.cardGradientDark,
    required this.chartColors,
  });
}

/// Extension to retrieve the [VibeThemeData] for any [VibeTheme] variant.
extension VibeThemeDataExtension on VibeTheme {
  VibeThemeData get data {
    switch (this) {
      case VibeTheme.midnight:
        return _midnight;
      case VibeTheme.matcha:
        return _matcha;
      case VibeTheme.sunset:
        return _sunset;
      case VibeTheme.lavender:
        return _lavender;
      case VibeTheme.ocean:
        return _ocean;
      case VibeTheme.monochrome:
        return _monochrome;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MIDNIGHT — deep navy + gold
// ════════════════════════════════════════════════════════════════════════════
const _midnight = VibeThemeData(
  name: 'Midnight',
  emoji: '\u{1F30C}',
  // Light
  primaryLight: Color(0xFF1A1A3E),
  secondaryLight: Color(0xFFF0C040),
  surfaceLight: Color(0xFFF2F1F6),
  backgroundLight: Color(0xFFFAF9FE),
  onSurfaceLight: Color(0xFF1A1A2E),
  // Dark
  primaryDark: Color(0xFFF0C040),
  secondaryDark: Color(0xFF6C63FF),
  surfaceDark: Color(0xFF1A1A3E),
  backgroundDark: Color(0xFF0F0E2E),
  onSurfaceDark: Color(0xFFE8E6F0),
  // Accents
  accent: Color(0xFFF0C040),
  accentAlt: Color(0xFF6C63FF),
  // Gradients
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A3E), Color(0xFF2D2B5E)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1E42), Color(0xFF0F0E2E)],
  ),
  // Chart colors
  chartColors: [
    Color(0xFFF0C040),
    Color(0xFF6C63FF),
    Color(0xFF4ECDC4),
    Color(0xFFFF6B6B),
    Color(0xFF45B7D1),
    Color(0xFFFF9F43),
    Color(0xFFA29BFE),
    Color(0xFF2ED573),
  ],
);

// ════════════════════════════════════════════════════════════════════════════
// MATCHA — forest green + cream
// ════════════════════════════════════════════════════════════════════════════
const _matcha = VibeThemeData(
  name: 'Matcha',
  emoji: '\u{1F375}',
  // Light
  primaryLight: Color(0xFF2D5016),
  secondaryLight: Color(0xFF8DB580),
  surfaceLight: Color(0xFFF5F0E1),
  backgroundLight: Color(0xFFFAF7EE),
  onSurfaceLight: Color(0xFF2D3B1A),
  // Dark
  primaryDark: Color(0xFF8DB580),
  secondaryDark: Color(0xFFC4A35A),
  surfaceDark: Color(0xFF1E2A14),
  backgroundDark: Color(0xFF141E0C),
  onSurfaceDark: Color(0xFFE8E4D4),
  // Accents
  accent: Color(0xFF5A8F3C),
  accentAlt: Color(0xFFC4A35A),
  // Gradients
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D5016), Color(0xFF3D6B22)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E2A14), Color(0xFF2D3B1A)],
  ),
  // Chart colors
  chartColors: [
    Color(0xFF5A8F3C),
    Color(0xFFC4A35A),
    Color(0xFF8DB580),
    Color(0xFFD4915E),
    Color(0xFF6BBF7A),
    Color(0xFF9B8A5E),
    Color(0xFF3D8B6E),
    Color(0xFFE8C547),
  ],
);

// ════════════════════════════════════════════════════════════════════════════
// SUNSET — coral + orange
// ════════════════════════════════════════════════════════════════════════════
const _sunset = VibeThemeData(
  name: 'Sunset',
  emoji: '\u{1F305}',
  // Light
  primaryLight: Color(0xFFFF6B6B),
  secondaryLight: Color(0xFFFFA44F),
  surfaceLight: Color(0xFFFFF5EC),
  backgroundLight: Color(0xFFFFFAF5),
  onSurfaceLight: Color(0xFF3D2C2C),
  // Dark
  primaryDark: Color(0xFFFF8E8E),
  secondaryDark: Color(0xFFFFBE76),
  surfaceDark: Color(0xFF2E1F1F),
  backgroundDark: Color(0xFF1E1414),
  onSurfaceDark: Color(0xFFF5E6DC),
  // Accents
  accent: Color(0xFFFF6B6B),
  accentAlt: Color(0xFFFFA44F),
  // Gradients
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFFFA44F)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B3A3A), Color(0xFF8B6430)],
  ),
  // Chart colors
  chartColors: [
    Color(0xFFFF6B6B),
    Color(0xFFFFA44F),
    Color(0xFFFFD93D),
    Color(0xFFFF8E8E),
    Color(0xFFFFBE76),
    Color(0xFFF78FB3),
    Color(0xFFFF6348),
    Color(0xFFFFB142),
  ],
);

// ════════════════════════════════════════════════════════════════════════════
// LAVENDER — purple + pink
// ════════════════════════════════════════════════════════════════════════════
const _lavender = VibeThemeData(
  name: 'Lavender',
  emoji: '\u{1F49C}',
  // Light
  primaryLight: Color(0xFF7C3AED),
  secondaryLight: Color(0xFFEC4899),
  surfaceLight: Color(0xFFF5F0FF),
  backgroundLight: Color(0xFFFAF5FF),
  onSurfaceLight: Color(0xFF2E1065),
  // Dark
  primaryDark: Color(0xFFA78BFA),
  secondaryDark: Color(0xFFF472B6),
  surfaceDark: Color(0xFF1E1535),
  backgroundDark: Color(0xFF140E26),
  onSurfaceDark: Color(0xFFEDE4F7),
  // Accents
  accent: Color(0xFF7C3AED),
  accentAlt: Color(0xFFEC4899),
  // Gradients
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4C1D95), Color(0xFF831843)],
  ),
  // Chart colors
  chartColors: [
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFFA78BFA),
    Color(0xFFF472B6),
    Color(0xFF8B5CF6),
    Color(0xFFF9A8D4),
    Color(0xFF6D28D9),
    Color(0xFFDB2777),
  ],
);

// ════════════════════════════════════════════════════════════════════════════
// OCEAN — teal + navy
// ════════════════════════════════════════════════════════════════════════════
const _ocean = VibeThemeData(
  name: 'Ocean',
  emoji: '\u{1F30A}',
  // Light
  primaryLight: Color(0xFF0D9488),
  secondaryLight: Color(0xFF1E3A5F),
  surfaceLight: Color(0xFFEFF9F8),
  backgroundLight: Color(0xFFF0FDFA),
  onSurfaceLight: Color(0xFF134E48),
  // Dark
  primaryDark: Color(0xFF2DD4BF),
  secondaryDark: Color(0xFF38BDF8),
  surfaceDark: Color(0xFF0C1F2C),
  backgroundDark: Color(0xFF081419),
  onSurfaceDark: Color(0xFFD5F5F0),
  // Accents
  accent: Color(0xFF0D9488),
  accentAlt: Color(0xFF38BDF8),
  // Gradients
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D9488), Color(0xFF1E3A5F)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF064E3B), Color(0xFF0C2340)],
  ),
  // Chart colors
  chartColors: [
    Color(0xFF0D9488),
    Color(0xFF38BDF8),
    Color(0xFF2DD4BF),
    Color(0xFF1E3A5F),
    Color(0xFF06B6D4),
    Color(0xFFB2F5EA),
    Color(0xFF0EA5E9),
    Color(0xFF14B8A6),
  ],
);

// ════════════════════════════════════════════════════════════════════════════
// MONOCHROME — pure grays
// ════════════════════════════════════════════════════════════════════════════
const _monochrome = VibeThemeData(
  name: 'Monochrome',
  emoji: '\u{26AB}',
  // Light
  primaryLight: Color(0xFF2D2D2D),
  secondaryLight: Color(0xFF6B7280),
  surfaceLight: Color(0xFFF3F4F6),
  backgroundLight: Color(0xFFFAFAFA),
  onSurfaceLight: Color(0xFF1F2937),
  // Dark
  primaryDark: Color(0xFFE5E7EB),
  secondaryDark: Color(0xFF9CA3AF),
  surfaceDark: Color(0xFF1F1F1F),
  backgroundDark: Color(0xFF141414),
  onSurfaceDark: Color(0xFFE5E7EB),
  // Accents
  accent: Color(0xFF6B7280),
  accentAlt: Color(0xFF9CA3AF),
  // Gradients
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF374151), Color(0xFF4B5563)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F1F1F), Color(0xFF2D2D2D)],
  ),
  // Chart colors
  chartColors: [
    Color(0xFF374151),
    Color(0xFF6B7280),
    Color(0xFF9CA3AF),
    Color(0xFF4B5563),
    Color(0xFFD1D5DB),
    Color(0xFF1F2937),
    Color(0xFF111827),
    Color(0xFFF3F4F6),
  ],
);
