import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/loan_model.dart';
import '../providers/loan_providers.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(loanSummaryProvider);
    final lendings = ref.watch(lendingLoansProvider);
    final borrowings = ref.watch(borrowingLoansProvider);
    final overdue = ref.watch(overdueLoansProvider);
    final closed = ref.watch(closedLoansProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans'),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed(RouteNames.addLoan),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Lendings (${lendings.length})'),
            Tab(text: 'Borrowings (${borrowings.length})'),
            Tab(text: 'Overdue (${overdue.length})'),
            Tab(text: 'Closed (${closed.length})'),
          ],
          isScrollable: true,
        ),
      ),
      body: Column(
        children: [
          _LoanSummaryCard(
            summary: summary,
            currencySymbol: currencySymbol,
          ).animate().fadeIn(duration: AppDurations.medium),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _LoanListTab(
                  loans: lendings,
                  emptyTitle: 'No lendings yet',
                  emptySubtitle: 'Track money you gave to others.',
                  currencySymbol: currencySymbol,
                ),
                _LoanListTab(
                  loans: borrowings,
                  emptyTitle: 'No borrowings yet',
                  emptySubtitle: 'Track money you borrowed.',
                  currencySymbol: currencySymbol,
                ),
                _LoanListTab(
                  loans: overdue,
                  emptyTitle: 'No overdue loans',
                  emptySubtitle: 'Everything is on schedule.',
                  currencySymbol: currencySymbol,
                ),
                _LoanListTab(
                  loans: closed,
                  emptyTitle: 'No closed loans yet',
                  emptySubtitle: 'Closed loans will appear here.',
                  currencySymbol: currencySymbol,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.addLoan),
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: const Text('Add Loan'),
      ),
    );
  }
}

class _LoanSummaryCard extends StatelessWidget {
  final LoanSummary summary;
  final String currencySymbol;

  const _LoanSummaryCard({required this.summary, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, 0),
      child: Padding(
        padding: Spacing.paddingMd,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Receivable',
                    value:
                        '$currencySymbol ${_formatAmount(summary.receivable)}',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Payable',
                    value: '$currencySymbol ${_formatAmount(summary.payable)}',
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Net',
                    value:
                        '$currencySymbol ${_formatAmount(summary.netPosition.abs())}',
                    color: summary.netPosition >= 0
                        ? Colors.green
                        : theme.colorScheme.error,
                    prefix: summary.netPosition >= 0 ? '+' : '-',
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Overdue',
                    value: '${summary.overdueLoans}',
                    color: summary.overdueLoans > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatAmount(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    }
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String prefix;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          '$prefix$value',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LoanListTab extends StatelessWidget {
  final List<LoanModel> loans;
  final String emptyTitle;
  final String emptySubtitle;
  final String currencySymbol;

  const _LoanListTab({
    required this.loans,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return _LoanEmptyState(title: emptyTitle, subtitle: emptySubtitle);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.md,
        96,
      ),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        return _LoanCard(loan: loan, currencySymbol: currencySymbol)
            .animate(delay: Duration(milliseconds: index * 50))
            .fadeIn(duration: AppDurations.medium)
            .slideX(begin: 0.05, end: 0);
      },
    );
  }
}

class _LoanCard extends StatelessWidget {
  final LoanModel loan;
  final String currencySymbol;

  const _LoanCard({required this.loan, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLending = loan.type == 0;
    final accent = loan.isClosed
        ? theme.colorScheme.outline
        : isLending
        ? Colors.green
        : theme.colorScheme.error;

    final dueLabel = _dueLabel(loan);

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: InkWell(
        borderRadius: Radii.borderMd,
        onTap: () => context.pushNamed(
          RouteNames.loanDetail,
          pathParameters: {'id': '${loan.id}'},
        ),
        child: Padding(
          padding: Spacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accent.withValues(alpha: 0.12),
                    child: Icon(
                      isLending
                          ? Icons.call_received_rounded
                          : Icons.call_made_rounded,
                      color: accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.personName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((loan.title ?? '').trim().isNotEmpty)
                          Text(
                            loan.title!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: Radii.borderFull,
                    ),
                    child: Text(
                      loan.isClosed
                          ? 'Closed'
                          : (isLending ? 'Lending' : 'Borrowing'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Outstanding',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '$currencySymbol ${loan.outstandingAmount.toStringAsFixed(0)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              ClipRRect(
                borderRadius: Radii.borderSm,
                child: LinearProgressIndicator(
                  value: loan.progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Text(
                    'Paid ${loan.paidAmount.toStringAsFixed(0)} / ${loan.principalAmount.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dueLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: loan.isOverdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: loan.isOverdue ? FontWeight.w600 : null,
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

  static String _dueLabel(LoanModel loan) {
    if (loan.dueDate == null) return 'No due date';
    final due = loan.dueDate!;
    final now = DateTime.now();
    final delta = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    if (loan.isClosed) {
      return 'Closed';
    }
    if (delta < 0) return 'Overdue by ${delta.abs()}d';
    if (delta == 0) return 'Due today';
    if (delta == 1) return 'Due tomorrow';
    return 'Due in $delta days';
  }
}

class _LoanEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _LoanEmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: Spacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
