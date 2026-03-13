import 'package:flutter/material.dart';

enum VibeTheme { midnight, matcha, sunset, lavender, ocean, monochrome }

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
      case VibeTheme.sunset:     return _sunset;
      case VibeTheme.lavender:   return _lavender;
      case VibeTheme.ocean:      return _ocean;
      case VibeTheme.monochrome: return _monochrome;
    }
  }
}

// ══ MIDNIGHT — deep navy + gold ═══════════════════════════════════════════════
const _midnight = VibeThemeData(
  name: 'Midnight',
  emoji: '\u{1F30C}',
  primaryLight:    Color(0xFF1A1A3E),
  secondaryLight:  Color(0xFFF0C040),
  surfaceLight:    Color(0xFFF2F1F6),
  backgroundLight: Color(0xFFFAF9FE),
  onSurfaceLight:  Color(0xFF1A1A2E),
  // Dark — boosted: brighter gold primary, pure white text, lifted surfaces
  primaryDark:    Color(0xFFFFD166),
  secondaryDark:  Color(0xFF9D8FFF),
  surfaceDark:    Color(0xFF1F1F48),
  backgroundDark: Color(0xFF12113A),
  onSurfaceDark:  Color(0xFFF5F3FF),
  accent:    Color(0xFFF0C040),
  accentAlt: Color(0xFF6C63FF),
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A3E), Color(0xFF2D2B5E)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2A2A5A), Color(0xFF16154A)],
  ),
  chartColors: [
    Color(0xFFFFD166), Color(0xFF9D8FFF), Color(0xFF4ECDC4),
    Color(0xFFFF6B6B), Color(0xFF45B7D1), Color(0xFFFF9F43),
    Color(0xFFA29BFE), Color(0xFF2ED573),
  ],
);

// ══ MATCHA — forest green + cream ════════════════════════════════════════════
const _matcha = VibeThemeData(
  name: 'Matcha',
  emoji: '\u{1F375}',
  primaryLight:    Color(0xFF2D5016),
  secondaryLight:  Color(0xFF8DB580),
  surfaceLight:    Color(0xFFF5F0E1),
  backgroundLight: Color(0xFFFAF7EE),
  onSurfaceLight:  Color(0xFF2D3B1A),
  // Dark — lifted greens, warm cream text
  primaryDark:    Color(0xFFA8D5A2),
  secondaryDark:  Color(0xFFD4B87A),
  surfaceDark:    Color(0xFF1F2E14),
  backgroundDark: Color(0xFF131A0B),
  onSurfaceDark:  Color(0xFFF2EEE0),
  accent:    Color(0xFF5A8F3C),
  accentAlt: Color(0xFFC4A35A),
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2D5016), Color(0xFF3D6B22)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF253A18), Color(0xFF1A2610)],
  ),
  chartColors: [
    Color(0xFF7ABF5A), Color(0xFFD4B87A), Color(0xFF8DB580),
    Color(0xFFE8A07A), Color(0xFF6BBF7A), Color(0xFF9B8A5E),
    Color(0xFF3D8B6E), Color(0xFFE8C547),
  ],
);

// ══ SUNSET — coral + orange ═══════════════════════════════════════════════════
const _sunset = VibeThemeData(
  name: 'Sunset',
  emoji: '\u{1F305}',
  primaryLight:    Color(0xFFFF6B6B),
  secondaryLight:  Color(0xFFFFA44F),
  surfaceLight:    Color(0xFFFFF5EC),
  backgroundLight: Color(0xFFFFFAF5),
  onSurfaceLight:  Color(0xFF3D2C2C),
  // Dark — vivid coral, warm white text, deeper background
  primaryDark:    Color(0xFFFF8E8E),
  secondaryDark:  Color(0xFFFFCA8A),
  surfaceDark:    Color(0xFF2C1E1E),
  backgroundDark: Color(0xFF1A1010),
  onSurfaceDark:  Color(0xFFFFF0E8),
  accent:    Color(0xFFFF6B6B),
  accentAlt: Color(0xFFFFA44F),
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFFFA44F)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF6B2A2A), Color(0xFF7A5020)],
  ),
  chartColors: [
    Color(0xFFFF8E8E), Color(0xFFFFCA8A), Color(0xFFFFD93D),
    Color(0xFFFF6B6B), Color(0xFFFFBE76), Color(0xFFF78FB3),
    Color(0xFFFF6348), Color(0xFFFFB142),
  ],
);

