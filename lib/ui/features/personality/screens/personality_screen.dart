import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/theme/spacing.dart';
import '../providers/personality_provider.dart';

/// Monthly spending personality screen with animated illustration,
/// category breakdown, and share capability.
class PersonalityScreen extends ConsumerStatefulWidget {
  const PersonalityScreen({super.key});

  @override
  ConsumerState<PersonalityScreen> createState() => _PersonalityScreenState();
}

class _PersonalityScreenState extends ConsumerState<PersonalityScreen> {
  final GlobalKey _screenshotKey = GlobalKey();

  Future<void> _sharePersonality(PersonalityData data) async {
    try {
      final boundary =
          _screenshotKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'cheddar_personality.png',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'I\'m ${data.title} on Cheddar! ${data.description}',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final personalityAsync = ref.watch(personalityProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      body: personalityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: Spacing.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  'Could not analyze spending',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  '$error',
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (data) => _buildContent(context, data),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PersonalityData data) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                data.gradientColors[0],
                data.gradientColors[1],
                theme.scaffoldBackgroundColor,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // AppBar row
                Padding(
                  padding: Spacing.horizontalMd,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        'My Spending Personality',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.lg),

                // Screenshot-able area
                RepaintBoundary(
                  key: _screenshotKey,
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        // SVG illustration
                        SvgPicture.asset(data.svgPath, width: 180, height: 180)
                            .animate()
                            .scale(
                              begin: const Offset(0.5, 0.5),
                              end: const Offset(1.0, 1.0),
                              duration: 600.ms,
                              curve: Curves.elasticOut,
                            )
                            .fadeIn(duration: 400.ms),
                        const SizedBox(height: Spacing.lg),

                        // Emoji
                        Text(
                          data.emoji,
                          style: const TextStyle(fontSize: 48),
                        ).animate().scale(
                          delay: 200.ms,
                          duration: 400.ms,
                          curve: Curves.bounceOut,
                        ),
                        const SizedBox(height: Spacing.sm),

                        // Title
                        Text(
                              data.title,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 400.ms)
                            .slideY(begin: 0.3, end: 0, duration: 400.ms),
                        const SizedBox(height: Spacing.sm),

                        // Description
                        Padding(
                          padding: Spacing.horizontalLg,
                          child: Text(
                            data.description,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xl),

                // Category breakdown card
                _buildCategoryBreakdown(context, data)
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 500.ms)
                    .slideY(begin: 0.2, end: 0, duration: 500.ms),
                const SizedBox(height: Spacing.md),

                // Fun fact card
                _buildFunFactCard(context, data)
                    .animate()
                    .fadeIn(delay: 800.ms, duration: 500.ms)
                    .slideY(begin: 0.2, end: 0, duration: 500.ms),
                const SizedBox(height: Spacing.lg),

                // Total spent
                Text(
                  'Total spent this month: Rs. ${_formatAmount(data.totalSpent)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ).animate().fadeIn(delay: 900.ms),
                const SizedBox(height: Spacing.lg),

                // Share button
                Padding(
                  padding: Spacing.horizontalLg,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _sharePersonality(data),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share My Personality'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: Radii.borderMd,
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.3, end: 0),
                const SizedBox(height: Spacing.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown(BuildContext context, PersonalityData data) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Sort categories by percentage descending, take top 5
    final sorted = data.categoryPercentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();

    if (top5.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: Spacing.horizontalMd,
      child: Card(
        child: Padding(
          padding: Spacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category Breakdown',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.md),
              ...top5.asMap().entries.map((entry) {
                final i = entry.key;
                final cat = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CategoryBar(
                    category: cat.key,
                    percentage: cat.value,
                    color: data.gradientColors[0].withOpacity(
                      1.0 - (i * 0.15).clamp(0.0, 0.6),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFunFactCard(BuildContext context, PersonalityData data) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: Spacing.horizontalMd,
      child: Card(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        child: Padding(
          padding: Spacing.paddingMd,
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fun Fact',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(data.funFact, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)} L';
    } else if (amount >= 1000) {
      return _formatIndian(amount);
    }
    return amount.toStringAsFixed(0);
  }

  String _formatIndian(double amount) {
    final intPart = amount.toInt().toString();
    if (intPart.length <= 3) return intPart;
    String result = intPart.substring(intPart.length - 3);
    String remaining = intPart.substring(0, intPart.length - 3);
    while (remaining.length > 2) {
      result = '${remaining.substring(remaining.length - 2)},$result';
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      result = '$remaining,$result';
    }
    return result;
  }
}

class _CategoryBar extends StatelessWidget {
  final String category;
  final double percentage;
  final Color color;

  const _CategoryBar({
    required this.category,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category, style: textTheme.bodySmall),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: Radii.borderFull,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percentage / 100),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              );
            },
          ),
        ),
      ],
    );
  }
}
