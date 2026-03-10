import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../../../../domain/models/transaction_model.dart';
import '../providers/budget_providers.dart';

/// Detail view for a single budget showing progress, daily chart, and transactions.
class BudgetDetailScreen extends ConsumerWidget {
  final String budgetId;

  const BudgetDetailScreen({super.key, required this.budgetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(budgetId) ?? 0;
    final budgetAsync = ref.watch(budgetByIdProvider(id));
    final dailyAsync = ref.watch(dailySpendingForBudgetProvider(id));
    final budgetsWithSpending = ref.watch(budgetWithSpendingProvider);
    // FIX #16: runtime currency symbol
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      body: budgetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (budget) {
          if (budget == null) {
            return const Center(child: Text('Budget not found'));
          }

          final bwsList = budgetsWithSpending.valueOrNull ?? [];
          final bws = bwsList.isNotEmpty
              ? bwsList.firstWhere(
                  (b) => b.budget.id == id,
                  orElse: () => BudgetWithSpending(
                    budget: budget,
                    spent: 0,
                    percentage: 0,
                    status: BudgetStatus.underBudget,
                  ),
                )
              : BudgetWithSpending(
                  budget: budget,
                  spent: 0,
                  percentage: 0,
                  status: BudgetStatus.underBudget,
                );

          return _BudgetDetailBody(
            bws: bws,
            dailySpendingAsync: dailyAsync,
            currencySymbol: currencySymbol,
          );
        },
      ),
    );
  }
}

class _BudgetDetailBody extends ConsumerWidget {
  final BudgetWithSpending bws;
  final AsyncValue<Map<DateTime, double>> dailySpendingAsync;
  final String currencySymbol;

