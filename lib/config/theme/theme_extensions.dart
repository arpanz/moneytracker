import 'package:flutter/material.dart';

/// Custom theme extension for Cheddar-specific colors not covered by
/// the standard Material [ColorScheme].
///
/// Access via `Theme.of(context).extension<CheddarColors>()`.
class CheddarColors extends ThemeExtension<CheddarColors> {
  /// Color used for income amounts and indicators.
  final Color income;

  /// Color used for expense amounts and indicators.
  final Color expense;

  /// Color used for transfer amounts and indicators.
  final Color transfer;

  /// Per-category colors keyed by category slug (e.g. 'food', 'transport').
  final Map<String, Color> categoryColors;

  /// Gradient applied to summary / hero cards.
  final LinearGradient cardGradient;

  /// Base color for shimmer loading placeholders.
  final Color shimmerBase;

  /// Highlight color for shimmer loading placeholders.
  final Color shimmerHighlight;

  const CheddarColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.categoryColors,
    required this.cardGradient,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  /// Default light mode instance.
  static CheddarColors light({
    required LinearGradient cardGradient,
  }) {
    return CheddarColors(
      income: const Color(0xFF22C55E),
      expense: const Color(0xFFEF4444),
      transfer: const Color(0xFF3B82F6),
      categoryColors: _defaultCategoryColors,
      cardGradient: cardGradient,
      shimmerBase: const Color(0xFFE5E7EB),
      shimmerHighlight: const Color(0xFFF9FAFB),
    );
  }

  /// Default dark mode instance.
  static CheddarColors dark({
    required LinearGradient cardGradient,
  }) {
    return CheddarColors(
      income: const Color(0xFF4ADE80),
      expense: const Color(0xFFF87171),
      transfer: const Color(0xFF60A5FA),
      categoryColors: _defaultCategoryColors,
      cardGradient: cardGradient,
      shimmerBase: const Color(0xFF374151),
      shimmerHighlight: const Color(0xFF4B5563),
    );
  }

  @override
  CheddarColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Map<String, Color>? categoryColors,
    LinearGradient? cardGradient,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return CheddarColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      categoryColors: categoryColors ?? this.categoryColors,
      cardGradient: cardGradient ?? this.cardGradient,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  CheddarColors lerp(covariant CheddarColors? other, double t) {
    if (other == null) return this;
    return CheddarColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      categoryColors: _lerpCategoryColors(categoryColors, other.categoryColors, t),
      cardGradient: LinearGradient.lerp(cardGradient, other.cardGradient, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }

  /// Interpolates two category-color maps key-by-key.
  static Map<String, Color> _lerpCategoryColors(
    Map<String, Color> a,
    Map<String, Color> b,
    double t,
  ) {
    final keys = {...a.keys, ...b.keys};
    return {
      for (final key in keys)
        key: Color.lerp(
          a[key] ?? Colors.transparent,
          b[key] ?? Colors.transparent,
          t,
        )!,
    };
  }
}

// ── Default category color map (16 categories) ──────────────────────────────
const Map<String, Color> _defaultCategoryColors = {
  'food': Color(0xFFFF6B6B),
  'transport': Color(0xFF4ECDC4),
  'shopping': Color(0xFFFFBE76),
  'bills': Color(0xFF6C5CE7),
  'entertainment': Color(0xFFFF9FF3),
  'health': Color(0xFF55E6C1),
  'education': Color(0xFF48DBFB),
  'travel': Color(0xFFFFA502),
  'gifts': Color(0xFFFF6348),
  'salary': Color(0xFF2ED573),
  'freelance': Color(0xFF1DD1A1),
  'investments': Color(0xFF5352ED),
  'rent': Color(0xFFFF4757),
  'groceries': Color(0xFFA3CB38),
  'pets': Color(0xFFF8A5C2),
  'subscriptions': Color(0xFF7158E2),
};
