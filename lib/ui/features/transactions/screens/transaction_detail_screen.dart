import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../../../../domain/models/split_model.dart';
import '../../../../domain/models/transaction_model.dart';
import '../providers/transaction_providers.dart';

/// Detail view for a single transaction.
///
/// Expects the transaction id as a path parameter via GoRouter.
class TransactionDetailScreen extends ConsumerWidget {
  final int transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnAsync = ref.watch(transactionByIdProvider(transactionId));
    final theme = Theme.of(context);

    return txnAsync.when(
      data: (txn) {
        if (txn == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Transaction')),
            body: const Center(child: Text('Transaction not found.')),
          );
        }
        return _TransactionDetailContent(transaction: txn);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: Center(
          child: Text('Error: $e', style: theme.textTheme.bodyMedium),
        ),
      ),
    );
  }
}

// ── Detail Content ──────────────────────────────────────────────────────────

class _TransactionDetailContent extends ConsumerWidget {
  final TransactionModel transaction;

  const _TransactionDetailContent({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final amountColor = _typeColor(cheddarColors);
    final formatter = NumberFormat('#,##,###.##', 'en_IN');
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 18),
            onPressed: () => context.pushNamed(
              RouteNames.addTransaction,
              extra: transaction,
            ),
            tooltip: 'Edit',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: Spacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Spacing.lg),

