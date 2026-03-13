import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../providers/stats_providers.dart';
import '../widgets/chart_card.dart';
import '../widgets/heatmap_calendar.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

enum StatsSection {
  spending('Spending'),
  categories('Categories'),
  cashflow('Cashflow'),
  calendar('Calendar');

  const StatsSection(this.label);
  final String label;
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _touchedPieIndex = -1;
  StatsSection _selectedSection = StatsSection.spending;

  @override
  void initState() {
    super.initState();
    ref.listenManual(statsTransactionStreamProvider, (previous, next) {
      ref.invalidate(spendingTrendProvider);
      ref.invalidate(categoryBreakdownProvider);
      ref.invalidate(incomeVsExpenseProvider);
      ref.invalidate(dailySpendingMapProvider);
      ref.invalidate(topCategoriesProvider);
    });
  }

  void _onPeriodChanged(PeriodType type) {
    final now = DateTime.now();

    switch (type) {
      case PeriodType.week:
        ref.read(periodTypeProvider.notifier).state = type;
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        ref.read(dateRangeProvider.notifier).state = DateTimeRange(
          start: DateTime(weekStart.year, weekStart.month, weekStart.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case PeriodType.month:
        ref.read(periodTypeProvider.notifier).state = type;
        ref.read(dateRangeProvider.notifier).state = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case PeriodType.quarter:
        ref.read(periodTypeProvider.notifier).state = type;
        final start = now.subtract(const Duration(days: 89));
        ref.read(dateRangeProvider.notifier).state = DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case PeriodType.year:
        ref.read(periodTypeProvider.notifier).state = type;
        ref.read(dateRangeProvider.notifier).state = DateTimeRange(
          start: DateTime(now.year, now.month - 11, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case PeriodType.custom:
        final previousPeriod = ref.read(periodTypeProvider);
        ref.read(periodTypeProvider.notifier).state = type;
        _showCustomDatePicker(previousPeriod);
    }
  }

  Future<void> _showCustomDatePicker(PeriodType previousPeriod) async {
    final now = DateTime.now();
    final currentRange = ref.read(dateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: currentRange,
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: Theme.of(context).colorScheme),
        child: child!,
      ),
    );

    if (!mounted) return;
    if (picked == null) {
      ref.read(periodTypeProvider.notifier).state = previousPeriod;
      return;
    }

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
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    }
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  String _formatFullAmount(double amount) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    final currencySymbol = ref.read(currencySymbolProvider);
    return '$currencySymbol${formatter.format(amount)}';
  }

  String _formatRangeLabel(DateTimeRange dateRange) {
    final sameYear = dateRange.start.year == dateRange.end.year;
    final startFormatter = sameYear
        ? DateFormat('d MMM')
        : DateFormat('d MMM y');
    final endFormatter = DateFormat('d MMM y');
    return '${startFormatter.format(dateRange.start)} - ${endFormatter.format(dateRange.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final periodType = ref.watch(periodTypeProvider);
    final dateRange = ref.watch(dateRangeProvider);
    final spendingTrend = ref.watch(spendingTrendProvider);
    final categoryBreakdown = ref.watch(categoryBreakdownProvider);
    final incomeVsExpense = ref.watch(incomeVsExpenseProvider);
    final dailySpending = ref.watch(dailySpendingMapProvider);
    final topCategories = ref.watch(topCategoriesProvider);

    final allEmpty =
        spendingTrend.valueOrNull?.every((spot) => spot.y == 0) == true &&
        (categoryBreakdown.valueOrNull?.isEmpty ?? true) &&
        incomeVsExpense.valueOrNull?.every(
              (item) => item.income == 0 && item.expense == 0,
            ) ==
            true;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('Statistics'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(112),
              child: Column(
                children: [
                  _buildSectionSelector(theme),
                  _buildPeriodSelector(theme, periodType, dateRange),
                ],
              ),
            ),
          ),
          if (allEmpty && !spendingTrend.isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(theme),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: Spacing.sm),
                ..._buildSelectedSections(
                  theme: theme,
                  cheddarColors: cheddarColors,
                  spendingTrend: spendingTrend,
                  dateRange: dateRange,
                  categoryBreakdown: categoryBreakdown,
                  incomeVsExpense: incomeVsExpense,
                  dailySpending: dailySpending,
                  topCategories: topCategories,
                ),
                const SizedBox(height: 100),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: StatsSection.values.map((section) {
            final isSelected = section == _selectedSection;
            return Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: ChoiceChip(
                label: Text(section.label),
                selected: isSelected,
                onSelected: (_) {
                  if (!isSelected) {
                    setState(() => _selectedSection = section);
                  }
                },
                selectedColor: theme.colorScheme.primary.withValues(
                  alpha: 0.14,
                ),
                backgroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.35)
                      : theme.colorScheme.outline.withValues(alpha: 0.25),
                ),
                labelStyle: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
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

  Widget _buildPeriodSelector(
    ThemeData theme,
    PeriodType selectedPeriod,
    DateTimeRange dateRange,
  ) {
    final labels = {
      PeriodType.week: '7D',
      PeriodType.month: '30D',
      PeriodType.quarter: '90D',
      PeriodType.year: '1Y',
      PeriodType.custom: 'Range',
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
            final label = type == PeriodType.custom && isSelected
                ? _formatRangeLabel(dateRange)
                : labels[type]!;

            return Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => _onPeriodChanged(type),
                selectedColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                labelStyle: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    );
  }

  List<Widget> _buildSelectedSections({
    required ThemeData theme,
    required CheddarColors cheddarColors,
    required AsyncValue<List<FlSpot>> spendingTrend,
    required DateTimeRange dateRange,
    required AsyncValue<List<CategoryTotal>> categoryBreakdown,
    required AsyncValue<List<MonthlyComparison>> incomeVsExpense,
    required AsyncValue<Map<DateTime, double>> dailySpending,
    required AsyncValue<List<CategoryTotal>> topCategories,
  }) {
    switch (_selectedSection) {
      case StatsSection.spending:
        return [
          _buildSpendingTrendSection(
            theme,
            cheddarColors,
            spendingTrend,
            dateRange,
          ),
        ];
      case StatsSection.categories:
        return [
          _buildCategoryBreakdownSection(
            theme,
            cheddarColors,
            categoryBreakdown,
          ),
          _buildTopCategoriesSection(theme, cheddarColors, topCategories),
        ];
      case StatsSection.cashflow:
        return [
          _buildIncomeVsExpenseSection(theme, cheddarColors, incomeVsExpense),
        ];
      case StatsSection.calendar:
        return [
          _buildHeatmapSection(theme, cheddarColors, dailySpending, dateRange),
        ];
    }
  }

  Widget _buildSpendingTrendSection(
    ThemeData theme,
    CheddarColors cheddarColors,
    AsyncValue<List<FlSpot>> spendingTrend,
    DateTimeRange dateRange,
  ) {
    return ChartCard(
      title: 'Spending Trend',
      subtitle: 'Daily expense over time',
      chartHeight: 220,
      child: spendingTrend.when(
        loading: () => _buildShimmerPlaceholder(cheddarColors, height: 220),
        error: (error, _) => _buildErrorWidget(theme),
        data: (spots) {
          if (spots.isEmpty || spots.every((spot) => spot.y == 0)) {
            return _buildNoDataPlaceholder(theme, 'No spending data');
          }

          final maxY =
              spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.2;
          return LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
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
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
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
                      final date = dateRange.start.add(
                        Duration(days: value.toInt()),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('d').format(date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
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
                        theme.colorScheme.primary.withValues(alpha: 0.3),
                        theme.colorScheme.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            duration: Duration.zero,
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

  Widget _buildCategoryBreakdownSection(
    ThemeData theme,
    CheddarColors cheddarColors,
    AsyncValue<List<CategoryTotal>> categoryBreakdown,
  ) {
    return ChartCard(
      title: 'Category Breakdown',
      subtitle: 'Where your money goes',
      child: categoryBreakdown.when(
        loading: () => _buildShimmerPlaceholder(cheddarColors, height: 280),
        error: (error, _) => _buildErrorWidget(theme),
        data: (categories) {
          if (categories.isEmpty) {
            return _buildNoDataPlaceholder(theme, 'No category data');
          }

          return Column(
            children: [
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
                      final index = entry.key;
                      final category = entry.value;
                      final isTouched = index == _touchedPieIndex;
                      return PieChartSectionData(
                        color: category.color,
                        value: category.amount,
                        title: '${category.percentage.toStringAsFixed(0)}%',
                        radius: isTouched ? 65 : 55,
                        showTitle: category.percentage >= 5,
                        titleStyle: TextStyle(
                          fontSize: isTouched ? 14 : 11,
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
                  duration: Duration.zero,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Wrap(
                spacing: Spacing.md,
                runSpacing: Spacing.sm,
                children: categories.map((category) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: category.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        category.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatFullAmount(category.amount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
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

  Widget _buildIncomeVsExpenseSection(
    ThemeData theme,
    CheddarColors cheddarColors,
    AsyncValue<List<MonthlyComparison>> incomeVsExpense,
  ) {
    return ChartCard(
      title: 'Income vs Expense',
      subtitle: 'Range comparison',
      chartHeight: 220,
      child: incomeVsExpense.when(
        loading: () => _buildShimmerPlaceholder(cheddarColors, height: 220),
        error: (error, _) => _buildErrorWidget(theme),
        data: (months) {
          if (months.isEmpty ||
              months.every(
                (month) => month.income == 0 && month.expense == 0,
              )) {
            return _buildNoDataPlaceholder(theme, 'No income or expense data');
          }

          final maxVal = months.fold<double>(0, (previous, month) {
            final localMax = month.income > month.expense
                ? month.income
                : month.expense;
            return localMax > previous ? localMax : previous;
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
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
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
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
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
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  strokeWidth: 1,
                ),
              ),
              barGroups: months.asMap().entries.map((entry) {
                final index = entry.key;
                final month = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: month.income,
                      color: cheddarColors.income,
                      width: 12,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    BarChartRodData(
                      toY: month.expense,
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
            duration: Duration.zero,
          );
        },
      ),
    );
  }

  Widget _buildHeatmapSection(
    ThemeData theme,
    CheddarColors cheddarColors,
    AsyncValue<Map<DateTime, double>> dailySpending,
    DateTimeRange dateRange,
  ) {
    return ChartCard(
      title: 'Spending Heatmap',
      subtitle: _formatRangeLabel(dateRange),
      child: dailySpending.when(
        loading: () => _buildShimmerPlaceholder(cheddarColors, height: 240),
        error: (error, _) => _buildErrorWidget(theme),
        data: (spendingMap) {
          if (spendingMap.isEmpty) {
            return _buildNoDataPlaceholder(theme, 'No spending data');
          }

          final month = DateTime(dateRange.end.year, dateRange.end.month);
          return HeatmapCalendar(
            dailySpending: spendingMap,
            month: month,
            onDayTap: (day) {
              final spent = spendingMap[day];
              if (spent == null || spent <= 0) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${DateFormat('dd MMM yyyy').format(day)}: ${_formatFullAmount(spent)}',
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTopCategoriesSection(
    ThemeData theme,
    CheddarColors cheddarColors,
    AsyncValue<List<CategoryTotal>> topCategories,
  ) {
    return ChartCard(
      title: 'Top Categories',
      subtitle: 'Highest spending categories',
      child: topCategories.when(
        loading: () => _buildShimmerPlaceholder(cheddarColors, height: 320),
        error: (error, _) => _buildErrorWidget(theme),
        data: (categories) {
          if (categories.isEmpty) {
            return _buildNoDataPlaceholder(theme, 'No category data');
          }

          final maxAmount = categories.first.amount;
          return Column(
            children: categories.map((category) {
              final fraction = maxAmount > 0
                  ? category.amount / maxAmount
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        category.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: Radii.borderSm,
                                ),
                              ),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: fraction),
                                duration: AppDurations.fast,
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return Container(
                                    height: 24,
                                    width: constraints.maxWidth * value,
                                    decoration: BoxDecoration(
                                      color: category.color,
                                      borderRadius: Radii.borderSm,
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    SizedBox(
                      width: 56,
                      child: Text(
                        _formatAmount(category.amount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

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
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
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
