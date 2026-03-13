import 'dart:math' as math;
import 'dart:ui';

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
import '../../../../config/theme/vibe_themes.dart';
import '../../../../domain/models/account_model.dart';
import '../../../../domain/models/transaction_model.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/balance_card.dart';

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
    ref.invalidate(accountsListProvider);
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
    final currencySymbol = ref.watch(currencySymbolProvider);
    final showValues = ref.watch(showValuesProvider);
    final pendingCount = ref.watch(pendingTransactionsProvider).length;
    final accountsAsync = ref.watch(accountsListProvider);
    final activeAccountId = ref.watch(activeAccountIdProvider);

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
              // ── Header (greeting + account switcher row) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm,
                  ),
                  child: _GreetingHeader(
                    greeting: _greeting(),
                    userName: userName,
                    theme: theme,
                    showValues: showValues,
                    pendingCount: pendingCount,
                    accounts: accountsAsync.value ?? [],
                    activeAccountId: activeAccountId,
                    onToggleVisibility: () async {
                      final nextValue = !ref.read(showValuesProvider);
                      ref.read(showValuesProvider.notifier).state = nextValue;
                      final prefs = ref.read(sharedPreferencesProvider);
                      await prefs.setBool(AppConstants.prefShowValues, nextValue);
                    },
                    onPendingTap: () =>
                        context.pushNamed(RouteNames.pendingTransactions),
                    onAccountSelected: (id) async {
                      ref.read(activeAccountIdProvider.notifier).state = id;
                      final prefs = ref.read(sharedPreferencesProvider);
                      await prefs.setInt(AppConstants.prefActiveAccountId, id);
                      ref.invalidate(totalBalanceProvider);
                      ref.invalidate(monthlyIncomeProvider);
                      ref.invalidate(monthlyExpenseProvider);
                      ref.invalidate(recentTransactionsProvider);
                      ref.invalidate(categoryTotalsProvider);
                    },
                    onMoreTap: () => context.pushNamed(RouteNames.accounts),
                  ),
                ),
              ),

              // ── Balance Card ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: Spacing.horizontalLg,
                  child: _BalanceSection(
                    ref: ref,
                    showValues: showValues,
                    currencySymbol: currencySymbol,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: Spacing.md)),

              // ── Income / Expense Row ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: Spacing.horizontalLg,
                  child: _IncomeExpenseRow(
                    ref: ref,
                    theme: theme,
                    currencySymbol: currencySymbol,
                    showValues: showValues,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: Spacing.lg)),

              // ── Quick Actions ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: Spacing.horizontalLg,
                  child: _QuickActionsRow(theme: theme),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: Spacing.lg)),

              // ── Mini Spending Chart ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: Spacing.horizontalLg,
                  child: _SpendingChart(
                    ref: ref,
                    theme: theme,
                    currencySymbol: currencySymbol,
                    showValues: showValues,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: Spacing.lg)),

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
                        onPressed: () => context.goNamed(RouteNames.transactions),
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
              _RecentTransactionsList(
                ref: ref,
                theme: theme,
                currencySymbol: currencySymbol,
                showValues: showValues,
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: kBottomNavigationBarHeight +
                      MediaQuery.of(context).padding.bottom +
                      Spacing.md,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══ Greeting Header ══════════════════════════════════════════════════════════

class _GreetingHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final ThemeData theme;
  final bool showValues;
  final int pendingCount;
  final List<AccountModel> accounts;
  final int activeAccountId;
  final VoidCallback onToggleVisibility;
  final VoidCallback onPendingTap;
  final ValueChanged<int> onAccountSelected;
  final VoidCallback onMoreTap;

  const _GreetingHeader({
    required this.greeting,
    required this.userName,
    required this.theme,
    required this.showValues,
    required this.pendingCount,
    required this.accounts,
    required this.activeAccountId,
    required this.onToggleVisibility,
    required this.onPendingTap,
    required this.onAccountSelected,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);
    final colorScheme = theme.colorScheme;

    // Chips: max 3 accounts + optional More
    final visibleAccounts = accounts.take(3).toList();
    final hasMore = accounts.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top row: greeting + icons ──
        Row(
          children: [
            Expanded(
              child: Text(
                '$greeting${userName.isNotEmpty ? ', $userName' : ''}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              )
              .animate()
              .fadeIn(duration: AppDurations.medium)
              .slideY(begin: -0.1, end: 0, duration: AppDurations.medium, curve: Curves.easeOut),
            ),
            if (pendingCount > 0)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: onPendingTap,
                    tooltip: '$pendingCount pending transaction${pendingCount == 1 ? '' : 's'}',
                    icon: const Icon(Icons.notifications_rounded),
                    color: colorScheme.primary,
                  ),
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: colorScheme.error, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$pendingCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onError, fontSize: 9,
                          fontWeight: FontWeight.bold, height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            IconButton(
              onPressed: onToggleVisibility,
              tooltip: showValues ? 'Hide values' : 'Show values',
              icon: Icon(showValues ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),

        // ── Date ──
        const SizedBox(height: Spacing.xs),
        Text(
          dateStr,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ).animate().fadeIn(delay: const Duration(milliseconds: 100), duration: AppDurations.medium),

        const SizedBox(height: Spacing.md),

        // ── Account switcher chips ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              // "All" chip
              _AccountChip(
                label: 'All Accounts',
                icon: Icons.account_balance_wallet_rounded,
                color: colorScheme.primary,
                isSelected: activeAccountId == -1,
                onTap: () => onAccountSelected(-1),
                theme: theme,
              ),
              ...visibleAccounts.map((acc) {
                final color = Color(acc.color);
                return Padding(
                  padding: const EdgeInsets.only(left: Spacing.sm),
                  child: _AccountChip(
                    label: acc.name,
                    icon: _iconForType(acc.accountType),
                    color: color,
                    isSelected: activeAccountId == acc.id,
                    onTap: () => onAccountSelected(acc.id),
                    theme: theme,
                  ),
                );
              }),
              if (hasMore)
                Padding(
                  padding: const EdgeInsets.only(left: Spacing.sm),
                  child: _AccountChip(
                    label: 'More',
                    icon: Icons.more_horiz_rounded,
                    color: colorScheme.onSurfaceVariant,
                    isSelected: false,
                    onTap: () => _showAccountSwitcher(
                      context, accounts, activeAccountId,
                      onAccountSelected, onMoreTap, theme,
                    ),
                    theme: theme,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: Spacing.sm),
                  child: _AccountChip(
                    label: 'Manage',
                    icon: Icons.settings_rounded,
                    color: colorScheme.onSurfaceVariant,
                    isSelected: false,
                    onTap: onMoreTap,
                    theme: theme,
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(delay: const Duration(milliseconds: 150), duration: AppDurations.medium),
      ],
    );
  }

  static IconData _iconForType(int type) {
    switch (type) {
      case 0: return Icons.account_balance_rounded;      // checking
      case 1: return Icons.savings_rounded;               // savings
      case 2: return Icons.credit_card_rounded;           // credit
      case 3: return Icons.wallet_rounded;                // cash
      case 4: return Icons.trending_up_rounded;           // investment
      default: return Icons.account_balance_wallet_rounded;
    }
  }

  static void _showAccountSwitcher(
    BuildContext context,
    List<AccountModel> accounts,
    int activeAccountId,
    ValueChanged<int> onSelected,
    VoidCallback onMoreTap,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountSwitcherSheet(
        accounts: accounts,
        activeAccountId: activeAccountId,
        onSelected: (id) {
          Navigator.of(context).pop();
          onSelected(id);
        },
        onMoreTap: () {
          Navigator.of(context).pop();
          onMoreTap();
        },
        theme: theme,
      ),
    );
  }
}

// ══ Account Chip ═════════════════════════════════════════════════════════════

class _AccountChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _AccountChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final bg = isSelected
        ? color.withValues(alpha: 0.18)
        : colorScheme.surfaceContainerHigh;
    final border = isSelected ? color : Colors.transparent;
    final labelColor = isSelected ? color : colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: labelColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: labelColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══ Account Switcher Bottom Sheet ════════════════════════════════════════════

class _AccountSwitcherSheet extends StatelessWidget {
  final List<AccountModel> accounts;
  final int activeAccountId;
  final ValueChanged<int> onSelected;
  final VoidCallback onMoreTap;
  final ThemeData theme;

  const _AccountSwitcherSheet({
    required this.accounts,
    required this.activeAccountId,
    required this.onSelected,
    required this.onMoreTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final sheetBg = colorScheme.surfaceContainerLow;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.25),
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Switch Account',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: onMoreTap,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Manage'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // All Accounts tile
          _SheetAccountTile(
            icon: Icons.account_balance_wallet_rounded,
            label: 'All Accounts',
            subtitle: 'Combined view',
            color: colorScheme.primary,
            isSelected: activeAccountId == -1,
            onTap: () => onSelected(-1),
            theme: theme,
          ),

          // Individual accounts
          ...accounts.map((acc) => _SheetAccountTile(
                icon: _GreetingHeader._iconForType(acc.accountType),
                label: acc.name,
                subtitle: _typeLabel(acc.accountType),
                color: Color(acc.color),
                isSelected: activeAccountId == acc.id,
                onTap: () => onSelected(acc.id),
                theme: theme,
              )),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  static String _typeLabel(int type) {
    switch (type) {
      case 0: return 'Checking';
      case 1: return 'Savings';
      case 2: return 'Credit Card';
      case 3: return 'Cash';
      case 4: return 'Investment';
      default: return 'Account';
    }
  }
}

class _SheetAccountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _SheetAccountTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: isSelected
            ? Border.all(color: color.withValues(alpha: 0.35), width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        onTap: onTap,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: color, size: 20)
            : null,
      ),
    );
  }
}

