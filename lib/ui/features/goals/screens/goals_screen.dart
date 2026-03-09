import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/goal_model.dart';

/// Goal list screen with GridView of jar illustrations showing progress.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final goalRepo = ref.watch(goalRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          FutureBuilder<double>(
            future: goalRepo.getTotalSaved(),
            builder: (context, snapshot) {
              final total = snapshot.data ?? 0;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: Radii.borderFull,
                    ),
                    child: Text(
                      'Rs. ${_formatIndian(total)}',
                      style: textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<GoalModel>>(
        future: goalRepo.getAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allGoals = snapshot.data ?? [];
          if (allGoals.isEmpty) {
            return _buildEmptyState(context);
          }

          final activeGoals =
              allGoals.where((g) => !g.isCompleted).toList();
          final completedGoals =
              allGoals.where((g) => g.isCompleted).toList();

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active goals grid
                  if (activeGoals.isNotEmpty) ...[
                    Text('Active Goals',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: activeGoals.length,
                      itemBuilder: (context, index) {
                        return _GoalCard(goal: activeGoals[index])
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: 100 * index),
                              duration: 400.ms,
                            )
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: Duration(milliseconds: 100 * index),
                              duration: 400.ms,
                            );
                      },
                    ),
                  ],

                  // Completed goals section
                  if (completedGoals.isNotEmpty) ...[
                    const SizedBox(height: Spacing.lg),
                    InkWell(
                      onTap: () =>
                          setState(() => _showCompleted = !_showCompleted),
                      borderRadius: Radii.borderSm,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Text(
                              'Completed (${completedGoals.length})',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _showCompleted ? 0.5 : 0,
                              duration: AppDurations.fast,
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: completedGoals.length,
                        itemBuilder: (context, index) {
                          return _GoalCard(
                            goal: completedGoals[index],
                            isCompleted: true,
                          );
                        },
                      ),
                      crossFadeState: _showCompleted
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: AppDurations.medium,
                    ),
                  ],

                  if (activeGoals.isEmpty) ...[
                    const SizedBox(height: Spacing.xl),
                    Center(
                      child: Text(
                        'All goals completed! Add a new one.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.addGoal),
        icon: const Icon(Icons.add),
        label: const Text('Add Goal'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: Spacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AssetPaths.emptyGoals, width: 200, height: 200),
            const SizedBox(height: Spacing.lg),
            Text('No Goals Yet',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.sm),
            Text(
              'Start saving toward something special!\nTap + to create your first goal.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
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
    if (remaining.isNotEmpty) result = '$remaining,$result';
    return result;
  }
}

class _GoalCard extends StatelessWidget {
  final GoalModel goal;
  final bool isCompleted;

  const _GoalCard({required this.goal, this.isCompleted = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final progress = goal.progress.clamp(0.0, 1.0);
    final pctText = '${(progress * 100).toStringAsFixed(0)}%';

    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.goalDetail,
        pathParameters: {'id': '${goal.id}'},
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Jar illustration
              Expanded(
                child: CustomPaint(
                  painter: _GoalJarPainter(
                    progress: progress,
                    liquidColor: Color(goal.color),
                    jarColor: theme.colorScheme.outlineVariant,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 8),
              // Goal name
              Text(
                goal.name,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // Progress text
              Text(
                'Rs. ${_formatCompact(goal.currentAmount)}'
                ' / Rs. ${_formatCompact(goal.targetAmount)}',
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Percentage badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withValues(alpha: 0.15)
                      : theme.colorScheme.primaryContainer,
                  borderRadius: Radii.borderFull,
                ),
                child: Text(
                  isCompleted ? 'Done!' : pctText,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isCompleted
                        ? Colors.green
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCompact(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

/// CustomPainter that draws a jar outline and fills it with a liquid-like
/// wave effect based on the progress percentage.
class _GoalJarPainter extends CustomPainter {
  final double progress;
  final Color liquidColor;
  final Color jarColor;

  _GoalJarPainter({
    required this.progress,
    required this.liquidColor,
    required this.jarColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Jar dimensions
    final jarLeft = w * 0.15;
    final jarRight = w * 0.85;
    final jarTop = h * 0.15;
    final jarBottom = h * 0.9;
    final jarHeight = jarBottom - jarTop;

    // Neck dimensions
    final neckLeft = w * 0.3;
    final neckRight = w * 0.7;
    final neckTop = h * 0.02;
    final neckBottom = jarTop;

    // Draw jar outline
    final jarPaint = Paint()
      ..color = jarColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final jarPath = Path()
      // Neck
      ..moveTo(neckLeft, neckTop)
      ..lineTo(neckLeft, neckBottom)
      // Left shoulder curve
      ..quadraticBezierTo(jarLeft, jarTop, jarLeft, jarTop + 20)
      // Left side
      ..lineTo(jarLeft, jarBottom - 10)
      // Bottom left curve
      ..quadraticBezierTo(jarLeft, jarBottom, jarLeft + 10, jarBottom)
      // Bottom
      ..lineTo(jarRight - 10, jarBottom)
      // Bottom right curve
      ..quadraticBezierTo(jarRight, jarBottom, jarRight, jarBottom - 10)
      // Right side
      ..lineTo(jarRight, jarTop + 20)
      // Right shoulder curve
      ..quadraticBezierTo(jarRight, jarTop, neckRight, neckBottom)
      // Neck right
      ..lineTo(neckRight, neckTop);

    // Neck rim
    final rimPath = Path()
      ..moveTo(neckLeft - 4, neckTop)
      ..lineTo(neckRight + 4, neckTop);

    // Fill liquid
    if (progress > 0) {
      final fillHeight = jarHeight * progress;
      final fillTop = jarBottom - fillHeight;

      // Create liquid fill with wave
      final liquidPaint = Paint()
        ..color = liquidColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;

      final liquidPath = Path();

      // Start at bottom left
      liquidPath.moveTo(jarLeft + 2, jarBottom - 10);
      liquidPath.quadraticBezierTo(
          jarLeft + 2, jarBottom, jarLeft + 12, jarBottom - 1);
      liquidPath.lineTo(jarRight - 12, jarBottom - 1);
      liquidPath.quadraticBezierTo(
          jarRight - 2, jarBottom, jarRight - 2, jarBottom - 10);

      // Right side up to fill level
      liquidPath.lineTo(jarRight - 2, fillTop);

      // Sine wave across the top of the liquid
      final waveAmplitude = 3.0;
      final steps = 20;
      for (int i = steps; i >= 0; i--) {
        final x =
            jarRight - 2 - ((jarRight - 2 - (jarLeft + 2)) * i / steps);
        final y =
            fillTop + math.sin(i * math.pi / steps * 2) * waveAmplitude;
        liquidPath.lineTo(x, y);
      }

      // Left side back down
      liquidPath.lineTo(jarLeft + 2, jarBottom - 10);
      liquidPath.close();

      canvas.drawPath(liquidPath, liquidPaint);

      // Draw a more opaque wave line at top
      final wavePaint = Paint()
        ..color = liquidColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final wavePath = Path();
      wavePath.moveTo(jarLeft + 2, fillTop);
      for (int i = 0; i <= steps; i++) {
        final x =
            jarLeft + 2 + ((jarRight - 2 - (jarLeft + 2)) * i / steps);
        final y =
            fillTop + math.sin(i * math.pi / steps * 2) * waveAmplitude;
        if (i == 0) {
          wavePath.moveTo(x, y);
        } else {
          wavePath.lineTo(x, y);
        }
      }
      canvas.drawPath(wavePath, wavePaint);
    }

    // Draw jar outline on top
    canvas.drawPath(jarPath, jarPaint);
    canvas.drawPath(rimPath, jarPaint..strokeWidth = 3.0);
  }

  @override
  bool shouldRepaint(covariant _GoalJarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.liquidColor != liquidColor;
  }
}