// ══ LAVENDER — purple + pink ══════════════════════════════════════════════════
const _lavender = VibeThemeData(
  name: 'Lavender',
  emoji: '\u{1F49C}',
  primaryLight:    Color(0xFF7C3AED),
  secondaryLight:  Color(0xFFEC4899),
  surfaceLight:    Color(0xFFF5F0FF),
  backgroundLight: Color(0xFFFAF5FF),
  onSurfaceLight:  Color(0xFF2E1065),
  // Dark — brighter violet, vivid pink, near-white text
  primaryDark:    Color(0xFFBBA4FF),
  secondaryDark:  Color(0xFFFF85C2),
  surfaceDark:    Color(0xFF1E1535),
  backgroundDark: Color(0xFF120D24),
  onSurfaceDark:  Color(0xFFF5EFFF),
  accent:    Color(0xFF7C3AED),
  accentAlt: Color(0xFFEC4899),
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF3B1A7A), Color(0xFF6B1A45)],
  ),
  chartColors: [
    Color(0xFFBBA4FF), Color(0xFFFF85C2), Color(0xFFA78BFA),
    Color(0xFFF472B6), Color(0xFF8B5CF6), Color(0xFFF9A8D4),
    Color(0xFF6D28D9), Color(0xFFDB2777),
  ],
);

// ══ OCEAN — teal + navy ═══════════════════════════════════════════════════════
const _ocean = VibeThemeData(
  name: 'Ocean',
  emoji: '\u{1F30A}',
  primaryLight:    Color(0xFF0D9488),
  secondaryLight:  Color(0xFF1E3A5F),
  surfaceLight:    Color(0xFFEFF9F8),
  backgroundLight: Color(0xFFF0FDFA),
  onSurfaceLight:  Color(0xFF134E48),
  // Dark — vivid teal, sky blue, near-white text, deeper ocean bg
  primaryDark:    Color(0xFF34EDD8),
  secondaryDark:  Color(0xFF56CFFF),
  surfaceDark:    Color(0xFF0C1E2C),
  backgroundDark: Color(0xFF071018),
  onSurfaceDark:  Color(0xFFE8F8F5),
  accent:    Color(0xFF0D9488),
  accentAlt: Color(0xFF38BDF8),
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0D9488), Color(0xFF1E3A5F)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0A3D30), Color(0xFF0A1E38)],
  ),
  chartColors: [
    Color(0xFF34EDD8), Color(0xFF56CFFF), Color(0xFF2DD4BF),
    Color(0xFF1E3A5F), Color(0xFF06B6D4), Color(0xFFB2F5EA),
    Color(0xFF0EA5E9), Color(0xFF14B8A6),
  ],
);

// ══ MONOCHROME — pure grays ═══════════════════════════════════════════════════
const _monochrome = VibeThemeData(
  name: 'Monochrome',
  emoji: '\u{26AB}',
  primaryLight:    Color(0xFF2D2D2D),
  secondaryLight:  Color(0xFF6B7280),
  surfaceLight:    Color(0xFFF3F4F6),
  backgroundLight: Color(0xFFFAFAFA),
  onSurfaceLight:  Color(0xFF1F2937),
  // Dark — bright white primary, higher contrast grays
  primaryDark:    Color(0xFFF3F4F6),
  secondaryDark:  Color(0xFFB0B8C4),
  surfaceDark:    Color(0xFF1C1C1C),
  backgroundDark: Color(0xFF111111),
  onSurfaceDark:  Color(0xFFF0F2F4),
  accent:    Color(0xFF6B7280),
  accentAlt: Color(0xFF9CA3AF),
  cardGradientLight: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF374151), Color(0xFF4B5563)],
  ),
  cardGradientDark: LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2A2A2A), Color(0xFF1C1C1C)],
  ),
  chartColors: [
    Color(0xFFF3F4F6), Color(0xFF9CA3AF), Color(0xFFD1D5DB),
    Color(0xFF6B7280), Color(0xFFE5E7EB), Color(0xFF4B5563),
    Color(0xFF374151), Color(0xFFFFFFFF),
  ],
);
