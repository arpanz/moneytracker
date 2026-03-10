
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';

/// GitHub-style spending heatmap calendar showing spending intensity by day.
///
/// Cells are colored by spending relative to the daily average:
/// - Empty/no spending: very light (surface)
/// - <50% of avg: light green
/// - 50-100% of avg: medium green
/// - 100-150% of avg: dark green / yellow
/// - >150% of avg: red (over-spending)
class HeatmapCalendar extends StatefulWidget {
  /// Map of day -> total spending for that day.
  final Map<DateTime, double> dailySpending;

  /// The month/year to display.
  final DateTime month;

  /// Callback when a cell is tapped.
  final ValueChanged<DateTime>? onDayTap;

  const HeatmapCalendar({
    super.key,
    required this.dailySpending,
    required this.month,
    this.onDayTap,
  });

  @override
  State<HeatmapCalendar> createState() => _HeatmapCalendarState();
}

class _HeatmapCalendarState extends State<HeatmapCalendar> {
  DateTime? _selectedDay;
  OverlayEntry? _tooltipOverlay;

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  double get _dailyAverage {
    if (widget.dailySpending.isEmpty) return 0;
    final total = widget.dailySpending.values.fold<double>(0, (a, b) => a + b);
    final daysWithSpending = widget.dailySpending.values.where((v) => v > 0).length;
    return daysWithSpending > 0 ? total / daysWithSpending : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Month Title ──
        Text(
          DateFormat('MMMM yyyy').format(widget.month),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.sm),

        // ── Weekday Headers ──
        _buildWeekdayHeaders(theme),
        const SizedBox(height: Spacing.xs),

        // ── Calendar Grid ──
        _buildCalendarGrid(theme),
        const SizedBox(height: Spacing.md),

        // ── Tooltip Display ──
        if (_selectedDay != null) _buildTooltipBanner(theme),
        const SizedBox(height: Spacing.sm),

        // ── Legend ──
        _buildLegend(theme),
      ],
    );
  }

  Widget _buildWeekdayHeaders(ThemeData theme) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: days
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme) {
    final cheddarColors = theme.extension<CheddarColors>()!;
    final year = widget.month.year;
    final month = widget.month.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Monday = 1, Sunday = 7
    final startWeekday = firstDay.weekday; // 1=Mon ... 7=Sun
    final leadingEmpty = startWeekday - 1;
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final avgSpending = _dailyAverage;

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNum = cellIndex - leadingEmpty + 1;

            if (dayNum < 1 || dayNum > daysInMonth) {
              return const Expanded(child: SizedBox(height: 36));
            }

            final date = DateTime(year, month, dayNum);
            final dateKey = DateTime(year, month, dayNum);
            final spending = widget.dailySpending[dateKey] ?? 0;
            final isSelected = _selectedDay != null &&
                _selectedDay!.year == date.year &&
                _selectedDay!.month == date.month &&
                _selectedDay!.day == date.day;
            final isToday = _isToday(date);

            final cellColor = _getCellColor(
              spending: spending,
              average: avgSpending,
              theme: theme,
              cheddarColors: cheddarColors,
            );

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDay = null;
                    } else {
                      _selectedDay = date;
                    }
                  });
                  if (widget.onDayTap != null) {
                    widget.onDayTap!(date);
                  }
                },
                child: Container(
                  height: 36,
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(6),
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          )
                        : isToday
                            ? Border.all(
                                color: theme.colorScheme.outline
                                    .withOpacity(0.4),
                                width: 1,
                              )
                            : null,
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: isToday || isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: spending > 0
                            ? _getTextColor(spending, avgSpending, theme)
                            : theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildTooltipBanner(ThemeData theme) {
    final cheddarColors = theme.extension<CheddarColors>()!;
    final day = _selectedDay!;
    final dateKey = DateTime(day.year, day.month, day.day);
    final spending = widget.dailySpending[dateKey] ?? 0;
    final formatter = NumberFormat('#,##,###', 'en_IN');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.inverseSurface.withOpacity(0.9),
        borderRadius: Radii.borderMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('EEE, MMM d').format(day),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onInverseSurface,
            ),
          ),
          Text(
            spending > 0
                ? 'Rs. ${formatter.format(spending.toInt())}'
                : 'No spending',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: spending > 0
                  ? cheddarColors.expense
                  : theme.colorScheme.onInverseSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    final cheddarColors = theme.extension<CheddarColors>()!;

    final colors = [
      theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      const Color(0xFFC8E6C9), // light green
      const Color(0xFF66BB6A), // medium green
      const Color(0xFFFDD835), // yellow
      cheddarColors.expense.withOpacity(0.8), // red
    ];

    final labels = ['None', 'Low', 'Avg', 'High', 'Over'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Less',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(width: Spacing.xs),
        ...colors.asMap().entries.map((entry) {
          return Tooltip(
            message: labels[entry.key],
            child: Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: entry.value,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
        const SizedBox(width: Spacing.xs),
        Text(
          'More',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ],
    );
  }

  Color _getCellColor({
    required double spending,
    required double average,
    required ThemeData theme,
    required CheddarColors cheddarColors,
  }) {
    if (spending <= 0) {
      return theme.colorScheme.surfaceContainerHighest.withOpacity(0.3);
    }

    if (average <= 0) {
      return const Color(0xFF66BB6A).withOpacity(0.5);
    }

    final ratio = spending / average;

    if (ratio < 0.5) {
      return const Color(0xFFC8E6C9); // light green
    } else if (ratio < 1.0) {
      return const Color(0xFF66BB6A); // medium green
    } else if (ratio < 1.5) {
      return const Color(0xFFFDD835); // yellow
    } else {
      return cheddarColors.expense.withOpacity(0.8); // red
    }
  }

  Color _getTextColor(double spending, double average, ThemeData theme) {
    if (average <= 0 || spending <= 0) {
      return theme.colorScheme.onSurface.withOpacity(0.6);
    }

    final ratio = spending / average;
    if (ratio < 0.5) {
      return const Color(0xFF2E7D32); // dark green text
    } else if (ratio < 1.0) {
      return Colors.white;
    } else if (ratio < 1.5) {
      return const Color(0xFF5D4037); // brown text on yellow
    } else {
      return Colors.white;
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
