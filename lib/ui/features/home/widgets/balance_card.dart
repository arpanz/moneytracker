import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';

/// Glassmorphism-styled card displaying the total balance.
///
/// Uses [BackdropFilter] for the frosted-glass effect, the theme's
/// [CheddarColors.cardGradient] for the background, and a
/// [TweenAnimationBuilder] for an animated number counter.
class BalanceCard extends StatelessWidget {
  /// The balance to display.
  final double balance;

  /// The currency symbol to prefix the amount.
  final String currencySymbol;

  const BalanceCard({
    super.key,
    required this.balance,
    this.currencySymbol = AppConstants.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cheddarColors = theme.extension<CheddarColors>();

    final gradient = cheddarColors?.cardGradient ??
        LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
        );

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.xl,
          ),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Balance',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: balance),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Text(
                    '$currencySymbol ${_formatAmount(value)}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats a double as a comma-separated string with 2 decimal places.
  ///
  /// Uses Indian-style grouping: last 3 digits, then groups of 2.
  static String _formatAmount(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    // Split into integer and decimal parts.
    final intPart = absAmount.truncate();
    final decPart = ((absAmount - intPart) * 100).round();

    final intStr = intPart.toString();
    final buffer = StringBuffer();

    if (intStr.length <= 3) {
      buffer.write(intStr);
    } else {
      final lastThree = intStr.substring(intStr.length - 3);
      final remaining = intStr.substring(0, intStr.length - 3);
      buffer.write(remaining.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{2})+$)'),
        (match) => '${match[1]},',
      ));
      buffer.write(',');
      buffer.write(lastThree);
    }

    buffer.write('.');
    buffer.write(decPart.toString().padLeft(2, '0'));

    return isNegative ? '-${buffer.toString()}' : buffer.toString();
  }
}
