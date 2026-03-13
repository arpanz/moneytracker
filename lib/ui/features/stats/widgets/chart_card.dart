import 'package:flutter/material.dart';

import '../../../../config/theme/spacing.dart';

/// Reusable chart container card with consistent styling across all stats sections.
///
/// Provides a rounded container with theme card background, subtle shadow,
/// title row, optional subtitle, and optional action button.
class ChartCard extends StatelessWidget {
  /// Title displayed at the top of the card.
  final String title;

  /// Optional subtitle displayed below the title.
  final String? subtitle;

  /// Optional action widget (e.g., "See more" button) displayed on the right.
  final Widget? action;

  /// The chart or content widget displayed inside the card.
  final Widget child;

  /// Optional fixed height for the chart content area.
  final double? chartHeight;

  /// Animation delay for staggered entrance.
  final Duration animationDelay;

  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    required this.child,
    this.chartHeight,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: Radii.borderLg,
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: Spacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (action != null) action!,
                  ],
                ),
                const SizedBox(height: Spacing.md),
                if (chartHeight != null)
                  SizedBox(height: chartHeight, child: child)
                else
                  child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