// ══ Balance Section ═══════════════════════════════════════════════════════════

class _BalanceSection extends StatelessWidget {
  final WidgetRef ref;
  final bool showValues;
  final String currencySymbol;

  const _BalanceSection({
    required this.ref,
    required this.showValues,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(totalBalanceProvider);

    return balanceAsync.when(
      data: (balance) => BalanceCard(
            balance: balance,
            currencySymbol: currencySymbol,
            obscureValues: !showValues,
          )
          .animate()
          .fadeIn(duration: AppDurations.medium)
          .slideY(begin: 0.05, end: 0, duration: AppDurations.medium, curve: Curves.easeOut),
      loading: () => const _BalanceCardShimmer(),
      error: (_, __) => BalanceCard(balance: 0, currencySymbol: currencySymbol, obscureValues: !showValues),
    );
  }
}

class _BalanceCardShimmer extends StatelessWidget {
  const _BalanceCardShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
          width: double.infinity, height: 120,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: AppDurations.shimmer, color: colorScheme.surface.withValues(alpha: 0.5));
  }
}

// ══ Income / Expense Row ══════════════════════════════════════════════════════

class _IncomeExpenseRow extends StatelessWidget {
  final WidgetRef ref;
  final ThemeData theme;
  final String currencySymbol;
  final bool showValues;