            // ── Amount Hero ──
            Center(
              child: Column(
                children: [
                  _TypeBadge(type: transaction.type, colors: cheddarColors),
                  const SizedBox(height: Spacing.md),
                  Hero(
                    tag: 'txn_amount_${transaction.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_amountPrefix}${AppConstants.currencySymbol}'
                          '${formatter.format(transaction.amount)}',
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: amountColor,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Spacing.xl),

            // ── Info Cards ──
            _InfoCard(
              icon: FontAwesomeIcons.layerGroup,
              label: 'Category',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _categoryColor(cheddarColors).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/svg/categories/${transaction.category.toLowerCase()}.svg',
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(
                          _categoryColor(cheddarColors),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    transaction.category,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (transaction.subcategory != null) ...[
                    Text(
                      ' / ${transaction.subcategory}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: Spacing.sm),

            _InfoCard(
              icon: FontAwesomeIcons.wallet,
              label: 'Account',
              child: Row(
                children: [
                  Text(
                    transaction.accountId,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (transaction.type == 2 &&
                      transaction.toAccountId != null) ...[
                    const SizedBox(width: Spacing.sm),
                    FaIcon(
                      FontAwesomeIcons.arrowRight,
                      size: 12,
                      color: cheddarColors.transfer,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      transaction.toAccountId!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: Spacing.sm),

            _InfoCard(
              icon: FontAwesomeIcons.calendar,
              label: 'Date & Time',
              child: Text(
                '${dateFormat.format(transaction.date)} at '
                '${timeFormat.format(transaction.date)}',
                style: theme.textTheme.bodyLarge,
              ),
            ),

            if (transaction.note != null && transaction.note!.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              _InfoCard(
                icon: FontAwesomeIcons.noteSticky,
                label: 'Note',
                child: Text(
                  transaction.note!,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],

            if (transaction.tags.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              _InfoCard(
                icon: FontAwesomeIcons.tags,
                label: 'Tags',
                child: Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: transaction.tags.map((tag) {
                    return Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: Radii.borderFull,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // ── Receipt Image ──
            if (transaction.receiptImagePath != null) ...[
              const SizedBox(height: Spacing.md),
              _ReceiptSection(imagePath: transaction.receiptImagePath!),
            ],

            // ── Recurring Info ──
            if (transaction.isRecurring) ...[
              const SizedBox(height: Spacing.md),
              _RecurringSection(recurringRule: transaction.recurringRule),
            ],

            // ── Split Info ──
            if (transaction.splitId != null) ...[
              const SizedBox(height: Spacing.md),
              _SplitSection(splitId: transaction.splitId!, ref: ref),
            ],

            const SizedBox(height: Spacing.xl),

            // ── Delete Button ──
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: FaIcon(
                  FontAwesomeIcons.trash,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                label: Text(
                  'Delete Transaction',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.error),
                  shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
                ),
              ),
            ),

            const SizedBox(height: Spacing.xxl),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Color _typeColor(CheddarColors colors) {
    switch (transaction.type) {
      case 0:
        return colors.income;
      case 2:
        return colors.transfer;
      default:
        return colors.expense;
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

  Color _categoryColor(CheddarColors colors) {
    return colors.categoryColors[transaction.category.toLowerCase()] ??
        colors.transfer;
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text(
            'This action cannot be undone. Are you sure you want to delete '
            'this transaction?',
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
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await ref.read(deleteTransactionProvider(transaction.id).future);
      if (context.mounted) {
        context.pop();
      }
    }
  }
}

// ── Type Badge ──────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final int type;
  final CheddarColors colors;

  const _TypeBadge({required this.type, required this.colors});

  String get _label {
    switch (type) {
      case 0:
        return 'Income';
      case 2:
        return 'Transfer';
      default:
        return 'Expense';
    }
  }

  FaIconData get _icon {
    switch (type) {
      case 0:
        return FontAwesomeIcons.arrowUp;
      case 2:
        return FontAwesomeIcons.arrowRightArrowLeft;
      default:
        return FontAwesomeIcons.arrowDown;
    }
  }

  Color get _color {
    switch (type) {
      case 0:
        return colors.income;
      case 2:
        return colors.transfer;
      default:
        return colors.expense;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: Radii.borderFull,
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(_icon, size: 12, color: _color),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Card ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final Widget child;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
      child: Padding(
        padding: Spacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(icon, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: Spacing.sm),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Receipt Section ─────────────────────────────────────────────────────────

class _ReceiptSection extends StatelessWidget {
  final String imagePath;

  const _ReceiptSection({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _InfoCard(
      icon: FontAwesomeIcons.receipt,
      label: 'Receipt',
      child: GestureDetector(
        onTap: () => _viewFullscreen(context),
        child: ClipRRect(
          borderRadius: Radii.borderMd,
          child: Image.file(
            File(imagePath),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: Radii.borderMd,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.image,
                      size: 24,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Unable to load receipt',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(child: Image.file(File(imagePath))),
          ),
        ),
      ),
    );
  }
}

// ── Recurring Section ───────────────────────────────────────────────────────

class _RecurringSection extends StatelessWidget {
  final String? recurringRule;

  const _RecurringSection({required this.recurringRule});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String frequency = 'Monthly';
    String nextOccurrence = 'Unknown';

    if (recurringRule != null) {
      try {
        final rule = json.decode(recurringRule!) as Map<String, dynamic>;
        final rawFreq = (rule['frequency'] as String?) ?? 'monthly';
        frequency = rawFreq[0].toUpperCase() + rawFreq.substring(1);

        // Calculate next occurrence based on frequency
        final now = DateTime.now();
        DateTime next;
        switch (rawFreq) {
          case 'daily':
            next = DateTime(now.year, now.month, now.day + 1);
            break;
          case 'weekly':
            next = now.add(Duration(days: 7 - now.weekday % 7));
            break;
          case 'yearly':
            next = DateTime(now.year + 1, now.month, now.day);
            break;
          case 'monthly':
          default:
            next = DateTime(now.year, now.month + 1, now.day);
            break;
        }
        nextOccurrence = DateFormat('MMM d, yyyy').format(next);
      } catch (_) {
        // Keep defaults
      }
    }

    return _InfoCard(
      icon: FontAwesomeIcons.repeat,
      label: 'Recurring',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm + 2,
                  vertical: Spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: Radii.borderFull,
                ),
                child: Text(
                  frequency,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.clockRotateLeft,
                size: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                'Next: $nextOccurrence',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Split Section ───────────────────────────────────────────────────────────

class _SplitSection extends StatelessWidget {
  final String splitId;
  final WidgetRef ref;

  const _SplitSection({required this.splitId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final splitRepo = ref.watch(splitRepositoryProvider);
    final formatter = NumberFormat('#,##,###.##', 'en_IN');

    return FutureBuilder<SplitModel?>(
      future: splitRepo.getById(int.tryParse(splitId) ?? 0),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: Spacing.paddingMd,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final split = snapshot.data;
        if (split == null) {
          return _InfoCard(
            icon: FontAwesomeIcons.peopleLine,
            label: 'Split',
            child: Text(
              'Split details not available.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          );
        }

        return _InfoCard(
          icon: FontAwesomeIcons.peopleLine,
          label: 'Split - ${split.description}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Total: ${AppConstants.currencySymbol}'
                    '${formatter.format(split.totalAmount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: split.isFullySettled
                          ? cheddarColors.income.withOpacity(0.1)
                          : cheddarColors.expense.withOpacity(0.1),
                      borderRadius: Radii.borderFull,
                    ),
                    child: Text(
                      split.isFullySettled ? 'Settled' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: split.isFullySettled
                            ? cheddarColors.income
                            : cheddarColors.expense,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              const Divider(height: 1),
              const SizedBox(height: Spacing.sm),
              ...split.participants.map((participant) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.1,
                        ),
                        child: Text(
                          participant.name.isNotEmpty
                              ? participant.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          participant.name,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${AppConstants.currencySymbol}'
                        '${formatter.format(participant.amount)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Icon(
                        participant.isSettled
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: participant.isSettled
                            ? cheddarColors.income
                            : theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
