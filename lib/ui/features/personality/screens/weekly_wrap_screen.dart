import 'dart:async';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/theme/spacing.dart';
import '../providers/personality_provider.dart';

/// Spotify Wrapped-style weekly summary with 5 animated story pages.
class WeeklyWrapScreen extends ConsumerStatefulWidget {
  const WeeklyWrapScreen({super.key});

  @override
  ConsumerState<WeeklyWrapScreen> createState() => _WeeklyWrapScreenState();
}

class _WeeklyWrapScreenState extends ConsumerState<WeeklyWrapScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoAdvanceTimer;
  final GlobalKey _screenshotKey = GlobalKey();

  static const _pageCount = 5;
  static const _autoAdvanceDuration = Duration(seconds: 4);

  static const _pageGradients = [
    [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    [Color(0xFFEC4899), Color(0xFFBE185D)],
    [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    [Color(0xFF0D9488), Color(0xFF06B6D4)],
    [Color(0xFFF59E0B), Color(0xFF22C55E)],
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(_autoAdvanceDuration, (_) {
      if (_currentPage < _pageCount - 1) {
        _pageController.nextPage(
          duration: Durations.medium,
          curve: Curves.easeInOut,
        );
      } else {
        _autoAdvanceTimer?.cancel();
      }
    });
  }

  void _goToNextPage() {
    _autoAdvanceTimer?.cancel();
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: Durations.medium,
        curve: Curves.easeInOut,
      );
    }
    _startAutoAdvance();
  }

  Future<void> _shareWrap() async {
    try {
      final boundary = _screenshotKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final xFile = XFile.fromData(
        byteData.buffer.asUint8List(),
        mimeType: 'image/png',
        name: 'cheddar_weekly_wrap.png',
      );
      await Share.shareXFiles([xFile],
          text: 'Check out my weekly spending wrap on Cheddar!');
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
    final wrapAsync = ref.watch(weeklyWrapProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: wrapAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
        error: (error, _) => Center(
          child: Padding(
            padding: Spacing.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.white54),
                const SizedBox(height: Spacing.md),
                Text('Could not load weekly wrap',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        )),
                const SizedBox(height: Spacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => _buildWrap(context, data),
      ),
    );
  }

  Widget _buildWrap(BuildContext context, WeeklyWrapData data) {
    return GestureDetector(
      onTap: _goToNextPage,
      child: Stack(
        children: [
          RepaintBoundary(
            key: _screenshotKey,
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                _autoAdvanceTimer?.cancel();
                _startAutoAdvance();
              },
              children: [
                _buildPage1(context, data),
                _buildPage2(context, data),
                _buildPage3(context, data),
                _buildPage4(context, data),
                _buildPage5(context, data),
              ],
            ),
          ),
          // Progress dots at top
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: List.generate(_pageCount, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: Radii.borderFull,
                        color: i <= _currentPage
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 1: Your Week in Numbers ──────────────────────────────────────

  Widget _buildPage1(BuildContext context, WeeklyWrapData data) {
    return _WrapPageContainer(
      gradientColors: _pageGradients[0],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Your Week\nin Numbers',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, end: 0),
          const SizedBox(height: Spacing.xxl),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: data.totalSpent),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text(
                'Rs. ${_formatIndian(value)}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 48,
                ),
              );
            },
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms).scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
              ),
          const SizedBox(height: Spacing.sm),
          Text('spent this week',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white70,
            ),
          ).animate().fadeIn(delay: 600.ms),
          const SizedBox(height: Spacing.xl),
          Text('across ${data.transactionCount} transactions',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white60,
            ),
          ).animate().fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  // ── Page 2: Top Category ──────────────────────────────────────────────

  Widget _buildPage2(BuildContext context, WeeklyWrapData data) {
    return _WrapPageContainer(
      gradientColors: _pageGradients[1],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Your Top\nCategory',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: Spacing.xl),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getCategoryIcon(data.topCategory),
              size: 64,
              color: Colors.white,
            ),
          )
              .animate()
              .scale(
                delay: 300.ms,
                duration: 500.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(delay: 300.ms),
          const SizedBox(height: Spacing.lg),
          Text(data.topCategory,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: Spacing.sm),
          Text('Rs. ${_formatIndian(data.topCategoryAmount)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white70,
            ),
          ).animate().fadeIn(delay: 700.ms),
          const SizedBox(height: Spacing.xs),
          Text('${data.topCategoryPercentage.toStringAsFixed(0)}% of spending',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white54,
            ),
          ).animate().fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  // ── Page 3: Biggest Expense ───────────────────────────────────────────

  Widget _buildPage3(BuildContext context, WeeklyWrapData data) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[data.biggestExpenseDate.weekday - 1];
    final dateStr = '$dayName, ${data.biggestExpenseDate.day}/'
        '${data.biggestExpenseDate.month}';

    return _WrapPageContainer(
      gradientColors: _pageGradients[2],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Biggest\nExpense',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: Spacing.xl),
          Icon(Icons.receipt_long_rounded, size: 56, color: Colors.white70)
              .animate()
              .fadeIn(delay: 300.ms)
              .shake(delay: 500.ms, hz: 2, duration: 400.ms),
          const SizedBox(height: Spacing.lg),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: data.biggestExpenseAmount),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text(
                'Rs. ${_formatIndian(value)}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              );
            },
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: Spacing.sm),
          Text(data.biggestExpenseName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white70,
            ),
          ).animate().fadeIn(delay: 600.ms),
          const SizedBox(height: Spacing.xs),
          Text(dateStr,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white54,
            ),
          ).animate().fadeIn(delay: 700.ms),
        ],
      ),
    );
  }

  // ── Page 4: Daily Breakdown ───────────────────────────────────────────

  Widget _buildPage4(BuildContext context, WeeklyWrapData data) {
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));

    // Build bar groups from daily breakdown
    final maxVal = data.dailyBreakdown.values.fold<double>(
      1.0,
      (max, v) => v > max ? v : max,
    );

    return _WrapPageContainer(
      gradientColors: _pageGradients[3],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Daily\nBreakdown',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: Spacing.xl),
          SizedBox(
            height: 200,
            child: Padding(
              padding: Spacing.horizontalMd,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final dayIndex = value.toInt();
                          final dayDate =
                              weekStart.add(Duration(days: dayIndex));
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              dayLabels[dayDate.weekday - 1],
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data.dailyBreakdown[i] ?? 0,
                          color: Colors.white.withOpacity(0.9),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
          const SizedBox(height: Spacing.lg),
          Text(
            'Daily average: Rs. ${_formatIndian(data.dailyAverage)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white70,
            ),
          ).animate().fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  // ── Page 5: The Verdict ───────────────────────────────────────────────

  Widget _buildPage5(BuildContext context, WeeklyWrapData data) {
    final isUp = data.comparedToLastWeek > 0;
    final changeAbs = data.comparedToLastWeek.abs();
    final savingsPositive = data.savingsRate > 0;

    String message;
    if (data.savingsRate > 30) {
      message = 'Amazing week! You saved like a pro. Keep it up!';
    } else if (data.savingsRate > 10) {
      message = 'Good week! You managed to save while spending wisely.';
    } else if (data.savingsRate > 0) {
      message = 'Decent week. Try cutting back a bit next week for better savings.';
    } else {
      message = 'Tough week. Consider setting a daily spending limit next week.';
    }

    return _WrapPageContainer(
      gradientColors: _pageGradients[4],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('The Verdict',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: Spacing.xl),
          // Savings rate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: Radii.borderLg,
            ),
            child: Column(
              children: [
                Text('Savings Rate',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.savingsRate.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: savingsPositive ? Colors.white : Colors.redAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms).scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
              ),
          const SizedBox(height: Spacing.lg),
          // Compared to last week
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isUp ? Icons.trending_up : Icons.trending_down,
                color: isUp ? Colors.redAccent : Colors.greenAccent,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                '${changeAbs.toStringAsFixed(1)}% ${isUp ? "more" : "less"} than last week',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.3, end: 0),
          const SizedBox(height: Spacing.lg),
          // Encouraging message
          Padding(
            padding: Spacing.horizontalLg,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withOpacity(0.85),
                fontStyle: FontStyle.italic,
              ),
            ),
          ).animate().fadeIn(delay: 700.ms),
          const SizedBox(height: Spacing.xl),
          // Share button
          FilledButton.icon(
            onPressed: _shareWrap,
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Wrap'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _pageGradients[4][0],
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: Radii.borderMd,
              ),
            ),
          ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'groceries':
        return Icons.shopping_basket_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'health':
        return Icons.favorite_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'travel':
        return Icons.flight_rounded;
      case 'rent':
        return Icons.home_rounded;
      case 'subscriptions':
        return Icons.subscriptions_rounded;
      default:
        return Icons.category_rounded;
    }
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

/// Reusable container for a wrap page with gradient background.
class _WrapPageContainer extends StatelessWidget {
  final List<Color> gradientColors;
  final Widget child;

  const _WrapPageContainer({
    required this.gradientColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: child,
        ),
      ),
    );
  }
}
