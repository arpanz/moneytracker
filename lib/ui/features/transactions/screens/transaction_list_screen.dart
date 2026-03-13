import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../../../../domain/models/transaction_model.dart';
import '../providers/transaction_providers.dart';

/// Full transaction list with search, filters, grouped-by-date sections,
/// swipe-to-delete/edit, empty state, and shimmer loading.
class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final filter = ref.watch(transactionFilterProvider);
    final groupedAsync = ref.watch(groupedTransactionsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar with Search ──
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('Transactions'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(108),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: Spacing.xs,
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (query) {
                        ref
                            .read(transactionFilterProvider.notifier)
                            .setSearch(query);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(transactionFilterProvider.notifier)
                                      .setSearch('');
                                  _searchFocusNode.unfocus();
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: Spacing.sm + 2,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: Radii.borderFull,
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                      ),
                    ),
                  ),

                  // Filter chips row
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: Spacing.horizontalMd,
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: filter.type == null,
                          onTap: () => ref
                              .read(transactionFilterProvider.notifier)
                              .setType(null),
                        ),
                        const SizedBox(width: Spacing.sm),
                        _FilterChip(
                          label: 'Income',
                          isSelected: filter.type == 0,
                          color: cheddarColors.income,
                          onTap: () => ref
                              .read(transactionFilterProvider.notifier)
                              .setType(filter.type == 0 ? null : 0),
                        ),
                        const SizedBox(width: Spacing.sm),
                        _FilterChip(
                          label: 'Expense',
                          isSelected: filter.type == 1,
                          color: cheddarColors.expense,
                          onTap: () => ref
                              .read(transactionFilterProvider.notifier)
                              .setType(filter.type == 1 ? null : 1),
                        ),
                        const SizedBox(width: Spacing.sm),
                        _FilterChip(
                          label: 'Transfer',
                          isSelected: filter.type == 2,
                          color: cheddarColors.transfer,
                          onTap: () => ref
                              .read(transactionFilterProvider.notifier)
                              .setType(filter.type == 2 ? null : 2),
                        ),
                        const SizedBox(width: Spacing.sm),
                        _FilterChip(
                          label: filter.dateRange != null
                              ? _formatDateRange(filter.dateRange!)
                              : 'Date Range',
                          isSelected: filter.dateRange != null,
                          icon: FontAwesomeIcons.calendar,
                          onTap: () => _pickDateRange(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ──
          groupedAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    hasFilter: filter.isActive,
                    onClear: () =>
                        ref.read(transactionFilterProvider.notifier).clearAll(),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    int runningIndex = 0;
                    for (final group in groups) {
                      if (index == runningIndex) {
                        return _DateSectionHeader(
                          date: group.date,
                          dayTotal: group.dayTotal,
                          cheddarColors: cheddarColors,
                        );
                      }
                      runningIndex++;

                      final itemIndex = index - runningIndex;
                      if (itemIndex < group.transactions.length) {
                        final txn = group.transactions[itemIndex];
                        return _TransactionTile(
                          transaction: txn,
                          cheddarColors: cheddarColors,
                          onTap: () => context.pushNamed(
                            RouteNames.transactionDetail,
                            pathParameters: {'id': txn.id.toString()},
                          ),
                          onEdit: () => context.pushNamed(
                            RouteNames.addTransaction,
                            extra: txn,
                          ),
                          onDelete: () => _confirmDelete(context, txn),
                        );
                      }
                      runningIndex += group.transactions.length;
                    }

                    return null;
                  },
                  childCount: groups.fold<int>(
                    0,
                    (sum, g) => sum + 1 + g.transactions.length,
                  ),
                ),
              );
            },
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const _ShimmerTile(),
                childCount: 8,
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      AssetPaths.errorState,
                      width: 120,
                      height: 120,
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      'Something went wrong',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      e.toString(),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // ── FAB ──
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(RouteNames.addTransaction),
        child: const FaIcon(FontAwesomeIcons.plus),
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final currentRange = ref.read(transactionFilterProvider).dateRange;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange:
          currentRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );

    if (picked != null) {
      ref.read(transactionFilterProvider.notifier).setDateRange(picked);
    }
  }

  String _formatDateRange(DateTimeRange range) {
    final fmt = DateFormat('MMM d');
    return '${fmt.format(range.start)} - ${fmt.format(range.end)}';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TransactionModel txn,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this ${txn.category} '
          'transaction of ${ref.read(currencySymbolProvider)}'
          '${NumberFormat('#,##,###.##', 'en_IN').format(txn.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(deleteTransactionProvider(txn.id).future);
    }
  }
}

