import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../../../../config/theme/theme_provider.dart';
import '../../../../domain/models/transaction_model.dart';
import '../providers/home_provider.dart';
import '../widgets/balance_card.dart';

/// The main home dashboard screen.
///
/// Displays greeting, total balance card, monthly income/expense,
/// quick actions, recent transactions, and a mini spending pie chart.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _refresh() async {
    ref.invalidate(totalBalanceProvider);
    ref.invalidate(monthlyIncomeProvider);
    ref.invalidate(monthlyExpenseProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(categoryTotalsProvider);
    // Small delay to let providers re-fetch.
    await Future.delayed(const Duration(milliseconds: 300));
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userName = ref.watch(userNameProvider);

    // Watch the transaction stream for live updates.
    ref.listen(transactionStreamProvider, (_, __) {
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(monthlyIncomeProvider);
      ref.invalidate(monthlyExpenseProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(categoryTotalsProvider);
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: colorScheme.primary,
        child: SafeArea(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── Greeting Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.lg,
                    Spacing.lg,
                    Spacing.lg,
                    Spacing.sm,
                  ),
                  child: _GreetingHeader(
                    greeting: _greeting(),
                    userName: userName,
                    theme: theme,
                  ),
                ),
              ),

              // ── Balance Card ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: Spacing.horizontalLg,
                  child: _BalanceSection(ref: ref),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: Spacing.md),
              ),

              // ── Income / Expense Row ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: Spacing.horizontalLg,
                  child: _IncomeExpenseRow(ref: ref, theme: theme),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: Spacing.lg),
              ),

              // ── Quick Actions ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: Spacing.horizontalLg,
                  child: _QuickActionsRow(theme: theme),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: Spacing.lg),
              ),

              // ── Mini Spending Chart ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: Spacing.horizontalLg,
                  child: _SpendingChart(ref: ref, theme: theme),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: Spacing.lg),
              ),

              // ── Recent Transactions Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: Spacing.horizontalLg,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transactions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.goNamed(RouteNames.transactions);
                        },
                        child: Text(
                          'See all',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Recent Transactions List ──
              _RecentTransactionsList(ref: ref, theme: theme),

              // Bottom padding for nav bar clearance.
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Greeting Header ──────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final ThemeData theme;

  const _GreetingHeader({
    required this.greeting,
    required this.userName,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting${userName.isNotEmpty ? ', $userName' : ''}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        )
            .animate()
            .fadeIn(duration: AppDurations.medium)
            .slideY(
              begin: -0.1,
              end: 0,
              duration: AppDurations.medium,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: Spacing.xs),
        Text(
          dateStr,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ).animate().fadeIn(
              delay: const Duration(milliseconds: 100),
              duration: AppDurations.medium,
            ),
      ],
    );
  }
}

// ── Balance Section ──────────────────────────────────────────────────────────

class _BalanceSection extends StatelessWidget {
  final WidgetRef ref;

  const _BalanceSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(totalBalanceProvider);

    return balanceAsync.when(
      data: (balance) => BalanceCard(balance: balance)
          .animate()
          .fadeIn(duration: AppDurations.medium)
          .slideY(
            begin: 0.05,
            end: 0,
            duration: AppDurations.medium,
            curve: Curves.easeOut,
          ),
      loading: () => const _BalanceCardShimmer(),
      error: (_, __) => const BalanceCard(balance: 0),
    );
  }
}

class _BalanceCardShimmer extends StatelessWidget {
  const _BalanceCardShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: AppDurations.shimmer,
          color: colorScheme.surface.withValues(alpha: 0.5),
        );
  }
}

// ── Income / Expense Row ─────────────────────────────────────────────────────

class _IncomeExpenseRow extends StatelessWidget {
  final WidgetRef ref;
  final ThemeData theme;

  const _IncomeExpenseRow({required this.ref, required this.theme});

