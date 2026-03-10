import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../../../../domain/models/transaction_model.dart';
import '../providers/notification_provider.dart';

/// Screen showing transactions detected from payment notifications.
/// Users can review, save, or dismiss each pending transaction.
class PendingTransactionsScreen extends ConsumerWidget {
  const PendingTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingTransactionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pending Transactions'),
            if (pending.isNotEmpty) ...[
              const SizedBox(width: Spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: Radii.borderFull,
                ),
                child: Text(
                  '${pending.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (pending.isNotEmpty)
            TextButton(
              onPressed: () => _showDismissAllDialog(context, ref),
              child: Text(
                'Dismiss All',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: pending.isEmpty
          ? _buildEmptyState(context, theme)
          : RefreshIndicator(
              onRefresh: () async {
                // Re-read from service (triggers stream update)
                ref.invalidate(pendingTransactionsProvider);
              },
              child: ListView.builder(
                padding: Spacing.paddingMd,
                itemCount: pending.length + 1, // +1 for info card
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildInfoCard(theme);
                  }
                  final tx = pending[index - 1];
                  return _PendingTransactionCard(
                        transaction: tx,
                        onSave: () => _saveTransaction(context, ref, tx),
                        onDismiss: () => _dismissTransaction(ref, tx),
                      )
                      .animate()
                      .fadeIn(
                        duration: 300.ms,
                        delay: Duration(milliseconds: 50 * (index - 1)),
                      )
                      .slideX(begin: 0.1);
                },
              ),
            ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: Spacing.paddingMd,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: Radii.borderMd,
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.circleInfo,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'These transactions were detected from your payment '
              'notifications. Tap Save to review and add them to your records.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: Spacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              AssetPaths.emptyTransactions,
              width: 180,
              height: 180,
              colorFilter: ColorFilter.mode(
                theme.colorScheme.primary.withOpacity(0.5),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'No Pending Transactions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Payment notifications will appear here\nautomatically when detected.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
      ),
    );
  }

  void _saveTransaction(
    BuildContext context,
    WidgetRef ref,
    PendingTransaction tx,
  ) {
    // Mark as saved in the provider
    ref.read(pendingTransactionsProvider.notifier).markSaved(tx.id);

    // Create a pre-filled transaction and navigate to add screen
    final transaction = TransactionModel()
      ..amount = tx.amount
      ..type = tx.isDebit
          ? 1
          : 0 // 1 = expense, 0 = income
      ..note = tx.merchant ?? tx.appName
      ..date = tx.timestamp
      ..createdAt = DateTime.now();

    context.pushNamed(RouteNames.addTransaction, extra: transaction);
  }

  void _dismissTransaction(WidgetRef ref, PendingTransaction tx) {
    ref.read(pendingTransactionsProvider.notifier).dismiss(tx.id);
  }

  void _showDismissAllDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Dismiss All?'),
          content: const Text(
            'This will remove all pending transactions. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(pendingTransactionsProvider.notifier).dismissAll();
                Navigator.of(dialogContext).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: const Text('Dismiss All'),
            ),
          ],
        );
      },
    );
  }
}

// ── Pending Transaction Card ──

class _PendingTransactionCard extends StatelessWidget {
  final PendingTransaction transaction;
  final VoidCallback onSave;
  final VoidCallback onDismiss;

  const _PendingTransactionCard({
    required this.transaction,
    required this.onSave,
    required this.onDismiss,
  });

  /// Map app icon identifiers to FontAwesome icons.
  static const _appIconMap = <String, FaIconData>{
    'gpay': FontAwesomeIcons.googlePay,
    'phonepe': FontAwesomeIcons.mobile,
    'paytm': FontAwesomeIcons.wallet,
    'bhim': FontAwesomeIcons.buildingColumns,
  };

  FaIconData get _appIcon {
    if (transaction.appIcon != null &&
        _appIconMap.containsKey(transaction.appIcon)) {
      return _appIconMap[transaction.appIcon]!;
    }
    // Default icon for bank apps
    return FontAwesomeIcons.buildingColumns;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>();
    final isDebit = transaction.isDebit;

    final amountColor = isDebit
        ? (cheddarColors?.expense ?? Colors.red)
        : (cheddarColors?.income ?? Colors.green);

    final amountPrefix = isDebit ? '-' : '+';
    final formattedAmount = _formatAmount(transaction.amount);
    final formattedDate = DateFormat(
      'dd MMM, hh:mm a',
    ).format(transaction.timestamp);

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withOpacity(0.1),
          borderRadius: Radii.borderMd,
        ),
        child: FaIcon(
          FontAwesomeIcons.trash,
          color: theme.colorScheme.error,
          size: 20,
        ),
      ),
      onDismissed: (_) => onDismiss(),
      child: Card(
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        child: Padding(
          padding: Spacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: app icon/name + amount
              Row(
                children: [
                  // App icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(
                        0.5,
                      ),
                      borderRadius: Radii.borderSm,
                    ),
                    child: Center(
                      child: FaIcon(
                        _appIcon,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),

                  // App name and merchant
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.appName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (transaction.merchant != null)
                          Text(
                            transaction.merchant!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$amountPrefix${AppConstants.currencySymbol}$formattedAmount',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: amountColor.withOpacity(0.1),
                          borderRadius: Radii.borderFull,
                        ),
                        child: Text(
                          isDebit ? 'Debit' : 'Credit',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: amountColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: Spacing.sm),

              // Date & time
              Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.clock,
                    size: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: Spacing.md),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDismiss,
                      icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
                      label: const Text('Dismiss'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface
                            .withOpacity(0.6),
                        side: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: Spacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onSave,
                      icon: const FaIcon(FontAwesomeIcons.floppyDisk, size: 14),
                      label: const Text('Save'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: Spacing.sm,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format amount with Indian-style comma grouping.
  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)} Cr';
    }
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)} L';
    }

    final wholePart = amount.truncate();
    final decimalPart = ((amount - wholePart) * 100).round();
    final wholeStr = wholePart.toString();

    // Indian comma format: last 3 digits, then groups of 2
    if (wholeStr.length <= 3) {
      return decimalPart > 0
          ? '$wholeStr.${decimalPart.toString().padLeft(2, '0')}'
          : wholeStr;
    }

    final lastThree = wholeStr.substring(wholeStr.length - 3);
    final remaining = wholeStr.substring(0, wholeStr.length - 3);
    final buffer = StringBuffer();
    for (var i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    buffer.write(',');
    buffer.write(lastThree);

    if (decimalPart > 0) {
      buffer.write('.${decimalPart.toString().padLeft(2, '0')}');
    }

    return buffer.toString();
  }
}
