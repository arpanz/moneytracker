import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/loan_model.dart';

class LoanDetailScreen extends ConsumerStatefulWidget {
  final int loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  @override
  ConsumerState<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends ConsumerState<LoanDetailScreen> {
  LoanModel? _loan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLoan();
  }

  Future<void> _loadLoan() async {
    final repo = ref.read(loanRepositoryProvider);
    final loan = await repo.getById(widget.loanId);
    if (!mounted) return;
    setState(() {
      _loan = loan;
      _isLoading = false;
    });
  }

  Future<void> _deleteLoan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Loan'),
        content: const Text('This ledger and all entries will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref.read(loanRepositoryProvider).delete(widget.loanId);
    if (mounted) context.pop();
  }

  Future<void> _toggleClosed() async {
    final loan = _loan;
    if (loan == null) return;
    final repo = ref.read(loanRepositoryProvider);
    if (loan.isClosed) {
      await repo.reopenLoan(loan.id);
    } else {
      await repo.closeLoan(loan.id);
    }
    await _loadLoan();
  }

  Future<void> _showAddRepaymentSheet() async {
    final loan = _loan;
    if (loan == null) return;
    final currencySymbol = ref.read(currencySymbolProvider);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (context) =>
          _RepaymentSheet(loanId: loan.id, currencySymbol: currencySymbol),
    );