  const _BudgetDetailBody({
    required this.bws,
    required this.dailySpendingAsync,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final formatter = NumberFormat('#,##,###', 'en_IN');

    final Color statusColor;
    switch (bws.status) {
      case BudgetStatus.overBudget:
        statusColor = cheddarColors.expense;
      case BudgetStatus.warning:
        statusColor = Colors.amber;
      case BudgetStatus.underBudget:
        statusColor = cheddarColors.income;
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(bws.budget.category),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => context.pushNamed(
                RouteNames.addBudget,
                extra: bws.budget,
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_rounded, color: cheddarColors.expense),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: Spacing.lg),

              _AnimatedCircularProgress(
                percentage: bws.percentage,
                spent: bws.spent,
                limit: bws.budget.limitAmount,
                color: statusColor,
                currencySymbol: currencySymbol,
              ).animate().fadeIn(duration: 600.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: Spacing.lg),

              Padding(
                padding: Spacing.horizontalMd,
                child: Row(
                  children: [
                    _StatTile(
                      label: 'Daily Avg',
                      value:
                          '$currencySymbol ${formatter.format(bws.dailyAverage.toInt())}',
                      icon: Icons.trending_up_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: Spacing.sm),
                    _StatTile(
                      label: 'Days Left',
                      value: '${bws.daysRemaining}',
                      icon: Icons.calendar_today_rounded,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: Spacing.sm),
                    _StatTile(
                      label: 'Projected',
                      value:
                          '$currencySymbol ${formatter.format(bws.projectedSpend.toInt())}',
                      icon: Icons.auto_graph_rounded,
                      color: bws.projectedSpend > bws.budget.limitAmount
                          ? cheddarColors.expense
                          : cheddarColors.income,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(
                    begin: 0.2,
                    end: 0,
                  ),

              const SizedBox(height: Spacing.lg),

              Padding(
                padding: Spacing.horizontalMd,
                child: Text(
                  'Daily Spending',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.sm),

              dailySpendingAsync.when(
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox(
                  height: 200,
                  child: Center(child: Text('Chart unavailable')),
                ),
                data: (dailyMap) => _DailySpendingChart(
                  dailyMap: dailyMap,
                  budgetLimit: bws.budget.limitAmount,
                  period: bws.budget.period,
                  statusColor: statusColor,
                  currencySymbol: currencySymbol,
                ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
              ),

              const SizedBox(height: Spacing.lg),

              Padding(
                padding: Spacing.horizontalMd,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transactions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.pushNamed(RouteNames.transactions),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),

              _BudgetTransactionsList(
                category: bws.budget.category,
                statusColor: statusColor,
                currencySymbol: currencySymbol,
              ),

              const SizedBox(height: Spacing.xxl),

              Padding(
                padding: Spacing.horizontalMd,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.pushNamed(
                          RouteNames.addBudget,
                          extra: bws.budget,
                        ),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _confirmDelete(context, ref),
                        style: FilledButton.styleFrom(
                          foregroundColor: cheddarColors.expense,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Spacing.xxl),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text(
          'Delete the budget for "${bws.budget.category}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(context).extension<CheddarColors>()!.expense,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(deleteBudgetProvider(bws.budget.id).future);
      if (context.mounted) context.pop();
    }
  }
}

// ── Animated Circular Progress ─────────────────────────────────────────────────

class _AnimatedCircularProgress extends StatelessWidget {
  final double percentage;
  final double spent;
  final double limit;
  final Color color;
  final String currencySymbol;

  const _AnimatedCircularProgress({
    required this.percentage,
    required this.spent,
    required this.limit,
    required this.color,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat('#,##,###', 'en_IN');

    return SizedBox(
      width: 180,
      height: 180,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: percentage.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _CircularProgressPainter(
              progress: value,
              progressColor: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              strokeWidth: 12,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FIX #16: runtime currency symbol
                  Text(
                    '$currencySymbol ${formatter.format(spent.toInt())}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'of $currencySymbol ${formatter.format(limit.toInt())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -1.5708; // -pi/2 (top)
    final sweepAngle = 2 * 3.14159265 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}

// ── Stat Tile ───────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.sm,
          horizontal: Spacing.sm,
        ),
        decoration: BoxDecoration(
          // FIX: withOpacity → withValues
          color: color.withValues(alpha: 0.08),
          borderRadius: Radii.borderMd,
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: Spacing.xs),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily Spending Chart ───────────────────────────────────────────────────────

class _DailySpendingChart extends StatelessWidget {
  final Map<DateTime, double> dailyMap;
  final double budgetLimit;
  final int period;
  final Color statusColor;
  final String currencySymbol;

  const _DailySpendingChart({
    required this.dailyMap,
    required this.budgetLimit,
    required this.period,
    required this.statusColor,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (dailyMap.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No spending data yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    final sortedDays = dailyMap.keys.toList()..sort();
    final maxAmount = dailyMap.values.reduce((a, b) => a > b ? a : b);
    final dailyBudget = _dailyBudgetLimit();

    return Padding(
      padding: Spacing.horizontalMd,
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (maxAmount > dailyBudget ? maxAmount : dailyBudget) * 1.2,
            barGroups: sortedDays.asMap().entries.map((entry) {
              final amount = dailyMap[entry.value] ?? 0;
              final isOverDaily = amount > dailyBudget;
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: amount,
                    color: isOverDaily
                        ? theme.extension<CheddarColors>()!.expense
                        : statusColor,
                    width: sortedDays.length > 15 ? 6 : 12,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: dailyBudget,
                  // FIX: withOpacity → withValues
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                    labelResolver: (_) => 'daily limit',
                  ),
                ),
              ],
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < sortedDays.length) {
                      final showLabel = sortedDays.length <= 10 ||
                          idx % (sortedDays.length ~/ 7 + 1) == 0;
                      if (showLabel) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('d').format(sortedDays[idx]),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              // FIX: withOpacity → withValues
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final idx = group.x;
                  if (idx >= 0 && idx < sortedDays.length) {
                    final date = DateFormat('MMM d').format(sortedDays[idx]);
                    // FIX #16: use passed-in currencySymbol
                    return BarTooltipItem(
                      '$date\n$currencySymbol ${rod.toY.toInt()}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _dailyBudgetLimit() {
    switch (period) {
      case 0:
        return budgetLimit / 7;
      case 1:
        return budgetLimit / 30;
      case 2:
        return budgetLimit / 365;
      default:
        return budgetLimit / 30;
    }
  }
}

// ── Budget Transactions List ──────────────────────────────────────────────────

class _BudgetTransactionsList extends ConsumerWidget {
  final String category;
  final Color statusColor;
  final String currencySymbol;

  const _BudgetTransactionsList({
    required this.category,
    required this.statusColor,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final txnRepo = ref.watch(transactionRepositoryProvider);

    return FutureBuilder<List<TransactionModel>>(
      future: txnRepo.getByCategory(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final transactions = snapshot.data ?? [];
        if (transactions.isEmpty) {
          return Padding(
            padding: Spacing.paddingLg,
            child: Center(
              child: Text(
                'No transactions yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  // FIX: withOpacity → withValues
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          );
        }

        final displayList = transactions.take(10).toList();
        final dateFormat = DateFormat('MMM d, h:mm a');

        return Column(
          children: displayList.asMap().entries.map((entry) {
            final txn = entry.value;
            return ListTile(
              leading: CircleAvatar(
                // FIX: withOpacity → withValues
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Icon(
                  Icons.receipt_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              title: Text(
                txn.note ?? txn.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                dateFormat.format(txn.date),
                style: theme.textTheme.bodySmall?.copyWith(
                  // FIX: withOpacity → withValues
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              trailing: Text(
                // FIX #16: runtime currency symbol
                '-$currencySymbol ${NumberFormat('#,##,###', 'en_IN').format(txn.amount.toInt())}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cheddarColors.expense,
                ),
              ),
              onTap: () => context.pushNamed(
                RouteNames.transactionDetail,
                pathParameters: {'id': txn.id.toString()},
              ),
            )
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 50 * entry.key),
                  duration: 300.ms,
                )
                .slideX(begin: 0.05, end: 0);
          }).toList(),
        );
      },
    );
  }
}
