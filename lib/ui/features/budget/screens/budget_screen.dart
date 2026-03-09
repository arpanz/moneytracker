import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../providers/budget_providers.dart';

/// Budget overview screen displaying all active budgets with spending progress.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetWithSpendingProvider);
    final unbudgetedAsync = ref.watch(unbudgetedSpendingProvider);

    // Listen for real-time updates
    ref.listen(budgetStreamProvider, (_, __) {
      ref.invalidate(allBudgetsProvider);
      ref.invalidate(budgetWithSpendingProvider);
      ref.invalidate(unbudgetedSpendingProvider);
    });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar ──
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('Budgets'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => context.pushNamed(RouteNames.addBudget),
              ),
            ],
          ),

          // ── Content ──
          budgetsAsync.when(
            loading: () => SliverFillRemaining(
              child: _buildShimmerLoading(context),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(AssetPaths.errorState, height: 120),
                    const SizedBox(height: Spacing.md),
                    Text('Failed to load budgets',
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: Spacing.sm),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(budgetWithSpendingProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (budgets) {
              if (budgets.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyState(context),
                );
              }
              return SliverList(
                delegate: SliverChildListDelegate([
                  // ── Monthly Summary Card ──
                  _BudgetSummaryCard(budgets: budgets),
                  const SizedBox(height: Spacing.md),

                  // ── Budget Cards ──
                  Padding(
                    padding: Spacing.horizontalMd,
                    child: Text(
                      'Active Budgets',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  ...budgets.asMap().entries.map((entry) {
                    return _BudgetCard(
                      budgetWithSpending: entry.value,
                      index: entry.key,
                    );
                  }),

                  // ── Unbudgeted Spending ──
                  const SizedBox(height: Spacing.lg),
                  unbudgetedAsync.when(
                    data: (unbudgeted) {
                      if (unbudgeted.isEmpty) return const SizedBox.shrink();
                      return _UnbudgetedSection(categories: unbudgeted);
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // Bottom padding for FAB
                  const SizedBox(height: 100),
                ]),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.addBudget),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Budget'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: Spacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              AssetPaths.emptyBudgets,
              height: 180,
            ).animate().fadeIn(duration: 600.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: Spacing.lg),
            Text(
              'No Budgets Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: Spacing.sm),
            Text(
              'Set spending limits for categories\nto keep your finances in check.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: Spacing.lg),
            FilledButton.icon(
              onPressed: () =>
                  GoRouter.of(context).pushNamed(RouteNames.addBudget),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Budget'),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(
                  begin: 0.3,
                  end: 0,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final cheddarColors = Theme.of(context).extension<CheddarColors>()!;
    return Padding(
      padding: Spacing.paddingMd,
      child: Column(
        children: List.generate(4, (i) {
          return Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: Spacing.md),
            decoration: BoxDecoration(
              color: cheddarColors.shimmerBase,
              borderRadius: Radii.borderLg,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1500.ms,
                color: cheddarColors.shimmerHighlight.withOpacity(0.3),
              );
        }),
      ),
    );
  }
}

// ── Monthly Summary Card ────────────────────────────────────────────────────

class _BudgetSummaryCard extends StatelessWidget {
  final List<BudgetWithSpending> budgets;

  const _BudgetSummaryCard({required this.budgets});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final formatter = NumberFormat('#,##,###', 'en_IN');

    final totalLimit =
        budgets.fold<double>(0.0, (sum, b) => sum + b.budget.limitAmount);
    final totalSpent = budgets.fold<double>(0.0, (sum, b) => sum + b.spent);
    final overallPercentage = totalLimit > 0 ? totalSpent / totalLimit : 0.0;

    final Color progressColor;
    if (overallPercentage >= 1.0) {
      progressColor = cheddarColors.expense;
    } else if (overallPercentage >= 0.8) {
      progressColor = Colors.amber;
    } else {
      progressColor = cheddarColors.income;
    }

    return Padding(
      padding: Spacing.horizontalMd,
      child: Container(
        padding: Spacing.paddingMd,
        decoration: BoxDecoration(
          gradient: cheddarColors.cardGradient,
          borderRadius: Radii.borderXl,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular progress
            SizedBox(
              width: 80,
              height: 80,
              child: TweenAnimationBuilder<double>(
                tween:
                    Tween(begin: 0, end: overallPercentage.clamp(0.0, 1.5)),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: value.clamp(0.0, 1.0),
                        strokeWidth: 8,
                        backgroundColor:
                            theme.colorScheme.onPrimary.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation(progressColor),
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '${(value * 100).toInt()}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Budget',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    '${AppConstants.currencySymbol} ${formatter.format(totalSpent.toInt())}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  Text(
                    'of ${AppConstants.currencySymbol} ${formatter.format(totalLimit.toInt())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0);
  }
}

// ── Budget Card ─────────────────────────────────────────────────────────────

class _BudgetCard extends ConsumerWidget {
  final BudgetWithSpending budgetWithSpending;
  final int index;

  const _BudgetCard({
    required this.budgetWithSpending,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final formatter = NumberFormat('#,##,###', 'en_IN');
    final bws = budgetWithSpending;

    final Color progressColor;
    switch (bws.status) {
      case BudgetStatus.overBudget:
        progressColor = cheddarColors.expense;
      case BudgetStatus.warning:
        progressColor = Colors.amber;
      case BudgetStatus.underBudget:
        progressColor = cheddarColors.income;
    }

    final categoryColor =
        cheddarColors.categoryColors[bws.budget.category.toLowerCase()] ??
            theme.colorScheme.primary;

    final categoryIcon = _getCategoryIconPath(bws.budget.category);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: Radii.borderLg),
        child: InkWell(
          onTap: () => context.pushNamed(
            RouteNames.budgetDetail,
            pathParameters: {'id': bws.budget.id.toString()},
          ),
          borderRadius: Radii.borderLg,
          child: Padding(
            padding: Spacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: icon + name + percentage
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.15),
                        borderRadius: Radii.borderMd,
                      ),
                      child: Center(
                        child: categoryIcon != null
                            ? SvgPicture.asset(
                                categoryIcon,
                                width: 22,
                                height: 22,
                                colorFilter: ColorFilter.mode(
                                  categoryColor,
                                  BlendMode.srcIn,
                                ),
                              )
                            : Icon(
                                Icons.category_rounded,
                                color: categoryColor,
                                size: 22,
                              ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bws.budget.category,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _periodLabel(bws.budget.period),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: progressColor.withOpacity(0.12),
                        borderRadius: Radii.borderFull,
                      ),
                      child: Text(
                        '${(bws.percentage * 100).toInt()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: progressColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),

                // Progress bar
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: bws.percentage.clamp(0.0, 1.0),
                  ),
                  duration: Duration(milliseconds: 800 + (index * 100)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: Radii.borderFull,
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(progressColor),
                      ),
                    );
                  },
                ),
                const SizedBox(height: Spacing.sm),

                // Spent vs Limit text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${AppConstants.currencySymbol} ${formatter.format(bws.spent.toInt())} / ${AppConstants.currencySymbol} ${formatter.format(bws.budget.limitAmount.toInt())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    if (bws.status == BudgetStatus.overBudget)
                      Text(
                        'Over by ${AppConstants.currencySymbol} ${formatter.format((bws.spent - bws.budget.limitAmount).toInt())}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cheddarColors.expense,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        '${AppConstants.currencySymbol} ${formatter.format(bws.remaining.toInt())} left',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cheddarColors.income,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: 100 * index), duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }

  String _periodLabel(int period) {
    switch (period) {
      case 0:
        return 'Weekly';
      case 1:
        return 'Monthly';
      case 2:
        return 'Yearly';
      default:
        return 'Monthly';
    }
  }

  String? _getCategoryIconPath(String category) {
    const map = <String, String>{
      'Food': AssetPaths.categoryFood,
      'Transport': AssetPaths.categoryTransport,
      'Shopping': AssetPaths.categoryShopping,
      'Bills': AssetPaths.categoryBills,
      'Entertainment': AssetPaths.categoryEntertainment,
      'Health': AssetPaths.categoryHealth,
      'Education': AssetPaths.categoryEducation,
      'Travel': AssetPaths.categoryTravel,
      'Gifts': AssetPaths.categoryGifts,
      'Salary': AssetPaths.categorySalary,
      'Freelance': AssetPaths.categoryFreelance,
      'Investments': AssetPaths.categoryInvestments,
      'Rent': AssetPaths.categoryRent,
      'Groceries': AssetPaths.categoryGroceries,
      'Pets': AssetPaths.categoryPets,
      'Subscriptions': AssetPaths.categorySubscriptions,
    };
    return map[category];
  }
}

// ── Unbudgeted Spending Section ─────────────────────────────────────────────

class _UnbudgetedSection extends StatelessWidget {
  final List<UnbudgetedCategory> categories;

  const _UnbudgetedSection({required this.categories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final formatter = NumberFormat('#,##,###', 'en_IN');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Spacing.horizontalMd,
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                'Unbudgeted Spending',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        ...categories.asMap().entries.map((entry) {
          final cat = entry.value;
          final color = cheddarColors
                  .categoryColors[cat.category.toLowerCase()] ??
              theme.colorScheme.tertiary;

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.xs,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: Radii.borderMd,
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      cat.category,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${AppConstants.currencySymbol} ${formatter.format(cat.totalSpent.toInt())}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cheddarColors.expense,
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 50 * entry.key),
                duration: 300.ms,
              )
              .slideX(begin: 0.05, end: 0);
        }),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}
