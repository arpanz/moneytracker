import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/subscription_model.dart';

/// Subscription list screen with monthly cost summary, upcoming bills,
/// auto-detected subscriptions, and insights.
class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  List<SubscriptionModel> _subscriptions = [];
  double _monthlyTotal = 0;
  double _yearlyTotal = 0;
  bool _isLoading = true;
  // FIX #16: store runtime currency symbol
  String _currencySymbol = '\u20b9';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final subRepo = ref.read(subscriptionRepositoryProvider);
    final subs = await subRepo.getAll();
    final monthly = await subRepo.getMonthlyTotal();
    final yearly = await subRepo.getYearlyTotal();
    // FIX #16: read live currency symbol on each load
    final symbol = ref.read(currencySymbolProvider);

    if (mounted) {
      setState(() {
        _subscriptions = subs;
        _monthlyTotal = monthly;
        _yearlyTotal = yearly;
        _currencySymbol = symbol;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActive(SubscriptionModel sub) async {
    final subRepo = ref.read(subscriptionRepositoryProvider);
    sub.isActive = !sub.isActive;
    await subRepo.update(sub);
    await _loadData();
  }

  Future<void> _deleteSub(SubscriptionModel sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Text('Delete "${sub.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(subscriptionRepositoryProvider).delete(sub.id);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // Also watch the provider live so the UI rebuilds if currency changes
    final currencySymbol = ref.watch(currencySymbolProvider);

    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (_subscriptions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscriptions')),
        body: _buildEmptyState(context),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await context.pushNamed(RouteNames.addSubscription);
            _loadData();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Subscription'),
        ),
      );
    }

    final activeSubs = _subscriptions.where((s) => s.isActive).toList();
    final inactiveSubs = _subscriptions.where((s) => !s.isActive).toList();
    final autoDetected =
        _subscriptions.where((s) => s.isAutoDetected).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: Radii.borderFull,
                ),
                child: Text(
                  // FIX #16: runtime symbol
                  '$currencySymbol ${_formatIndian(_monthlyTotal)}/mo',
                  style: textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _buildSummaryCard(context, currencySymbol)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.1, end: 0),
            const SizedBox(height: Spacing.lg),

            if (activeSubs.isNotEmpty) ...[
              Text('Active Subscriptions',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: Spacing.sm),
              ...activeSubs.asMap().entries.map((entry) {
                return _buildSubscriptionCard(
                        context, entry.value, currencySymbol)
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 80 * entry.key),
                      duration: 300.ms,
                    )
                    .slideX(begin: 0.1, end: 0);
              }),
            ],

            if (autoDetected.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('Auto-Detected',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Card(
                // FIX: withOpacity → withValues
                color: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.2),
                child: Padding(
                  padding: Spacing.paddingSm,
                  child: Column(
                    children: autoDetected
                        .map((s) => ListTile(
                              dense: true,
                              leading: Icon(Icons.subscriptions_outlined,
                                  color: theme.colorScheme.primary),
                              title: Text(s.name),
                              subtitle: Text(
                                // FIX #16: runtime symbol
                                '$currencySymbol ${s.amount.toStringAsFixed(0)} / ${_frequencyLabel(s.frequency)}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],

            if (_subscriptions.length > 1) ...[
              const SizedBox(height: Spacing.lg),
              _buildInsightsCard(context, inactiveSubs, currencySymbol),
            ],

            if (inactiveSubs.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              Text('Inactive',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: Spacing.sm),
              ...inactiveSubs.map(
                  (s) => _buildSubscriptionCard(context, s, currencySymbol,
                      isInactive: true)),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.pushNamed(RouteNames.addSubscription);
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String currencySymbol) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      child: Padding(
        padding: Spacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscription Summary',
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monthly',
                          style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        // FIX #16: runtime symbol
                        '$currencySymbol ${_formatIndian(_monthlyTotal)}',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Yearly',
                            style: textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          // FIX #16: runtime symbol
                          '$currencySymbol ${_formatIndian(_yearlyTotal)}',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(
      BuildContext context, SubscriptionModel sub, String currencySymbol,
      {bool isInactive = false}) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final now = DateTime.now();
    final daysUntilBill = sub.nextBillDate.difference(now).inDays;
    final countdownText = daysUntilBill <= 0
        ? 'Due today'
        : daysUntilBill == 1
            ? 'in 1 day'
            : 'in $daysUntilBill days';

    return Dismissible(
      key: Key('sub_${sub.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: Radii.borderMd,
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteSub(sub);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isInactive
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.primaryContainer,
                  borderRadius: Radii.borderMd,
                ),
                child: Center(
                  child: Icon(
                    Icons.subscriptions_rounded,
                    color: isInactive
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isInactive
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (!isInactive)
                          Text(
                            countdownText,
                            style: textTheme.bodySmall?.copyWith(
                              color: daysUntilBill <= 3
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: daysUntilBill <= 3
                                  ? FontWeight.w600
                                  : null,
                            ),
                          ),
                        if (!isInactive)
                          Text(' · ', style: textTheme.bodySmall),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: Radii.borderFull,
                          ),
                          child: Text(
                            _frequencyLabel(sub.frequency),
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    // FIX #16: runtime symbol
                    '$currencySymbol ${sub.amount.toStringAsFixed(0)}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isInactive
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: Switch(
                  value: sub.isActive,
                  onChanged: (_) => _toggleActive(sub),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsCard(
      BuildContext context,
      List<SubscriptionModel> inactiveSubs,
      String currencySymbol) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    double wastedAmount = 0;
    final wasteful = <SubscriptionModel>[];
    for (final sub in _subscriptions) {
      if (!sub.isActive) {
        wastedAmount += _toMonthly(sub.amount, sub.frequency);
        wasteful.add(sub);
      }
    }

    if (wastedAmount <= 0) return const SizedBox.shrink();

    return Card(
      // FIX: withOpacity → withValues
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: Spacing.paddingMd,
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline,
                color: theme.colorScheme.tertiary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Insights',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.tertiary,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    // FIX #16: runtime symbol in insights text
                    'You have ${wasteful.length} inactive subscription(s) '
                    'that could save you $currencySymbol ${wastedAmount.toStringAsFixed(0)}/month '
                    'if cancelled.',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: Spacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AssetPaths.emptySubscriptions,
                width: 200, height: 200),
            const SizedBox(height: Spacing.lg),
            Text('No Subscriptions Yet',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.sm),
            Text(
              'Track your recurring expenses.\nTap + to add your first subscription.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _frequencyLabel(int frequency) {
    switch (frequency) {
      case 0:
        return 'Weekly';
      case 1:
        return 'Monthly';
      case 2:
        return 'Quarterly';
      case 3:
        return 'Yearly';
      default:
        return 'Monthly';
    }
  }

  double _toMonthly(double amount, int frequency) {
    switch (frequency) {
      case 0:
        return amount * 4.33;
      case 1:
        return amount;
      case 2:
        return amount / 3.0;
      case 3:
        return amount / 12.0;
      default:
        return amount;
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
    if (remaining.isNotEmpty) result = '$remaining,$result';
    return result;
  }
}