// ── Filter Chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final FaIconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: Radii.borderFull,
          border: Border.all(
            color: isSelected
                ? chipColor
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              FaIcon(icon!, size: 12, color: isSelected ? chipColor : null),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? chipColor : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date Section Header ─────────────────────────────────────────────────────

class _DateSectionHeader extends ConsumerWidget {
  final DateTime date;
  final double dayTotal;
  final CheddarColors cheddarColors;

  const _DateSectionHeader({
    required this.date,
    required this.dayTotal,
    required this.cheddarColors,
  });

  String get _dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    return DateFormat('EEEE, MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatter = NumberFormat('#,##,###.##', 'en_IN');
    final isPositive = dayTotal >= 0;
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.md,
        Spacing.xs,
      ),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _dateLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Text(
            '${isPositive ? '+' : '-'}$currencySymbol'
            '${formatter.format(dayTotal.abs())}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isPositive ? cheddarColors.income : cheddarColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Tile ────────────────────────────────────────────────────────

class _TransactionTile extends ConsumerWidget {
  final TransactionModel transaction;
  final CheddarColors cheddarColors;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.transaction,
    required this.cheddarColors,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _amountColor {
    switch (transaction.type) {
      case 0:
        return cheddarColors.income;
      case 2:
        return cheddarColors.transfer;
      default:
        return cheddarColors.expense;
    }
  }

  String get _amountPrefix {
    switch (transaction.type) {
      case 0:
        return '+';
      case 2:
        return '';
      default:
        return '-';
    }
  }

  Color get _categoryColor {
    return cheddarColors.categoryColors[transaction.category.toLowerCase()] ??
        cheddarColors.transfer;
  }

  // FIX [Bug 3]: Always return a valid path; unknown categories → categoryOther.
  String get _categoryIconPath {
    final slug = transaction.category.toLowerCase().trim();
    const knownSlugs = {
      'food', 'transport', 'shopping', 'bills', 'entertainment',
      'health', 'education', 'travel', 'gifts', 'salary',
      'freelance', 'investments', 'rent', 'groceries', 'pets',
      'subscriptions', 'other',
    };
    if (knownSlugs.contains(slug)) {
      return 'assets/svg/categories/$slug.svg';
    }
    return AssetPaths.categoryOther;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatter = NumberFormat('#,##,###.##', 'en_IN');
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Dismissible(
      key: ValueKey(transaction.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: Spacing.lg),
        color: cheddarColors.transfer,
        child: const FaIcon(
          FontAwesomeIcons.penToSquare,
          color: Colors.white,
          size: 20,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.lg),
        color: cheddarColors.expense,
        child: const FaIcon(
          FontAwesomeIcons.trash,
          color: Colors.white,
          size: 20,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onDelete();
          return false;
        } else {
          onEdit();
          return false;
        }
      },
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _categoryColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              _categoryIconPath,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(_categoryColor, BlendMode.srcIn),
            ),
          ),
        ),
        title: Text(
          transaction.category,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          transaction.note ?? transaction.accountId,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Hero(
          tag: 'txn_amount_${transaction.id}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              '$_amountPrefix$currencySymbol'
              '${formatter.format(transaction.amount)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: _amountColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onClear;

  const _EmptyState({required this.hasFilter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: Spacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              AssetPaths.emptyTransactions,
              width: 180,
              height: 180,
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              hasFilter ? 'No matching transactions' : 'No transactions yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              hasFilter
                  ? 'Try adjusting your filters or search terms.'
                  : 'Tap the + button to add your first transaction.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: Spacing.md),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shimmer Loading Tile ────────────────────────────────────────────────────

class _ShimmerTile extends StatelessWidget {
  const _ShimmerTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final baseColor = cheddarColors.shimmerBase;
    final highlightColor = cheddarColors.shimmerHighlight;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: Row(
        children: [
          _ShimmerBox(
            width: 40,
            height: 40,
            isCircle: true,
            baseColor: baseColor,
            highlightColor: highlightColor,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                  width: 120,
                  height: 14,
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                ),
                const SizedBox(height: 6),
                _ShimmerBox(
                  width: 80,
                  height: 10,
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                ),
              ],
            ),
          ),
          _ShimmerBox(
            width: 64,
            height: 16,
            baseColor: baseColor,
            highlightColor: highlightColor,
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final bool isCircle;
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.isCircle = false,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.shimmer,
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: widget.baseColor,
      end: widget.highlightColor,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle ? null : Radii.borderSm,
          ),
        );
      },
    );
  }
}
