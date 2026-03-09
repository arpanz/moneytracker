import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../../config/constants/asset_paths.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../providers/stats_providers.dart';
import '../widgets/chart_card.dart';
import '../widgets/heatmap_calendar.dart';

/// Statistics dashboard screen displaying multiple chart sections:
/// spending trend, category breakdown, income vs expense, heatmap, and top categories.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    // Listen for transaction changes to refresh stats.
    ref.listenManual(statsTransactionStreamProvider, (_, __) {
      ref.invalidate(spendingTrendProvider);
      ref.invalidate(categoryBreakdownProvider);
      ref.invalidate(incomeVsExpenseProvider);
      ref.invalidate(dailySpendingMapProvider);
      ref.invalidate(topCategoriesProvider);
    });
  }

  // ── Period Selection Helpers ─────────────────────────────────────────────

  void _onPeriodChanged(PeriodType type) {
    ref.read(periodTypeProvider.notifier).state = type;
    final now = DateTime.now();

    switch (type) {
      case PeriodType.week:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        ref.read(dateRangeProvider.notifier).state = DateTimeRange(
          start: DateTime(weekStart.year, weekStart.month, weekStart.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case PeriodType.month:
        ref.read(dateRangeProvider.notifier).state = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case PeriodType.year:
        ref.read(dateRangeProvider.notifier).state = DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
      case PeriodType.custom:
        _showCustomDatePicker();
    }
  }

  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final currentRange = ref.read(dateRangeProvider);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: currentRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: Theme.of(context).colorScheme),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      ref.read(dateRangeProvider.notifier).state = DateTimeRange(
        start: picked.start,
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        ),
      );
    } else {
      // Revert to month if user cancelled.
      ref.read(periodTypeProvider.notifier).state = PeriodType.month;
    }
  }

  // ── Number Formatting ───────────────────────────────────────────────────

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatFullAmount(double amount) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    return 'Rs.${formatter.format(amount)}';
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final periodType = ref.watch(periodTypeProvider);
    final dateRange = ref.watch(dateRangeProvider);

    // Watch all async data providers.
    final spendingTrend = ref.watch(spendingTrendProvider);
    final categoryBreakdown = ref.watch(categoryBreakdownProvider);
    final incomeVsExpense = ref.watch(incomeVsExpenseProvider);
    final dailySpending = ref.watch(dailySpendingMapProvider);
    final topCategories = ref.watch(topCategoriesProvider);

    // Determine if everything is empty (all loaded with no data).
    final allEmpty =
        spendingTrend.valueOrNull?.every((s) => s.y == 0) == true &&
        (categoryBreakdown.valueOrNull?.isEmpty ?? true) &&
        incomeVsExpense.valueOrNull?.every(
              (m) => m.income == 0 && m.expense == 0,
            ) ==
            true;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar ──
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('Statistics'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: _buildPeriodSelector(theme, periodType, dateRange),
            ),
          ),

          // ── Content ──
          if (allEmpty && !spendingTrend.isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(theme),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: Spacing.sm),

                // Section 1: Spending Trend
                _buildSpendingTrendSection(
                  theme,
                  cheddarColors,
                  spendingTrend,
                  dateRange,
                ),

                // Section 2: Category Breakdown
                _buildCategoryBreakdownSection(
                  theme,
                  cheddarColors,
                  categoryBreakdown,
                ),

                // Section 3: Income vs Expense
                _buildIncomeVsExpenseSection(
                  theme,
                  cheddarColors,
                  incomeVsExpense,
                ),

                // Section 4: Spending Heatmap
                _buildHeatmapSection(
                  theme,
                  cheddarColors,
                  dailySpending,
                  dateRange,
                ),

                // Section 5: Top Categories
                _buildTopCategoriesSection(theme, cheddarColors, topCategories),

                // Bottom padding for nav bar.
                const SizedBox(height: 100),
              ]),
            ),
        ],
      ),
    );
  }

  // ── Period Selector ─────────────────────────────────────────────────────

  Widget _buildPeriodSelector(
    ThemeData theme,
    PeriodType selectedPeriod,
    DateTimeRange dateRange,
  ) {
    final labels = {
      PeriodType.week: 'This Week',
      PeriodType.month: 'This Month',
      PeriodType.year: 'This Year',
      PeriodType.custom: 'Custom',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: PeriodType.values.map((type) {
            final isSelected = type == selectedPeriod;
            String label = labels[type]!;

            // Show date range for custom period.
            if (type == PeriodType.custom && isSelected) {
              final fmt = DateFormat('dd MMM');
              label =
                  '${fmt.format(dateRange.start)} - ${fmt.format(dateRange.end)}';
            }

            return Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => _onPeriodChanged(type),
                selectedColor: theme.colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
                backgroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : theme.colorScheme.outline.withOpacity(0.3),
                ),
                shape: RoundedRectangleBorder(borderRadius: Radii.borderFull),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: Spacing.xs,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
          child: Padding(
            padding: Spacing.paddingXl,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  AssetPaths.emptyTransactions,
                  width: 180,
                  height: 180,
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  'No statistics yet',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Start adding transactions to see your\nspending insights and trends here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.1, end: 0, duration: 500.ms);
  }

  // ── Shimmer Placeholder ─────────────────────────────────────────────────

  Widget _buildShimmerPlaceholder(CheddarColors colors, {double height = 200}) {
    return Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: Radii.borderMd,
            gradient: LinearGradient(
              colors: [colors.shimmerBase, colors.shimmerHighlight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: AppDurations.shimmer,
          color: colors.shimmerHighlight,
        );
  }

  // ── Section 1: Spending Trend ───────────────────────────────────────────

  Widget _buildSpendingTrendSection(
    ThemeData theme,
    CheddarColors cheddarColors,
    AsyncValue<List<FlSpot>> spendingTrend,
    DateTimeRange dateRange,
  ) {
    return ChartCard(
      title: 'Spending Trend',
      subtitle: 'Daily expense over time',
      animationDelay: 100.ms,
      chartHeight: 220,
      child: spendingTrend.when(
        loading: () => _buildShimmerPlaceholder(cheddarColors, height: 220),
        error: (e, _) => _buildErrorWidget(theme, e.toString()),
        data: (spots) {
          if (spots.isEmpty || spots.every((s) => s.y == 0)) {
            return _buildNoDataPlaceholder(theme, 'No spending data');
          }

          final maxY =
              spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;

          return LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: maxY > 0 ? maxY / 4 : 1,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          _formatAmount(value),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: _computeBottomInterval(spots.length),
                    getTitlesWidget: (value, meta) {
                      final dayIndex = value.toInt();
                      final date = dateRange.start.add(
                        Duration(days: dayIndex),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('d').format(date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: spots.first.x,
              maxX: spots.last.x,
              minY: 0,
              maxY: maxY > 0 ? maxY : 100,
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  tooltipBorderRadius: BorderRadius.circular(8),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final date = dateRange.start.add(
                        Duration(days: spot.x.toInt()),
                      );
                      return LineTooltipItem(
                        '${DateFormat('dd MMM').format(date)}\n${_formatFullAmount(spot.y)}',
                        TextStyle(
                          color: theme.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: theme.colorScheme.primary,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.3),
                        theme.colorScheme.primary.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            duration: AppDurations.medium,
          );
        },
      ),
    );
  }

  double _computeBottomInterval(int totalSpots) {
    if (totalSpots <= 7) return 1;
    if (totalSpots <= 14) return 2;
    if (totalSpots <= 31) return 5;
    if (totalSpots <= 90) return 14;
    return 30;
  }

  // ── Section 2: Category Breakdown ───────────────────────────────────────

  Widget _buildCategoryBreakdownSection(
    ThemeData theme,
    CheddarColors cheddarColors,
    AsyncValue<List<CategoryTotal>> categoryBreakdown,
  ) {
    return ChartCard(
      title: 'Category Breakdown',
      subtitle: 'Where your money goes',
      animationDelay: 200.ms,
      child: categoryBreakdown.when(
        loading: () => _buildShimmerPlaceholder(cheddarColors, height: 280),
        error: (e, _) => _buildErrorWidget(theme, e.toString()),
        data: (categories) {
          if (categories.isEmpty) {
            return _buildNoDataPlaceholder(theme, 'No category data');
          }

          return Column(
            children: [
              // ── Pie Chart ──
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedPieIndex = -1;
                            return;
                          }
                          _touchedPieIndex =
                              response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: categories.asMap().entries.map((entry) {
                      final i = entry.key;
                      final cat = entry.value;
                      final isTouched = i == _touchedPieIndex;
                      final radius = isTouched ? 65.0 : 55.0;
                      final fontSize = isTouched ? 14.0 : 11.0;

                      return PieChartSectionData(
                        color: cat.color,
                        value: cat.amount,
                        title: '${cat.percentage.toStringAsFixed(0)}%',
                        radius: radius,
                        showTitle: cat.percentage >= 5,
                        titleStyle: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black26, blurRadius: 2),
                          ],
                        ),
                        titlePositionPercentageOffset: 0.55,
                      );
                    }).toList(),
                  ),
                  duration: AppDurations.medium,
                ),
              ),
              const SizedBox(height: Spacing.md),

              // ── Legend ──
              Wrap(
                spacing: Spacing.md,
                runSpacing: Spacing.sm,
                children: categories.map((cat) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatFullAmount(cat.amount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Section 3: Income vs Expense ────────────────────────────────────────

  Widget _buildIncomeVsExpenseSection(
    ThemeData theme,
    CheddarColors cheddarColors,
    AsyncValue<List<MonthlyComparison>> incomeVsExpense,
  ) {
    return ChartCard(
      title: 'Income vs Expense',
      subtitle: 'Last 6 months comparison',
      animationDelay: 300.ms,
      chartHeight: 220,
      child: incomeVsExpense.when(
        loading: () => _buildShimmerPlaceholder(cheddarColors, height: 220),
        error: (e, _) => _buildErrorWidget(theme, e.toString()),
        data: (months) {
          if (months.isEmpty ||
              months.every((m) => m.income == 0 && m.expense == 0)) {
            return _buildNoDataPlaceholder(theme, 'No income/expense data');
          }

          final maxVal = months.fold<double>(0, (prev, m) {
            final localMax = m.income > m.expense ? m.income : m.expense;
            return localMax > prev ? localMax : prev;
          });
          final maxY = maxVal * 1.2;

          return BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY > 0 ? maxY : 100,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  tooltipBorderRadius: BorderRadius.circular(8),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = rodIndex == 0 ? 'Income' : 'Expense';
                    return BarTooltipItem(
                      '$label\n${_formatFullAmount(rod.toY)}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: maxY > 0 ? maxY / 4 : 1,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          _formatAmount(value),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= months.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          months[index].monthLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  strokeWidth: 1,
                ),
              ),
              barGroups: months.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: m.income,
                      color: cheddarColors.income,
                      width: 12,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    BarChartRodData(
                      toY: m.expense,
                      color: cheddarColors.expense,
                      width: 12,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            duration: AppDurations.medium,
          );
        },
      ),
    );
  }

  // ── Section 4: Spending Heatmap ─────────────────────────────────────────

  Widget _buildHeatmapSection(
    ThemeData theme,
    CheddarColors cheddarColors,
    AsyncValue<Map<DateTime, double>> dailySpending,
    DateTimeRange dateRange,
  ) {
    return ChartCard(
      title: 'Spending Heatmap',
      subtitle: 'Daily spending intensity',
      animationDelay: 400.ms,
      child: dailySpending.when(
        loading: () => _buildShimmerPlaceholder(cheddarColors, height: 240),
        error: (e, _) => _buildErrorWidget(theme, e.toString()),
        data: (spendingMap) {
          if (spendingMap.isEmpty) {
            return _buildNoDataPlaceholder(theme, 'No spending data');
          }

          // Show heatmap for current month of the date range.
          final month = DateTime(dateRange.start.year, dateRange.start.month);

          return HeatmapCalendar(
            dailySpending: spendingMap,
            month: month,
            onDayTap: (day) {
              final spent = spendingMap[day];
              if (spent != null && spent > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${DateFormat('dd MMM yyyy').format(day)}: ${_formatFullAmount(spent)}',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  // ── Section 5: Top Categories ───────────────────────────────────────────

  Widget _buildTopCategoriesSection(
    ThemeData theme,
    CheddarColors cheddarColors,
    AsyncValue<List<CategoryTotal>> topCategories,
  ) {
    return ChartCard(
      title: 'Top Categories',
      subtitle: 'Highest spending categories',
      animationDelay: 500.ms,
      child: topCategories.when(
        loading: () => _buildShimmerPlaceholder(cheddarColors, height: 320),
        error: (e, _) => _buildErrorWidget(theme, e.toString()),
        data: (categories) {
          if (categories.isEmpty) {
            return _buildNoDataPlaceholder(theme, 'No category data');
          }

          final maxAmount = categories.first.amount;

          return Column(
            children: categories.asMap().entries.map((entry) {
              final i = entry.key;
              final cat = entry.value;
              final fraction = maxAmount > 0 ? cat.amount / maxAmount : 0.0;

              return Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: Row(
                      children: [
                        // ── Category Label ──
                        SizedBox(
                          width: 80,
                          child: Text(
                            cat.category,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),

                        // ── Horizontal Bar ──
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  // Background track.
                                  Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.outline
                                          .withOpacity(0.08),
                                      borderRadius: Radii.borderSm,
                                    ),
                                  ),
                                  // Filled bar.
                                  AnimatedContainer(
                                    duration: AppDurations.medium,
                                    curve: Curves.easeOutCubic,
                                    height: 24,
                                    width: constraints.maxWidth * fraction,
                                    decoration: BoxDecoration(
                                      color: cat.color,
                                      borderRadius: Radii.borderSm,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),

                        // ── Amount Label ──
                        SizedBox(
                          width: 56,
                          child: Text(
                            _formatAmount(cat.amount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: (100 * i).ms, duration: 400.ms)
                  .slideX(
                    begin: -0.1,
                    end: 0,
                    delay: (100 * i).ms,
                    duration: 400.ms,
                  );
            }).toList(),
          );
        },
      ),
    );
  }

  // ── Shared Widgets ──────────────────────────────────────────────────────

  Widget _buildNoDataPlaceholder(ThemeData theme, String message) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 40,
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(ThemeData theme, String error) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Failed to load data',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
