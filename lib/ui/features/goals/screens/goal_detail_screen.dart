import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/goal_model.dart';

/// Goal detail view with animated jar, contribution history, and projections.
class GoalDetailScreen extends ConsumerStatefulWidget {
  final int goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fillController;
  GoalModel? _goal;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadGoal();
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  Future<void> _loadGoal() async {
    final goalRepo = ref.read(goalRepositoryProvider);
    final goal = await goalRepo.getById(widget.goalId);
    if (mounted) {
      setState(() {
        _goal = goal;
        _isLoading = false;
      });
      if (goal != null) {
        _fillController.animateTo(
          goal.progress.clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  Future<void> _showAddMoneySheet(String currencySymbol) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            24,
            16,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: Radii.borderFull,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text('Add Money',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: Spacing.lg),
              TextField(
                controller: amountController,
                // FIX #16: runtime currency symbol as prefix
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$currencySymbol ',
                  prefixIcon: const Icon(Icons.savings_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: Spacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final amt = double.tryParse(
                        amountController.text.replaceAll(',', '').trim());
                    if (amt == null || amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Enter a valid amount')),
                      );
                      return;
                    }
                    final goalRepo = ref.read(goalRepositoryProvider);
                    await goalRepo.addContribution(
                      widget.goalId,
                      amt,
                      note: noteController.text.trim().isNotEmpty
                          ? noteController.text.trim()
                          : null,
                    );
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: Radii.borderMd,
                    ),
                  ),
                  child: const Text('Add Contribution'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      await _loadGoal();
    }
  }

  Future<void> _deleteGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text(
            'Are you sure you want to delete this goal? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(goalRepositoryProvider).delete(widget.goalId);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // FIX #16: runtime currency symbol
    final currencySymbol = ref.watch(currencySymbolProvider);

    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (_goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Goal not found')),
      );
    }

    final goal = _goal!;
    final progress = goal.progress.clamp(0.0, 1.0);
    final remaining = (goal.targetAmount - goal.currentAmount)
        .clamp(0.0, double.infinity);

    String projectionText = '';
    String suggestionText = '';
    if (!goal.isCompleted && goal.contributions.isNotEmpty) {
      final firstContrib = goal.contributions.first;
      final daysSinceStart =
          DateTime.now().difference(firstContrib.date).inDays;
      if (daysSinceStart > 0 && goal.currentAmount > 0) {
        final dailyRate = goal.currentAmount / daysSinceStart;
        final daysRemaining = remaining / dailyRate;
        final projectedDate =
            DateTime.now().add(Duration(days: daysRemaining.ceil()));
        projectionText =
            '${projectedDate.day}/${projectedDate.month}/${projectedDate.year}';

        final weeklySave = remaining / (daysRemaining / 7).ceil();
        final dailySave = remaining / daysRemaining.ceil();
        // FIX #16: runtime currency symbol in suggestion text
        suggestionText =
            'Save $currencySymbol ${dailySave.toStringAsFixed(0)}/day or '
            '$currencySymbol ${weeklySave.toStringAsFixed(0)}/week to reach your goal';
      }
    }

    if (goal.deadline != null && !goal.isCompleted) {
      final daysLeft = goal.deadline!.difference(DateTime.now()).inDays;
      if (daysLeft > 0 && remaining > 0) {
        final dailyNeeded = remaining / daysLeft;
        final weeklyNeeded = remaining / (daysLeft / 7).ceil();
        // FIX #16: runtime currency symbol in deadline suggestion
        suggestionText =
            'Save $currencySymbol ${dailyNeeded.toStringAsFixed(0)}/day or '
            '$currencySymbol ${weeklyNeeded.toStringAsFixed(0)}/week to meet your deadline';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              context.pushNamed(
                'add-goal',
                extra: goal,
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: theme.colorScheme.error),
            onPressed: _deleteGoal,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: 200,
                height: 240,
                child: AnimatedBuilder(
                  animation: _fillController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _AnimatedJarPainter(
                        progress: _fillController.value,
                        liquidColor: Color(goal.color),
                        jarColor: theme.colorScheme.outlineVariant,
                      ),
                    );
                  },
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0)),
            const SizedBox(height: Spacing.lg),

            Center(
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: goal.currentAmount),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      // FIX #16: runtime symbol in animated counter
                      return Text(
                        '$currencySymbol ${_formatIndian(value)} of $currencySymbol ${_formatIndian(goal.targetAmount)}',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}% complete',
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),

