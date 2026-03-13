import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_provider.dart';
import '../../../../config/theme/vibe_themes.dart';

/// Screen for picking the app's vibe theme.
class ThemePickerScreen extends ConsumerWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentTheme = ref.watch(themeProvider);
    final allThemes = VibeTheme.values;

    return Scaffold(
      appBar: AppBar(title: const Text('Theme & Vibes')),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.85,
        ),
        itemCount: allThemes.length,
        itemBuilder: (context, index) {
          final vibe = allThemes[index];
          final isSelected = currentTheme.vibeTheme == vibe;

          return _ThemeCard(
                vibe: vibe,
                isSelected: isSelected,
                onTap: () {
                  ref.read(themeProvider.notifier).setVibeTheme(vibe);
                },
              )
              .animate(delay: (index * 80).ms)
              .fadeIn(duration: 300.ms)
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
        },
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final VibeTheme vibe;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.vibe,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = vibe.data;
    final isDark = theme.brightness == Brightness.dark;
    final previewPrimary = isDark ? d.primaryDark : d.primaryLight;
    final previewSecondary = isDark ? d.secondaryDark : d.secondaryLight;
    final previewAccent = isDark ? d.accentAlt : d.accent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isSelected
                ? previewPrimary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: previewPrimary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg - 1),
          child: Column(
            children: [
              // Color preview header
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [previewPrimary, previewSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(d.emoji, style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: AppSpacing.xs),
                        // Color dots preview
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ColorDot(color: previewPrimary),
                            _ColorDot(color: previewSecondary),
                            _ColorDot(color: previewAccent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Name and status
              Expanded(
                flex: 2,
                child: Container(
                  color: theme.colorScheme.surface,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        d.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Icon(
                          Icons.check_circle_rounded,
                          color: previewPrimary,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
    );
  }
}
