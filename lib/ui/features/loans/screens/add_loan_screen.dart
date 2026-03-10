import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/loan_model.dart';

class AddLoanScreen extends ConsumerStatefulWidget {
  final LoanModel? existingLoan;

  const AddLoanScreen({super.key, this.existingLoan});

  @override
  ConsumerState<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends ConsumerState<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personController = TextEditingController();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestController = TextEditingController();
  final _noteController = TextEditingController();

  int _type = 0;
  DateTime? _dueDate;
  bool _isSaving = false;

  bool get _isEditing => widget.existingLoan != null;

  @override
  void initState() {
    super.initState();
    final loan = widget.existingLoan;
    if (loan != null) {
      _type = loan.type;
      _personController.text = loan.personName;
      _titleController.text = loan.title ?? '';
      _amountController.text = loan.principalAmount.toStringAsFixed(0);
      _interestController.text = loan.interestRate?.toStringAsFixed(2) ?? '';
      _noteController.text = loan.note ?? '';
      _dueDate = loan.dueDate;
    }
  }

  @override
  void dispose() {
    _personController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final principal = double.parse(_amountController.text.trim());
    final interestRate = _interestController.text.trim().isEmpty
        ? null
        : double.parse(_interestController.text.trim());
    final existing = widget.existingLoan;
    final title = _titleController.text.trim();
    final notes = _noteController.text.trim();
    final entryNote = title.isNotEmpty
        ? title
        : (notes.isNotEmpty ? notes : null);

    if (existing != null && principal < existing.paidAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Principal cannot be less than already paid amount '
            '(${existing.paidAmount.toStringAsFixed(0)}).',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(loanRepositoryProvider);

      if (existing != null) {
        existing
          ..type = _type
          ..personName = _personController.text.trim()
          ..title = _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim()
          ..principalAmount = existing.principalAmount
          ..interestRate = interestRate
          ..dueDate = _dueDate
          ..note = _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim();

        if (existing.paidAmount >= existing.principalAmount) {
          existing
            ..paidAmount = existing.principalAmount
            ..isClosed = true;
        } else if (existing.isClosed) {
          existing.isClosed = false;
        }

        await repo.update(existing);
      } else {
        final personName = _personController.text.trim();
        final activeLedger = await repo.findActiveLedger(personName, _type);
        if (activeLedger != null && mounted) {
          final appendToExisting = await _showLedgerMergeDialog(
            existingLoan: activeLedger,
            amount: principal,
            currencySymbol: ref.read(currencySymbolProvider),
          );
          if (appendToExisting == null) {
            if (mounted) setState(() => _isSaving = false);
            return;
          }

          if (appendToExisting) {
            await repo.addDisbursement(
              activeLedger.id,
              principal,
              dueDate: _dueDate,
              note: entryNote,
            );
            if (mounted) context.pop();
            return;
          }
        }

        final now = DateTime.now();
        final loan = LoanModel()
          ..type = _type
          ..personName = personName
          ..title = title.isEmpty ? null : title
          ..principalAmount = principal
          ..interestRate = interestRate
          ..dueDate = _dueDate
          ..note = notes.isEmpty ? null : notes
          ..disbursements = [
            LoanDisbursement()
              ..amount = principal
              ..date = now
              ..dueDate = _dueDate
              ..note = entryNote,
          ]
          ..createdAt = now
          ..updatedAt = now;

        await repo.add(loan);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save loan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool?> _showLedgerMergeDialog({
    required LoanModel existingLoan,
    required double amount,
    required String currencySymbol,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Existing Ledger Found'),
          content: Text(
            'An active ${_type == 0 ? 'lending' : 'borrowing'} ledger already '
            'exists for ${existingLoan.personName}.\n\n'
            'Add $currencySymbol ${amount.toStringAsFixed(0)} to this existing '
            'ledger?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Create Separate'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: const Text('Add To Existing'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final typeLabel = _type == 0 ? 'Lending' : 'Borrowing';

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Loan' : 'Add Loan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.md,
            Spacing.md,
            96,
          ),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  label: Text('Lending'),
                  icon: Icon(Icons.call_received_rounded),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text('Borrowing'),
                  icon: Icon(Icons.call_made_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
            const SizedBox(height: Spacing.md),
            Text(
              '$typeLabel details',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _personController,
              decoration: InputDecoration(
                labelText: _type == 0 ? 'Borrower name' : 'Lender name',
                hintText: 'e.g. Rahul Sharma',
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'e.g. Emergency cash, Bike repair',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Principal amount',
                prefixText: '$currencySymbol ',
                prefixIcon: const Icon(Icons.payments_outlined),
                helperText: _isEditing
                    ? 'Use "Add Entry" on detail screen to increase amount.'
                    : null,
              ),
              readOnly: _isEditing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter amount';
                }
                final amount = double.tryParse(value.trim());
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _interestController,
              decoration: const InputDecoration(
                labelText: 'Annual interest % (optional)',
                hintText: 'e.g. 12',
                suffixText: '%',
                prefixIcon: Icon(Icons.percent_rounded),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }
                final rate = double.tryParse(value.trim());
                if (rate == null || rate < 0 || rate > 100) {
                  return 'Enter a valid percentage (0-100)';
                }
                return null;
              },
            ),
            const SizedBox(height: Spacing.md),
            InkWell(
              onTap: _pickDueDate,
              borderRadius: Radii.borderMd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: Radii.borderMd,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        _dueDate == null
                            ? 'No due date'
                            : _formatDate(_dueDate!),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _dueDate == null
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ),
                    if (_dueDate != null)
                      IconButton(
                        onPressed: () => setState(() => _dueDate = null),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Anything important about this loan',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.md,
            Spacing.md,
          ),
          child: FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? 'Update Loan' : 'Create Loan'),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }
}
