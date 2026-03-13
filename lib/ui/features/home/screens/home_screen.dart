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
import '../../../../config/constants/category_catalog.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
              // ── Top Bar (account chip + actions) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.lg,
                    Spacing.lg,
                    Spacing.sm,
                    0,
                  ),
                  child: _HomeTopBar(
                    showValues: showValues,
                    pendingCount: pendingCount,
                    accounts: accountsAsync.value ?? [],
                    activeAccountId: activeAccountId,
                    theme: theme,
                    onToggleTheme: () =>
                        ref.read(themeProvider.notifier).toggleTheme(),
                    onToggleVisibility: () async {
                      final nextValue = !ref.read(showValuesProvider);
                      ref.read(showValuesProvider.notifier).state = nextValue;
                      final prefs = ref.read(sharedPreferencesProvider);
                      await prefs.setBool(
                        AppConstants.prefShowValues,
                        nextValue,
                      );
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

              // ── Month / Year Selector ──
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: _MonthYearSelector(),
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
                        onPressed: () =>
                            context.goNamed(RouteNames.transactions),
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
                  height:
                      kBottomNavigationBarHeight +
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

// ══ Top Bar ════════════════════════════════════════════════════════════════════

class _HomeTopBar extends StatelessWidget {
  final ThemeData theme;
  final bool showValues;
  final int pendingCount;
  final List<AccountModel> accounts;
  final int activeAccountId;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleVisibility;
  final VoidCallback onPendingTap;
  final ValueChanged<int> onAccountSelected;
  final VoidCallback onMoreTap;

  const _HomeTopBar({
    required this.theme,
    required this.showValues,
    required this.pendingCount,
    required this.accounts,
    required this.activeAccountId,
    required this.onToggleTheme,
    required this.onToggleVisibility,
    required this.onPendingTap,
    required this.onAccountSelected,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selectedAccount = _findSelectedAccount(accounts, activeAccountId);

    final accountLabel = activeAccountId == -1
        ? 'All Accounts'
        : selectedAccount?.name ?? 'Account';
    final accountColor = activeAccountId == -1
        ? colorScheme.primary
        : Color(selectedAccount?.color ?? colorScheme.primary.value);
    final accountIcon = activeAccountId == -1
        ? Icons.account_balance_wallet_rounded
        : _iconForType(selectedAccount?.accountType ?? 0);

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _AccountDropdownChip(
              label: accountLabel,
              icon: accountIcon,
              color: accountColor,
              theme: theme,
              onTap: () => _showAccountSwitcher(
                context,
                accounts,
                activeAccountId,
                onAccountSelected,
                onMoreTap,
                theme,
              ),
            ),
          ),
        ),
        if (pendingCount > 0)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onPendingTap,
                tooltip:
                    '$pendingCount pending transaction${pendingCount == 1 ? '' : 's'}',
                icon: const Icon(Icons.notifications_rounded),
                color: colorScheme.primary,
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$pendingCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onError,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1,
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
          icon: Icon(
            showValues
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
          ),
          color: colorScheme.onSurfaceVariant,
        ),
        IconButton(
          onPressed: onToggleTheme,
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          color: colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  static AccountModel? _findSelectedAccount(
    List<AccountModel> accounts,
    int id,
  ) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  static IconData _iconForType(int type) {
    switch (type) {
      case 0:
        return Icons.account_balance_rounded;
      case 1:
        return Icons.savings_rounded;
      case 2:
        return Icons.credit_card_rounded;
      case 3:
        return Icons.wallet_rounded;
      case 4:
        return Icons.trending_up_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
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

class _AccountDropdownChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final ThemeData theme;
  final VoidCallback onTap;

  const _AccountDropdownChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: Border.all(
              color: color.withValues(alpha: 0.45),
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══ Month / Year Selector ═════════════════════════════════════════════════════

class _MonthYearSelector extends ConsumerWidget {
  const _MonthYearSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedMonth = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MonthNavButton(
          icon: Icons.chevron_left_rounded,
          enabled: true,
          onTap: () {
            ref.read(selectedMonthProvider.notifier).state = DateTime(
              selectedMonth.year,
              selectedMonth.month - 1,
            );
          },
        ),
        const SizedBox(width: Spacing.sm),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _pickMonthYear(context, ref, selectedMonth),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.all(Radius.circular(999)),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(selectedMonth),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        _MonthNavButton(
          icon: Icons.chevron_right_rounded,
          enabled: !isCurrentMonth,
          onTap: () {
            ref.read(selectedMonthProvider.notifier).state = DateTime(
              selectedMonth.year,
              selectedMonth.month + 1,
            );
          },
        ),
      ],
    );
  }

  static Future<void> _pickMonthYear(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedMonth,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2010, 1, 1),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select month and year',
    );

    if (picked != null) {
      ref.read(selectedMonthProvider.notifier).state = DateTime(
        picked.year,
        picked.month,
      );
    }
  }
}

class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _MonthNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: enabled ? onTap : null,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerLow,
        disabledBackgroundColor: colorScheme.surfaceContainerLow.withValues(
          alpha: 0.6,
        ),
      ),
      icon: Icon(icon),
      color: colorScheme.onSurfaceVariant,
      disabledColor: colorScheme.onSurface.withValues(alpha: 0.25),
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
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
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
                Text(
                  'Switch Account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: onMoreTap,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Manage'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _SheetAccountTile(
            icon: Icons.account_balance_wallet_rounded,
            label: 'All Accounts',
            subtitle: 'Combined view',
            color: colorScheme.primary,
            isSelected: activeAccountId == -1,
            onTap: () => onSelected(-1),
            theme: theme,
          ),
          ...accounts.map(
            (acc) => _SheetAccountTile(
              icon: _HomeTopBar._iconForType(acc.accountType),
              label: acc.name,
              subtitle: _typeLabel(acc.accountType),
              color: Color(acc.color),
              isSelected: activeAccountId == acc.id,
              onTap: () => onSelected(acc.id),
              theme: theme,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  static String _typeLabel(int type) {
    switch (type) {
      case 0:
        return 'Checking';
      case 1:
        return 'Savings';
      case 2:
        return 'Credit Card';
      case 3:
        return 'Cash';
      case 4:
        return 'Investment';
      default:
        return 'Account';
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
          width: 42,
          height: 42,
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
      ),
      loading: () => const _BalanceCardShimmer(),
      error: (_, __) => BalanceCard(
        balance: 0,
        currencySymbol: currencySymbol,
        obscureValues: !showValues,
      ),
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

// ══ Income / Expense Row ═════════════════════════════════════════════════════════

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
            label: 'Income',
            amount: incomeAsync.value ?? 0,
            isLoading: incomeAsync.isLoading,
            icon: Icons.arrow_downward_rounded,
            iconColor: cheddarColors?.income ?? Colors.green,
            theme: theme,
            currencySymbol: currencySymbol,
            showValues: showValues,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _MiniStatCard(
            label: 'Expense',
            amount: expenseAsync.value ?? 0,
            isLoading: expenseAsync.isLoading,
            icon: Icons.arrow_upward_rounded,
            iconColor: cheddarColors?.expense ?? Colors.red,
            theme: theme,
            currencySymbol: currencySymbol,
            showValues: showValues,
          ),
        ),
      ],
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
  final String currencySymbol;
  final bool showValues;

  const _MiniStatCard({
    required this.label,
    required this.amount,
    required this.isLoading,
    required this.icon,
    required this.iconColor,
    required this.theme,
    required this.currencySymbol,
    required this.showValues,
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
                    : _BlurredValue(
                        obscure: !showValues,
                        child: Text(
                          showValues
                              ? '$currencySymbol ${_formatCompact(amount)}'
                              : '$currencySymbol 0000',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    if (value >= 1000000000)
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

// ══ Mini Spending Chart ═════════════════════════════════════════════════════════

class _SpendingChart extends StatelessWidget {
  final WidgetRef ref;
  final ThemeData theme;
  final String currencySymbol;
  final bool showValues;

  const _SpendingChart({
    required this.ref,
    required this.theme,
    required this.currencySymbol,
    required this.showValues,
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
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 32,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(width: Spacing.md),
                Text(
                  'No spending data yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        final sorted = totals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top5 = sorted.take(5).toList();
        final total = top5.fold<double>(0, (s, e) => s + e.value);

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
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 28,
                          sections: List.generate(top5.length, (i) {
                            final entry = top5[i];
                            final sectionColor =
                                chartColors[i % chartColors.length];
                            final sectionOnColor =
                                ThemeData.estimateBrightnessForColor(
                                      sectionColor,
                                    ) ==
                                    Brightness.dark
                                ? Colors.white
                                : const Color(0xFF121212);
                            final pct = total > 0
                                ? (entry.value / total) * 100
                                : 0.0;
                            return PieChartSectionData(
                              value: entry.value,
                              color: sectionColor,
                              radius: 28,
                              title: showValues ? '${pct.round()}%' : '••',
                              titleStyle: theme.textTheme.labelSmall?.copyWith(
                                color: sectionOnColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            );
                          }),
                        ),
                      ),
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
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: chartColors[i % chartColors.length],
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
                                _BlurredValue(
                                  obscure: !showValues,
                                  child: Text(
                                    showValues
                                        ? '$currencySymbol ${_MiniStatCard._formatCompact(entry.value)}'
                                        : '$currencySymbol 0000',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
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

// ══ Recent Transactions List ═══════════════════════════════════════════════════════

class _RecentTransactionsList extends StatefulWidget {
  final WidgetRef ref;
  final ThemeData theme;
  final String currencySymbol;
  final bool showValues;

  const _RecentTransactionsList({
    required this.ref,
    required this.theme,
    required this.currencySymbol,
    required this.showValues,
  });

  @override
  State<_RecentTransactionsList> createState() =>
      _RecentTransactionsListState();
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
                  Text(
                    'No transactions yet',
                    style: widget.theme.textTheme.bodyMedium?.copyWith(
                      color: widget.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Tap + to add your first transaction',
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                      color: widget.theme.colorScheme.onSurfaceVariant
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
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: widget.theme.colorScheme.onError,
                  ),
                ),
                confirmDismiss: (_) async =>
                    await _showDeleteConfirmation(context, widget.theme),
                onDismissed: (_) {
                  setState(() => _dismissedIds.add(txn.id));
                  final deletedTxn = txn;
                  widget.ref
                      .read(transactionRepositoryProvider)
                      .delete(deletedTxn.id);
                  widget.ref.invalidate(recentTransactionsProvider);
                  widget.ref.invalidate(totalBalanceProvider);
                  widget.ref.invalidate(monthlyIncomeProvider);
                  widget.ref.invalidate(monthlyExpenseProvider);
                  widget.ref.invalidate(categoryTotalsProvider);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('${deletedTxn.category} deleted'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: Radii.borderMd,
                        ),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () async {
                            await widget.ref
                                .read(transactionRepositoryProvider)
                                .add(deletedTxn);
                            if (mounted) {
                              setState(
                                () => _dismissedIds.remove(deletedTxn.id),
                              );
                            }
                            widget.ref.invalidate(recentTransactionsProvider);
                            widget.ref.invalidate(totalBalanceProvider);
                            widget.ref.invalidate(monthlyIncomeProvider);
                            widget.ref.invalidate(monthlyExpenseProvider);
                            widget.ref.invalidate(categoryTotalsProvider);
                          },
                        ),
                      ),
                    );
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
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
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

// ══ Transaction Row ═══════════════════════════════════════════════════════════════

class _TransactionRow extends StatelessWidget {
  final TransactionModel transaction;
  final ThemeData theme;
  final CheddarColors? cheddarColors;
  final String currencySymbol;
  final bool showValues;
  final VoidCallback onTap;

  const _TransactionRow({
    required this.transaction,
    required this.theme,
    required this.cheddarColors,
    required this.currencySymbol,
    required this.showValues,
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
    final prefix = isIncome
        ? '+'
        : isTransfer
        ? ''
        : '-';
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    amountColor.withValues(alpha: 0.20),
                    amountColor.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: Radii.borderMd,
                border: Border.all(color: amountColor.withValues(alpha: 0.28)),
                boxShadow: [
                  BoxShadow(
                    color: amountColor.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
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
            _BlurredValue(
              obscure: !showValues,
              child: Text(
                showValues
                    ? '$prefix$currencySymbol ${transaction.amount.toStringAsFixed(0)}'
                    : '$prefix$currencySymbol 0000',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryToAssetPath(String category) {
    return CategoryCatalog.assetPathForName(category);
  }
}

// ══ Blurred Value ═══════════════════════════════════════════════════════════════════

class _BlurredValue extends StatelessWidget {
  final bool obscure;
  final Widget child;
  const _BlurredValue({required this.obscure, required this.child});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: obscure ? 6 : 0,
        sigmaY: obscure ? 6 : 0,
      ),
      child: child,
    );
  }
}

// ══ Transaction Shimmer ═════════════════════════════════════════════════════════════

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
                height: 12,
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