            if (projectionText.isNotEmpty)
              Card(
                child: Padding(
                  padding: Spacing.paddingMd,
                  child: Row(
                    children: [
                      Icon(Icons.trending_up,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Projected completion',
                                style: textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600)),
                            Text(projectionText,
                                style: textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),

            if (suggestionText.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              Card(
                // FIX: withOpacity → withValues
                color: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.3),
                child: Padding(
                  padding: Spacing.paddingMd,
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(suggestionText,
                            style: textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),
            ],

            const SizedBox(height: Spacing.lg),

            Text('Contribution History',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.sm),

            if (goal.contributions.isEmpty)
              Padding(
                padding: Spacing.verticalLg,
                child: Center(
                  child: Text(
                    'No contributions yet.\nTap the button below to get started!',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...goal.contributions.reversed.toList().asMap().entries.map(
                (entry) {
                  final i = entry.key;
                  final c = entry.value;
                  return ListTile(
                    leading: CircleAvatar(
                      // FIX: withOpacity → withValues
                      backgroundColor:
                          Color(goal.color).withValues(alpha: 0.15),
                      child: Icon(Icons.add,
                          color: Color(goal.color), size: 18),
                    ),
                    // FIX #16: runtime currency symbol
                    title: Text('$currencySymbol ${_formatIndian(c.amount)}'),
                    subtitle: Text(
                      c.note ?? '${c.date.day}/${c.date.month}/${c.date.year}',
                      style: textTheme.bodySmall,
                    ),
                    trailing: Text(
                      '${c.date.day}/${c.date.month}',
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 50 * i),
                        duration: 300.ms,
                      )
                      .slideX(begin: 0.1, end: 0);
                },
              ),
          ],
        ),
      ),
      floatingActionButton: goal.isCompleted
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddMoneySheet(currencySymbol),
              backgroundColor: Color(goal.color),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Money'),
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

/// Animated jar painter that supports fill-level animation.
class _AnimatedJarPainter extends CustomPainter {
  final double progress;
  final Color liquidColor;
  final Color jarColor;

  _AnimatedJarPainter({
    required this.progress,
    required this.liquidColor,
    required this.jarColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final jarLeft = w * 0.12;
    final jarRight = w * 0.88;
    final jarTop = h * 0.12;
    final jarBottom = h * 0.92;
    final jarHeight = jarBottom - jarTop;

    final neckLeft = w * 0.28;
    final neckRight = w * 0.72;
    final neckTop = h * 0.02;

    final jarPaint = Paint()
      ..color = jarColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final jarPath = Path()
      ..moveTo(neckLeft, neckTop)
      ..lineTo(neckLeft, jarTop)
      ..quadraticBezierTo(jarLeft, jarTop, jarLeft, jarTop + 24)
      ..lineTo(jarLeft, jarBottom - 12)
      ..quadraticBezierTo(jarLeft, jarBottom, jarLeft + 12, jarBottom)
      ..lineTo(jarRight - 12, jarBottom)
      ..quadraticBezierTo(jarRight, jarBottom, jarRight, jarBottom - 12)
      ..lineTo(jarRight, jarTop + 24)
      ..quadraticBezierTo(jarRight, jarTop, neckRight, jarTop)
      ..lineTo(neckRight, neckTop);

    final rimPaint = Paint()
      ..color = jarColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawLine(
      Offset(neckLeft - 5, neckTop),
      Offset(neckRight + 5, neckTop),
      rimPaint,
    );

    if (progress > 0) {
      final fillHeight = jarHeight * progress;
      final fillTop = jarBottom - fillHeight;

      // FIX: withOpacity → withValues
      final liquidPaint = Paint()
        ..color = liquidColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      final liquidPath = Path();
      liquidPath.moveTo(jarLeft + 3, jarBottom - 12);
      liquidPath.quadraticBezierTo(
          jarLeft + 3, jarBottom - 1, jarLeft + 14, jarBottom - 1);
      liquidPath.lineTo(jarRight - 14, jarBottom - 1);
      liquidPath.quadraticBezierTo(
          jarRight - 3, jarBottom - 1, jarRight - 3, jarBottom - 12);
      liquidPath.lineTo(jarRight - 3, fillTop);

      const amp = 4.0;
      const steps = 24;
      for (int i = steps; i >= 0; i--) {
        final x = jarRight - 3 -
            ((jarRight - 3 - (jarLeft + 3)) * i / steps);
        final y = fillTop + math.sin(i * math.pi / steps * 2.5) * amp;
        liquidPath.lineTo(x, y);
      }
      liquidPath.close();
      canvas.drawPath(liquidPath, liquidPaint);

      // FIX: withOpacity → withValues
      final wavePaint = Paint()
        ..color = liquidColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final wavePath = Path();
      for (int i = 0; i <= steps; i++) {
        final x = jarLeft + 3 +
            ((jarRight - 3 - (jarLeft + 3)) * i / steps);
        final y = fillTop + math.sin(i * math.pi / steps * 2.5) * amp;
        if (i == 0) {
          wavePath.moveTo(x, y);
        } else {
          wavePath.lineTo(x, y);
        }
      }
      canvas.drawPath(wavePath, wavePaint);
    }

    canvas.drawPath(jarPath, jarPaint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedJarPainter old) {
    return old.progress != progress || old.liquidColor != liquidColor;
  }
}
