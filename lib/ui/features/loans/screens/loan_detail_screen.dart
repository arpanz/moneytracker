import 'dart:math' as math;

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
    final loan = await ref.read(loanRepositoryProvider).getById(widget.loanId);
    if (!mounted) return;
    setState(() {
      _loan = loan;
      _isLoading = false;
    });
  }

  Future<void> _showRepaymentSheet() async {
    final loan = _loan;
    if (loan == null) return;
    final symbol = ref.read(currencySymbolProvider);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (_) => _RepaymentSheet(loanId: loan.id, currencySymbol: symbol),
    );
    if (result == true) await _loadLoan();
  }

  Future<void> _showDisbursementSheet() async {
    final loan = _loan;
    if (loan == null) return;
    final symbol = ref.read(currencySymbolProvider);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (_) =>
          _DisbursementSheet(loanId: loan.id, currencySymbol: symbol),
    );
    if (result == true) await _loadLoan();
  }

  Future<void> _toggleClosed() async {
    final loan = _loan;
    if (loan == null) return;
    if (loan.isClosed) {
      await ref.read(loanRepositoryProvider).reopenLoan(loan.id);
    } else {
      await ref.read(loanRepositoryProvider).closeLoan(loan.id);
    }
    await _loadLoan();
  }

  Future<void> _deleteLoan() async {
    final ok = await showDialog<bool>(
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(loanRepositoryProvider).delete(widget.loanId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbol = ref.watch(currencySymbolProvider);
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

    final accent = loan.isClosed
        ? theme.colorScheme.outline
        : loan.type == 0
        ? Colors.green
        : theme.colorScheme.error;

    final breakdownMap = {
      for (final b in _buildDisbursementBreakdown(loan)) b.sourceIndex: b,
    };
    final timeline = loan.timeline.reversed.toList();

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
              if (value == 'add') _showDisbursementSheet();
              if (value == 'toggle') _toggleClosed();
              if (value == 'delete') _deleteLoan();
            },
            itemBuilder: (_) => [
              if (!loan.isClosed)
                PopupMenuItem(
                  value: 'add',
                  child: Text(
                    loan.type == 0
                        ? 'Add Lending Entry'
                        : 'Add Borrowing Entry',
                  ),
                ),
              PopupMenuItem(
                value: 'toggle',
                child: Text(loan.isClosed ? 'Reopen Loan' : 'Mark Closed'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete Loan')),
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
            Card(
              child: Padding(
                padding: Spacing.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$symbol ${loan.outstandingAmount.toStringAsFixed(0)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Paid ${loan.paidAmount.toStringAsFixed(0)} / ${loan.principalAmount.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Spacing.sm),
                    LinearProgressIndicator(value: loan.progress, minHeight: 6),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: AppDurations.medium),
            if (loan.isOverdue) ...[
              const SizedBox(height: Spacing.md),
              _InfoBanner(
                icon: Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                title:
                    'Overdue: $symbol ${loan.overdueAmount.toStringAsFixed(0)}',
                subtitle: 'Pending amount is past due date.',
              ),
            ],
            const SizedBox(height: Spacing.md),
            Text('Disbursement Ledger', style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            ...loan.disbursements.reversed.toList().asMap().entries.map((
              entry,
            ) {
              final sourceIndex = loan.disbursements.length - 1 - entry.key;
              final d = entry.value;
              final b = breakdownMap[sourceIndex];
              return Card(
                child: ListTile(
                  title: Text('$symbol ${d.amount.toStringAsFixed(0)}'),
                  subtitle: Text(
                    'Paid $symbol ${(b?.covered ?? 0).toStringAsFixed(0)} • '
                    'Open $symbol ${(b?.outstanding ?? d.amount).toStringAsFixed(0)}',
                  ),
                  trailing: Text(
                    d.dueDate == null ? 'No due' : _formatDate(d.dueDate!),
                  ),
                ),
              );
            }),
            const SizedBox(height: Spacing.md),
            Text('Ledger Timeline', style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            ...timeline.asMap().entries.map((entry) {
              final row = entry.value;
              final isDisbursement =
                  row.type == LoanLedgerEntryType.disbursement;
              return Card(
                    child: ListTile(
                      leading: Icon(
                        isDisbursement
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: accent,
                      ),
                      title: Text(
                        '${isDisbursement ? '+' : '-'}$symbol ${row.amount.toStringAsFixed(0)}',
                      ),
                      subtitle: Text(_formatDate(row.date)),
                      trailing: Text(
                        'Bal $symbol ${row.runningOutstanding.toStringAsFixed(0)}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  )
                  .animate(delay: Duration(milliseconds: entry.key * 50))
                  .fadeIn(duration: AppDurations.fast);
            }),
          ],
        ),
      ),
      floatingActionButton: loan.isClosed
          ? null
          : FloatingActionButton.extended(
              onPressed: _showRepaymentSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Repayment'),
            ),
    );
  }

  List<_DisbursementBreakdown> _buildDisbursementBreakdown(LoanModel loan) {
    final sorted = loan.disbursements.asMap().entries.toList()
      ..sort((a, b) => a.value.date.compareTo(b.value.date));
    var remaining = loan.paidAmount;
    final out = <_DisbursementBreakdown>[];
    for (final item in sorted) {
      final covered = math.min(remaining, item.value.amount);
      remaining = (remaining - covered).clamp(0.0, double.infinity);
      out.add(
        _DisbursementBreakdown(
          sourceIndex: item.key,
          covered: covered,
          outstanding: (item.value.amount - covered).clamp(
            0.0,
            item.value.amount,
          ),
        ),
      );
    }
    return out;
  }

  static String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }
}

class _DisbursementBreakdown {
  final int sourceIndex;
  final double covered;
  final double outstanding;

  const _DisbursementBreakdown({
    required this.sourceIndex,
    required this.covered,
    required this.outstanding,
  });
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
    return Container(
      padding: Spacing.paddingMd,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: Radii.borderMd,
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(title), Text(subtitle)],
            ),
          ),
        ],
      ),
    );
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
  DateTime _date = DateTime.now();
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
            date: _date,
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
        children: [
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
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18),
              const SizedBox(width: Spacing.sm),
              Text(_LoanDetailScreenState._formatDate(_date)),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 3650),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null && mounted) setState(() => _date = picked);
                },
                child: const Text('Change'),
              ),
            ],
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
        children: [
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
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 18),
              const SizedBox(width: Spacing.sm),
              Text(
                _dueDate == null
                    ? 'No due date'
                    : _LoanDetailScreenState._formatDate(_dueDate!),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
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
                child: const Text('Change'),
              ),
            ],
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