    if (result == true) {
      await _loadLoan();
    }
  }

  Future<void> _showAddDisbursementSheet() async {
    final loan = _loan;
    if (loan == null) return;
    final currencySymbol = ref.read(currencySymbolProvider);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (context) =>
          _DisbursementSheet(loanId: loan.id, currencySymbol: currencySymbol),
    );

    if (result == true) {
      await _loadLoan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final loan = _loan;
    if (loan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Loan not found')),
      );
    }

    final isLending = loan.type == 0;
    final accent = loan.isClosed
        ? theme.colorScheme.outline
        : isLending
        ? Colors.green
        : theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.personName),
        actions: [
          IconButton(
            onPressed: () async {
              await context.pushNamed(RouteNames.addLoan, extra: loan);
              _loadLoan();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'disburse') {
                _showAddDisbursementSheet();
              } else if (value == 'toggle') {
                _toggleClosed();
              } else if (value == 'delete') {
                _deleteLoan();
              }
            },
            itemBuilder: (context) => [
              if (!loan.isClosed)
                PopupMenuItem<String>(
                  value: 'disburse',
                  child: Text(
                    loan.type == 0
                        ? 'Add Lending Entry'
                        : 'Add Borrowing Entry',
                  ),
                ),
              PopupMenuItem<String>(
                value: 'toggle',
                child: Text(loan.isClosed ? 'Reopen Loan' : 'Mark Closed'),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete Loan'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLoan,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.md,
            Spacing.md,
            96,
          ),
          children: [
            _LoanHeaderCard(
              loan: loan,
              accent: accent,
              currencySymbol: currencySymbol,
            ).animate().fadeIn(duration: AppDurations.medium),
            const SizedBox(height: Spacing.md),
            if (loan.isOverdue)
              _InfoBanner(
                icon: Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                title:
                    'Overdue amount: $currencySymbol ${loan.overdueAmount.toStringAsFixed(0)}',
                subtitle: loan.type == 0
                    ? 'Follow up to collect pending amount.'
                    : 'Pay pending amount to close the overdue.',
              ),
            if (loan.isOverdue) const SizedBox(height: Spacing.md),
            _LoanMetaCard(loan: loan),
            const SizedBox(height: Spacing.md),
            Text(
              'Disbursement Ledger',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            if (loan.disbursements.isEmpty)
              _InfoBanner(
                icon: Icons.account_balance_wallet_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                title: 'No disbursements',
                subtitle: 'Entries will appear when money is added.',
              )
            else
              ...loan.disbursements.reversed.toList().asMap().entries.map((
                entry,
              ) {
                final disbursement = entry.value;
                return Card(
                      margin: const EdgeInsets.only(bottom: Spacing.sm),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: accent.withValues(alpha: 0.12),
                          child: Icon(
                            loan.type == 0
                                ? Icons.call_received_rounded
                                : Icons.call_made_rounded,
                            color: accent,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '$currencySymbol ${disbursement.amount.toStringAsFixed(0)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          disbursement.note?.trim().isNotEmpty == true
                              ? disbursement.note!
                              : 'Added on ${_formatDate(disbursement.date)}',
                        ),
                        trailing: Text(
                          disbursement.dueDate == null
                              ? 'No due'
                              : 'Due ${_formatDate(disbursement.dueDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                    .animate(delay: Duration(milliseconds: entry.key * 60))
                    .fadeIn(duration: AppDurations.fast)
                    .slideX(begin: 0.05, end: 0);
              }),
            const SizedBox(height: Spacing.md),
            Text(
              'Repayment History',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            if (loan.repayments.isEmpty)
              _InfoBanner(
                icon: Icons.history_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                title: 'No repayments yet',
                subtitle: 'Use "Add Repayment" to record payments.',
              )
            else
              ...loan.repayments.reversed.toList().asMap().entries.map((entry) {
                final repayment = entry.value;
                return Card(
                      margin: const EdgeInsets.only(bottom: Spacing.sm),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: accent.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.check_rounded,
                            color: accent,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '$currencySymbol ${repayment.amount.toStringAsFixed(0)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          repayment.note?.trim().isNotEmpty == true
                              ? repayment.note!
                              : _formatDate(repayment.date),
                        ),
                        trailing: Text(
                          _formatDate(repayment.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                    .animate(delay: Duration(milliseconds: entry.key * 60))
                    .fadeIn(duration: AppDurations.fast)
                    .slideX(begin: 0.05, end: 0);
              }),
          ],
        ),
      ),
      floatingActionButton: loan.isClosed
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddRepaymentSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Repayment'),
            ),
    );
  }

  static String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }
}

class _RepaymentSheet extends ConsumerStatefulWidget {
  final int loanId;
  final String currencySymbol;

  const _RepaymentSheet({required this.loanId, required this.currencySymbol});

  @override
  ConsumerState<_RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends ConsumerState<_RepaymentSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(loanRepositoryProvider)
          .addRepayment(
            widget.loanId,
            amount,
            date: _selectedDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save repayment: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.md,
        MediaQuery.of(context).viewInsets.bottom + Spacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: Radii.borderFull,
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Record Repayment',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${widget.currencySymbol} ',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            autofocus: true,
          ),
          const SizedBox(height: Spacing.md),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null && mounted) {
                setState(() => _selectedDate = picked);
              }
            },
            borderRadius: Radii.borderMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: Radii.borderMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(_LoanDetailScreenState._formatDate(_selectedDate)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: Spacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Repayment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisbursementSheet extends ConsumerStatefulWidget {
  final int loanId;
  final String currencySymbol;

  const _DisbursementSheet({
    required this.loanId,
    required this.currencySymbol,
  });

  @override
  ConsumerState<_DisbursementSheet> createState() => _DisbursementSheetState();
}

class _DisbursementSheetState extends ConsumerState<_DisbursementSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(loanRepositoryProvider)
          .addDisbursement(
            widget.loanId,
            amount,
            dueDate: _dueDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add entry: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.md,
        MediaQuery.of(context).viewInsets.bottom + Spacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: Radii.borderFull,
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Add New Entry',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${widget.currencySymbol} ',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            autofocus: true,
          ),
          const SizedBox(height: Spacing.md),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 20),
              );
              if (picked != null && mounted) {
                setState(() => _dueDate = picked);
              }
            },
            borderRadius: Radii.borderMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: Radii.borderMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      _dueDate == null
                          ? 'No due date'
                          : _LoanDetailScreenState._formatDate(_dueDate!),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      onPressed: () => setState(() => _dueDate = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Entry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanHeaderCard extends StatelessWidget {
  final LoanModel loan;
  final Color accent;
  final String currencySymbol;

  const _LoanHeaderCard({
    required this.loan,
    required this.accent,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLending = loan.type == 0;

    return Card(
      child: Padding(
        padding: Spacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: Radii.borderFull,
                  ),
                  child: Text(
                    loan.isClosed
                        ? 'Closed'
                        : (isLending ? 'Lending' : 'Borrowing'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  loan.title?.trim().isNotEmpty == true
                      ? loan.title!
                      : 'Untitled',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text(
              '$currencySymbol ${loan.outstandingAmount.toStringAsFixed(0)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Outstanding amount',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.md),
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
                  '${(loan.progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanMetaCard extends StatelessWidget {
  final LoanModel loan;

  const _LoanMetaCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: Spacing.paddingMd,
        child: Column(
          children: [
            _MetaRow(
              label: 'Type',
              value: loan.type == 0 ? 'Lending' : 'Borrowing',
            ),
            const SizedBox(height: Spacing.sm),
            _MetaRow(
              label: 'Next due',
              value: loan.nextDueDate == null
                  ? 'Not set'
                  : _LoanDetailScreenState._formatDate(loan.nextDueDate!),
            ),
            const SizedBox(height: Spacing.sm),
            _MetaRow(
              label: 'Entries',
              value: '${loan.disbursements.length} disbursement(s)',
            ),
            const SizedBox(height: Spacing.sm),
            _MetaRow(
              label: 'Interest',
              value: loan.interestRate == null
                  ? 'Not set'
                  : '${loan.interestRate!.toStringAsFixed(2)}%',
            ),
            if ((loan.note ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      'Notes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(loan.note!, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: Spacing.paddingMd,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: Radii.borderMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
