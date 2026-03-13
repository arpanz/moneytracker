import 'package:flutter/material.dart';

// Only 3 curated themes: Midnight, Matcha, Monochrome
enum VibeTheme { midnight, matcha, monochrome }

class VibeThemeData {
  final String name;
  final String emoji;
  final Color primaryLight;
  final Color secondaryLight;
  final Color surfaceLight;
  final Color backgroundLight;
  final Color onSurfaceLight;
  final Color primaryDark;
  final Color secondaryDark;
  final Color surfaceDark;
  final Color backgroundDark;
  final Color onSurfaceDark;
  final Color accent;
  final Color accentAlt;
  final LinearGradient cardGradientLight;
  final LinearGradient cardGradientDark;
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

extension VibeThemeDataExtension on VibeTheme {
  VibeThemeData get data {
    switch (this) {
      case VibeTheme.midnight:   return _midnight;
      case VibeTheme.matcha:     return _matcha;
      case VibeTheme.monochrome: return _monochrome;
    }
  }
}

// ══ MIDNIGHT — deep navy + gold ════════════════════════════════════════════════
// Dark mode: boosted gold primary, rich navy surfaces, near-white text
const _midnight = VibeThemeData(
  name: 'Midnight',
  emoji: '\u{1F30C}',
  primaryLight:    Color(0xFF2A2A6E),
  secondaryLight:  Color(0xFFF0C040),
  surfaceLight:    Color(0xFFF2F1F6),
  backgroundLight: Color(0xFFFAF9FE),
  onSurfaceLight:  Color(0xFF1A1A2E),
  // Dark: vivid gold as primary, distinct tonal surfaces, crisp white text
  primaryDark:    Color(0xFFFFD166),
  secondaryDark:  Color(0xFFB8ACFF),
  surfaceDark:    Color(0xFF1E1E4A),
  backgroundDark: Color(0xFF0F0E2E),
  onSurfaceDark:  Color(0xFFF8F6FF),
  accent:    Color(0xFFFFD166),
  accentAlt: Color(0xFF7C74FF),
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2A2A6E), Color(0xFF3D3B80)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2E2D6B), Color(0xFF191845)],
  ),
  chartColors: [
    Color(0xFFFFD166), Color(0xFFB8ACFF), Color(0xFF4ECDC4),
    Color(0xFFFF8E8E), Color(0xFF56CFFF), Color(0xFFFF9F43),
    Color(0xFFA29BFE), Color(0xFF2ED573),
  ],
);

// ══ MATCHA — forest green + warm cream ════════════════════════════════════════
// Dark mode: luminous sage primary, warm amber secondary, deep forest bg
const _matcha = VibeThemeData(
  name: 'Matcha',
  emoji: '\u{1F375}',
  primaryLight:    Color(0xFF2D5016),
  secondaryLight:  Color(0xFF8DB580),
  surfaceLight:    Color(0xFFF5F0E1),
  backgroundLight: Color(0xFFFAF7EE),
  onSurfaceLight:  Color(0xFF2D3B1A),
  // Dark: bright sage primary, golden amber secondary, deep forest bg
  primaryDark:    Color(0xFFB4E0AE),
  secondaryDark:  Color(0xFFE8C97A),
  surfaceDark:    Color(0xFF1A2A10),
  backgroundDark: Color(0xFF0E1808),
  onSurfaceDark:  Color(0xFFF4F0E2),
  accent:    Color(0xFF5A8F3C),
  accentAlt: Color(0xFFC4A35A),
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2D5016), Color(0xFF3D6B22)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF243D15), Color(0xFF162410)],
  ),
  chartColors: [
    Color(0xFF8FCC85), Color(0xFFE8C97A), Color(0xFF70C4A8),
    Color(0xFFE8A07A), Color(0xFF6BBF7A), Color(0xFFB8A86E),
    Color(0xFF3D8B6E), Color(0xFFE8C547),
  ],
);

// ══ MONOCHROME — clean grays ═══════════════════════════════════════════════════
// Dark mode: bright white primary, high-contrast grays, true black bg
const _monochrome = VibeThemeData(
  name: 'Monochrome',
  emoji: '\u{26AB}',
  primaryLight:    Color(0xFF1F2937),
  secondaryLight:  Color(0xFF6B7280),
  surfaceLight:    Color(0xFFF3F4F6),
  backgroundLight: Color(0xFFFAFAFA),
  onSurfaceLight:  Color(0xFF111827),
  // Dark: pure white primary, layered grays, true-black bg for AMOLED
  primaryDark:    Color(0xFFF9FAFB),
  secondaryDark:  Color(0xFFD1D5DB),
  surfaceDark:    Color(0xFF1C1C1E),
  backgroundDark: Color(0xFF000000),
  onSurfaceDark:  Color(0xFFF2F4F6),
  accent:    Color(0xFF6B7280),
  accentAlt: Color(0xFF9CA3AF),
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1F2937), Color(0xFF374151)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
  ),
  // 5 visually distinct grays — no near-white duplicates
  chartColors: [
    Color(0xFFF9FAFB), Color(0xFFADB5BD), Color(0xFF6C757D),
    Color(0xFF495057), Color(0xFF343A40), Color(0xFFCED4DA),
    Color(0xFF868E96), Color(0xFFDEE2E6),
  ],
);