  const _IncomeExpenseRow({
    required this.ref,
    required this.theme,
    required this.currencySymbol,
    required this.showValues,
  });

  @override
  Widget build(BuildContext context) {
    final incomeAsync = ref.watch(monthlyIncomeProvider);
    final expenseAsync = ref.watch(monthlyExpenseProvider);
    final cheddarColors = theme.extension<CheddarColors>();

    return Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                label: 'Income', amount: incomeAsync.value ?? 0,
                isLoading: incomeAsync.isLoading,
                icon: Icons.arrow_downward_rounded,
                iconColor: cheddarColors?.income ?? Colors.green,
                theme: theme, currencySymbol: currencySymbol, showValues: showValues,
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: _MiniStatCard(
                label: 'Expense', amount: expenseAsync.value ?? 0,
                isLoading: expenseAsync.isLoading,
                icon: Icons.arrow_upward_rounded,
                iconColor: cheddarColors?.expense ?? Colors.red,
                theme: theme, currencySymbol: currencySymbol, showValues: showValues,
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(delay: const Duration(milliseconds: 200), duration: AppDurations.medium)
        .slideY(begin: 0.05, end: 0, delay: const Duration(milliseconds: 200), duration: AppDurations.medium, curve: Curves.easeOut);
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final double amount;
  final bool isLoading;
  final IconData icon;
  final Color iconColor;
  final ThemeData theme;
  final String currencySymbol;
  final bool showValues;

  const _MiniStatCard({
    required this.label, required this.amount, required this.isLoading,
    required this.icon, required this.iconColor, required this.theme,
    required this.currencySymbol, required this.showValues,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: Radii.borderLg,
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                isLoading
                    ? Container(
                        width: 60, height: 14,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: Radii.borderSm,
                        ),
                      )
                    : _BlurredValue(
                        obscure: !showValues,
                        child: Text(
                          showValues ? '$currencySymbol ${_formatCompact(amount)}' : '$currencySymbol 0000',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold, color: iconColor,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCompact(double value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000)    return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000)       return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

// ══ Quick Actions ═════════════════════════════════════════════════════════════

class _QuickActionsRow extends StatelessWidget {
  final ThemeData theme;
  const _QuickActionsRow({required this.theme});

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Row(
          children: [
            _QuickActionChip(label: 'Add Expense', icon: Icons.remove_circle_outline_rounded,
                color: colorScheme.error, onTap: () => context.pushNamed(RouteNames.addTransaction, extra: 1), theme: theme),
            const SizedBox(width: Spacing.sm),
            _QuickActionChip(label: 'Add Income', icon: Icons.add_circle_outline_rounded,
                color: Colors.green.shade600, onTap: () => context.pushNamed(RouteNames.addTransaction, extra: 0), theme: theme),
            const SizedBox(width: Spacing.sm),
            _QuickActionChip(label: 'Scan Receipt', icon: Icons.document_scanner_outlined,
                color: colorScheme.tertiary, onTap: () => context.pushNamed(RouteNames.scanner), theme: theme),
          ],
        )
        .animate()
        .fadeIn(delay: const Duration(milliseconds: 300), duration: AppDurations.medium);
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final ThemeData theme;

  const _QuickActionChip({
    required this.label, required this.icon, required this.color,
    required this.onTap, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.09),
        borderRadius: Radii.borderMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.borderMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.sm + 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: Spacing.xs),
                Text(label, style: theme.textTheme.labelSmall?.copyWith(
                  color: color, fontWeight: FontWeight.w600,
                ), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══ Mini Spending Chart ═══════════════════════════════════════════════════════

class _SpendingChart extends StatelessWidget {
  final WidgetRef ref;
  final ThemeData theme;
  final String currencySymbol;
  final bool showValues;

  const _SpendingChart({
    required this.ref, required this.theme,
    required this.currencySymbol, required this.showValues,
  });

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
          return Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: Radii.borderLg,
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.pie_chart_outline_rounded, size: 32,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                const SizedBox(width: Spacing.md),
                Text('No spending data yet', style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                )),
              ],
            ),
          );
        }

        final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final top5 = sorted.take(5).toList();
        final total = top5.fold<double>(0, (s, e) => s + e.value);

        return Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: Radii.borderLg,
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spending Breakdown', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: Spacing.md),
                  SizedBox(
                    height: 160,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120, height: 120,
                          child: PieChart(PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 28,
                            sections: List.generate(top5.length, (i) {
                              final entry = top5[i];
                              final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
                              return PieChartSectionData(
                                value: entry.value,
                                color: chartColors[i % chartColors.length],
                                radius: 28,
                                title: showValues ? '${pct.round()}%' : '••',
                                titleStyle: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10,
                                ),
                              );
                            }),
                          )),
                        ),
                        const SizedBox(width: Spacing.lg),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(top5.length, (i) {
                              final entry = top5[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10, height: 10,
                                      decoration: BoxDecoration(
                                        color: chartColors[i % chartColors.length],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.sm),
                                    Expanded(
                                      child: Text(entry.key, style: theme.textTheme.bodySmall,
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    _BlurredValue(
                                      obscure: !showValues,
                                      child: Text(
                                        showValues
                                            ? '$currencySymbol ${_MiniStatCard._formatCompact(entry.value)}'
                                            : '$currencySymbol 0000',
                                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
            .fadeIn(delay: const Duration(milliseconds: 400), duration: AppDurations.medium)
            .slideY(begin: 0.05, end: 0, delay: const Duration(milliseconds: 400), duration: AppDurations.medium, curve: Curves.easeOut);
      },
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  static const _defaultChartColors = [
    Color(0xFF6366F1), Color(0xFFF59E0B), Color(0xFF10B981),
    Color(0xFFEF4444), Color(0xFF8B5CF6),
  ];
}

// ══ Recent Transactions List ══════════════════════════════════════════════════

class _RecentTransactionsList extends StatefulWidget {
  final WidgetRef ref;
  final ThemeData theme;
  final String currencySymbol;
  final bool showValues;

  const _RecentTransactionsList({
    required this.ref, required this.theme,
    required this.currencySymbol, required this.showValues,
  });

  @override
  State<_RecentTransactionsList> createState() => _RecentTransactionsListState();
}

class _RecentTransactionsListState extends State<_RecentTransactionsList> {
  final Set<int> _dismissedIds = {};

  @override
  Widget build(BuildContext context) {
    final txnAsync = widget.ref.watch(recentTransactionsProvider);
    final cheddarColors = widget.theme.extension<CheddarColors>();

    return txnAsync.when(
      data: (allTransactions) {
        final transactions = allTransactions
            .where((t) => !_dismissedIds.contains(t.id))
            .take(5)
            .toList();

        if (transactions.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: Spacing.paddingLg,
              child: Column(
                children: [
                  SvgPicture.asset(AssetPaths.emptyTransactions, height: 120),
                  const SizedBox(height: Spacing.md),
                  Text('No transactions yet', style: widget.theme.textTheme.bodyMedium?.copyWith(
                    color: widget.theme.colorScheme.onSurfaceVariant,
                  )),
                  const SizedBox(height: Spacing.sm),
                  Text('Tap "Add Expense" to get started', style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: widget.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  )),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: Spacing.horizontalLg,
          sliver: SliverList.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final txn = transactions[index];
              return Dismissible(
                key: ValueKey(txn.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: Spacing.lg),
                  decoration: BoxDecoration(
                    color: widget.theme.colorScheme.error,
                    borderRadius: Radii.borderMd,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                confirmDismiss: (_) async =>
                    await _showDeleteConfirmation(context, widget.theme),
                onDismissed: (_) {
                  setState(() => _dismissedIds.add(txn.id));
                  final deletedTxn = txn;
                  widget.ref.read(transactionRepositoryProvider).delete(deletedTxn.id);
                  widget.ref.invalidate(recentTransactionsProvider);
                  widget.ref.invalidate(totalBalanceProvider);
                  widget.ref.invalidate(monthlyIncomeProvider);
                  widget.ref.invalidate(monthlyExpenseProvider);
                  widget.ref.invalidate(categoryTotalsProvider);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text('${deletedTxn.category} deleted'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () async {
                          await widget.ref.read(transactionRepositoryProvider).add(deletedTxn);
                          if (mounted) setState(() => _dismissedIds.remove(deletedTxn.id));
                          widget.ref.invalidate(recentTransactionsProvider);
                          widget.ref.invalidate(totalBalanceProvider);
                          widget.ref.invalidate(monthlyIncomeProvider);
                          widget.ref.invalidate(monthlyExpenseProvider);
                          widget.ref.invalidate(categoryTotalsProvider);
                        },
                      ),
                    ));
                },
                child: _TransactionRow(
                      transaction: txn,
                      theme: widget.theme,
                      cheddarColors: cheddarColors,
                      currencySymbol: widget.currencySymbol,
                      showValues: widget.showValues,
                      onTap: () => context.pushNamed(
                        RouteNames.transactionDetail,
                        pathParameters: {'id': txn.id.toString()},
                      ),
                    )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 100 * index), duration: AppDurations.medium)
                    .slideX(begin: 0.05, end: 0, delay: Duration(milliseconds: 100 * index),
                        duration: AppDurations.medium, curve: Curves.easeOut),
              );
            },
          ),
        );
      },
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: Spacing.horizontalLg,
          child: Column(children: List.generate(3, (_) => const _TransactionShimmer())),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  static Future<bool?> _showDeleteConfirmation(BuildContext context, ThemeData theme) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ══ Transaction Row ═══════════════════════════════════════════════════════════

class _TransactionRow extends StatelessWidget {
  final TransactionModel transaction;
  final ThemeData theme;
  final CheddarColors? cheddarColors;
  final String currencySymbol;
  final bool showValues;
  final VoidCallback onTap;

  const _TransactionRow({
    required this.transaction, required this.theme, required this.cheddarColors,
    required this.currencySymbol, required this.showValues, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome   = transaction.type == 0;
    final isTransfer = transaction.type == 2;
    final amountColor = isIncome
        ? (cheddarColors?.income   ?? Colors.green)
        : isTransfer
        ? (cheddarColors?.transfer ?? Colors.blue)
        : (cheddarColors?.expense  ?? Colors.red);
    final prefix  = isIncome ? '+' : isTransfer ? '' : '-';
    final dateStr = DateFormat('MMM d').format(transaction.date);
    final categoryIcon = _categoryToAssetPath(transaction.category);

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.borderMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm + 2),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    amountColor.withValues(alpha: 0.20),
                    amountColor.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: Radii.borderMd,
                border: Border.all(color: amountColor.withValues(alpha: 0.28)),
                boxShadow: [
                  BoxShadow(color: amountColor.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset(categoryIcon, width: 26, height: 26),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.category,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    transaction.note?.isNotEmpty == true
                        ? '${transaction.note} · $dateStr'
                        : dateStr,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _BlurredValue(
              obscure: !showValues,
              child: Text(
                showValues
                    ? '$prefix$currencySymbol ${transaction.amount.toStringAsFixed(0)}'
                    : '$prefix$currencySymbol 0000',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold, color: amountColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryToAssetPath(String category) {
    final normalized = category.toLowerCase().trim();
    const map = {
      'food':          AssetPaths.categoryFood,
      'transport':     AssetPaths.categoryTransport,
      'shopping':      AssetPaths.categoryShopping,
      'bills':         AssetPaths.categoryBills,
      'entertainment': AssetPaths.categoryEntertainment,
      'health':        AssetPaths.categoryHealth,
      'education':     AssetPaths.categoryEducation,
      'travel':        AssetPaths.categoryTravel,
      'gifts':         AssetPaths.categoryGifts,
      'salary':        AssetPaths.categorySalary,
      'freelance':     AssetPaths.categoryFreelance,
      'investments':   AssetPaths.categoryInvestments,
      'rent':          AssetPaths.categoryRent,
      'groceries':     AssetPaths.categoryGroceries,
      'pets':          AssetPaths.categoryPets,
      'subscriptions': AssetPaths.categorySubscriptions,
      'transfer':      AssetPaths.categoryOther,
    };
    return map[normalized] ?? AssetPaths.categoryOther;
  }
}

// ══ Blurred Value ═════════════════════════════════════════════════════════════

class _BlurredValue extends StatelessWidget {
  final bool obscure;
  final Widget child;
  const _BlurredValue({required this.obscure, required this.child});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: obscure ? 6 : 0, sigmaY: obscure ? 6 : 0),
      child: child,
    );
  }
}

// ══ Transaction Shimmer ═══════════════════════════════════════════════════════

class _TransactionShimmer extends StatelessWidget {
  const _TransactionShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Row(
            children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest, borderRadius: Radii.borderMd,
              )),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 100, height: 12, decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest, borderRadius: Radii.borderSm,
                    )),
                    const SizedBox(height: 6),
                    Container(width: 60, height: 10, decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest, borderRadius: Radii.borderSm,
                    )),
                  ],
                ),
              ),
              Container(width: 50, height: 12, decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest, borderRadius: Radii.borderSm,
              )),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: AppDurations.shimmer, color: colorScheme.surface.withValues(alpha: 0.5));
  }
}