  @override
  Widget build(BuildContext context) {
    final incomeAsync = ref.watch(monthlyIncomeProvider);
    final expenseAsync = ref.watch(monthlyExpenseProvider);
    final cheddarColors = theme.extension<CheddarColors>();

    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Income',
            amount: incomeAsync.value ?? 0,
            isLoading: incomeAsync.isLoading,
            icon: Icons.arrow_upward_rounded,
            iconColor: cheddarColors?.income ?? Colors.green,
            theme: theme,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _MiniStatCard(
            label: 'Expense',
            amount: expenseAsync.value ?? 0,
            isLoading: expenseAsync.isLoading,
            icon: Icons.arrow_downward_rounded,
            iconColor: cheddarColors?.expense ?? Colors.red,
            theme: theme,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay: const Duration(milliseconds: 200),
          duration: AppDurations.medium,
        )
        .slideY(
          begin: 0.05,
          end: 0,
          delay: const Duration(milliseconds: 200),
          duration: AppDurations.medium,
          curve: Curves.easeOut,
        );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final double amount;
  final bool isLoading;
  final IconData icon;
  final Color iconColor;
  final ThemeData theme;

  const _MiniStatCard({
    required this.label,
    required this.amount,
    required this.isLoading,
    required this.icon,
    required this.iconColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: Radii.borderLg,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                isLoading
                    ? Container(
                        width: 60,
                        height: 14,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: Radii.borderSm,
                        ),
                      )
                    : Text(
                        '${AppConstants.currencySymbol} ${_formatCompact(amount)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCompact(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(1)}Cr';
    } else if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

// ── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  final ThemeData theme;

  const _QuickActionsRow({required this.theme});

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        _QuickActionChip(
          label: 'Add Expense',
          icon: Icons.remove_circle_outline_rounded,
          color: colorScheme.error,
          onTap: () => context.pushNamed(RouteNames.addTransaction),
          theme: theme,
        ),
        const SizedBox(width: Spacing.sm),
        _QuickActionChip(
          label: 'Add Income',
          icon: Icons.add_circle_outline_rounded,
          color: Colors.green.shade600,
          onTap: () => context.pushNamed(RouteNames.addTransaction),
          theme: theme,
        ),
        const SizedBox(width: Spacing.sm),
        _QuickActionChip(
          label: 'Scan Receipt',
          icon: Icons.document_scanner_outlined,
          color: colorScheme.tertiary,
          onTap: () => context.pushNamed(RouteNames.scanner),
          theme: theme,
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay: const Duration(milliseconds: 300),
          duration: AppDurations.medium,
        );
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final ThemeData theme;

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: Radii.borderMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.borderMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.sm + 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: Spacing.xs),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mini Spending Chart ──────────────────────────────────────────────────────

class _SpendingChart extends StatelessWidget {
  final WidgetRef ref;
  final ThemeData theme;

  const _SpendingChart({required this.ref, required this.theme});

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryTotalsProvider);
    final themeState = ref.watch(themeProvider);
    final chartColors = themeState.vibeTheme.data.chartColors.isNotEmpty
        ? themeState.vibeTheme.data.chartColors
        : _defaultChartColors;

    return categoryAsync.when(
      data: (totals) {
        if (totals.isEmpty) {
          return const SizedBox.shrink();
        }

        // Sort by amount descending, take top 5.
        final sorted = totals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top5 = sorted.take(5).toList();
        final total = top5.fold<double>(0, (sum, e) => sum + e.value);

        return Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: Radii.borderLg,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending Breakdown',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: Spacing.md),
              SizedBox(
                height: 160,
                child: Row(
                  children: [
                    // Pie chart.
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 28,
                          sections: List.generate(top5.length, (i) {
                            final entry = top5[i];
                            final pct = total > 0
                                ? (entry.value / total) * 100
                                : 0.0;
                            return PieChartSectionData(
                              value: entry.value,
                              color: chartColors[i % chartColors.length],
                              radius: 28,
                              title: '${pct.round()}%',
                              titleStyle: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.lg),
                    // Legend.
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(top5.length, (i) {
                          final entry = top5[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 3,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: chartColors[
                                        i % chartColors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: Spacing.sm),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${AppConstants.currencySymbol} ${_MiniStatCard._formatCompact(entry.value)}',
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(
              delay: const Duration(milliseconds: 400),
              duration: AppDurations.medium,
            )
            .slideY(
              begin: 0.05,
              end: 0,
              delay: const Duration(milliseconds: 400),
              duration: AppDurations.medium,
              curve: Curves.easeOut,
            );
      },
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  static const _defaultChartColors = [
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];
}

// ── Recent Transactions List (Sliver) ────────────────────────────────────────

class _RecentTransactionsList extends StatelessWidget {
  final WidgetRef ref;
  final ThemeData theme;

  const _RecentTransactionsList({required this.ref, required this.theme});

  @override
  Widget build(BuildContext context) {
    final txnAsync = ref.watch(recentTransactionsProvider);
    final cheddarColors = theme.extension<CheddarColors>();

    return txnAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: Spacing.paddingLg,
              child: Column(
                children: [
                  SvgPicture.asset(
                    AssetPaths.emptyTransactions,
                    height: 120,
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'No transactions yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Tap "Add Expense" to get started',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: Spacing.horizontalLg,
          sliver: SliverList.builder(
            itemCount: math.min(transactions.length, 5),
            itemBuilder: (context, index) {
              final txn = transactions[index];
              return Dismissible(
                key: ValueKey(txn.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: Spacing.lg),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: Radii.borderMd,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                ),
                confirmDismiss: (_) async {
                  return await _showDeleteConfirmation(context, theme);
                },
                onDismissed: (_) {
                  ref
                      .read(transactionRepositoryProvider)
                      .delete(txn.id);
                  ref.invalidate(recentTransactionsProvider);
                  ref.invalidate(totalBalanceProvider);
                  ref.invalidate(monthlyIncomeProvider);
                  ref.invalidate(monthlyExpenseProvider);
                  ref.invalidate(categoryTotalsProvider);
                },
                child: _TransactionRow(
                  transaction: txn,
                  theme: theme,
                  cheddarColors: cheddarColors,
                  onTap: () {
                    context.pushNamed(
                      RouteNames.transactionDetail,
                      pathParameters: {'id': txn.id.toString()},
                    );
                  },
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 100 * index),
                      duration: AppDurations.medium,
                    )
                    .slideX(
                      begin: 0.05,
                      end: 0,
                      delay: Duration(milliseconds: 100 * index),
                      duration: AppDurations.medium,
                      curve: Curves.easeOut,
                    ),
              );
            },
          ),
        );
      },
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: Spacing.horizontalLg,
          child: Column(
            children: List.generate(3, (_) => const _TransactionShimmer()),
          ),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(
        child: SizedBox.shrink(),
      ),
    );
  }

  static Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    ThemeData theme,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Row ──────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final TransactionModel transaction;
  final ThemeData theme;
  final CheddarColors? cheddarColors;
  final VoidCallback onTap;

  const _TransactionRow({
    required this.transaction,
    required this.theme,
    required this.cheddarColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 0;
    final isTransfer = transaction.type == 2;
    final amountColor = isIncome
        ? (cheddarColors?.income ?? Colors.green)
        : isTransfer
            ? (cheddarColors?.transfer ?? Colors.blue)
            : (cheddarColors?.expense ?? Colors.red);
    final prefix = isIncome ? '+' : isTransfer ? '' : '-';
    final dateStr = DateFormat('MMM d').format(transaction.date);

    // Map category to SVG icon.
    final categoryIcon = _categoryToAssetPath(transaction.category);

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.borderMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.sm + 2,
        ),
        child: Row(
          children: [
            // Category icon.
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: Radii.borderMd,
              ),
              padding: const EdgeInsets.all(8),
              child: categoryIcon != null
                  ? SvgPicture.asset(
                      categoryIcon,
                      width: 26,
                      height: 26,
                    )
                  : Icon(
                      Icons.receipt_long_rounded,
                      size: 22,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),

            const SizedBox(width: Spacing.md),

            // Category name & date.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.category,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.note?.isNotEmpty == true
                        ? '${transaction.note} · $dateStr'
                        : dateStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Amount.
            Text(
              '$prefix${AppConstants.currencySymbol} ${transaction.amount.toStringAsFixed(0)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps a category name to its corresponding SVG asset path.
  static String? _categoryToAssetPath(String category) {
    final normalized = category.toLowerCase().trim();
    const map = {
      'food': AssetPaths.categoryFood,
      'transport': AssetPaths.categoryTransport,
      'shopping': AssetPaths.categoryShopping,
      'bills': AssetPaths.categoryBills,
      'entertainment': AssetPaths.categoryEntertainment,
      'health': AssetPaths.categoryHealth,
      'education': AssetPaths.categoryEducation,
      'travel': AssetPaths.categoryTravel,
      'gifts': AssetPaths.categoryGifts,
      'salary': AssetPaths.categorySalary,
      'freelance': AssetPaths.categoryFreelance,
      'investments': AssetPaths.categoryInvestments,
      'rent': AssetPaths.categoryRent,
      'groceries': AssetPaths.categoryGroceries,
      'pets': AssetPaths.categoryPets,
      'subscriptions': AssetPaths.categorySubscriptions,
    };
    return map[normalized];
  }
}

// ── Transaction Shimmer ──────────────────────────────────────────────────────

class _TransactionShimmer extends StatelessWidget {
  const _TransactionShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: Radii.borderMd,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: Radii.borderSm,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 60,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: Radii.borderSm,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 50,
            height: 14,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: Radii.borderSm,
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: AppDurations.shimmer,
          color: colorScheme.surface.withValues(alpha: 0.5),
        );
  }
}
