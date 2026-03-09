import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/split_model.dart';

/// Screen to create a new split expense.
class AddSplitScreen extends ConsumerStatefulWidget {
  const AddSplitScreen({super.key});

  @override
  ConsumerState<AddSplitScreen> createState() => _AddSplitScreenState();
}

class _AddSplitScreenState extends ConsumerState<AddSplitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _totalAmountController = TextEditingController();

  int _splitMethod = 0; // 0=equal, 1=exact, 2=percentage
  final List<_ParticipantEntry> _participants = [
    _ParticipantEntry(),
    _ParticipantEntry(),
  ];
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _totalAmountController.dispose();
    for (final p in _participants) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Split'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // ── Description ──
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Dinner at Olive Garden',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Total Amount ──
            TextFormField(
              controller: _totalAmountController,
              decoration: const InputDecoration(
                labelText: 'Total Amount',
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              onChanged: (_) => _recalculateShares(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final amount = double.tryParse(v);
                if (amount == null || amount <= 0) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Split Method ──
            Text('Split Method', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Equal'), icon: Icon(Icons.drag_handle_rounded)),
                ButtonSegment(value: 1, label: Text('Exact'), icon: Icon(Icons.pin_rounded)),
                ButtonSegment(value: 2, label: Text('Percent'), icon: Icon(Icons.percent_rounded)),
              ],
              selected: {_splitMethod},
              onSelectionChanged: (s) {
                setState(() => _splitMethod = s.first);
                _recalculateShares();
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Participants ──
            Row(
              children: [
                Expanded(
                  child: Text('Participants',
                      style: theme.textTheme.titleSmall),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _participants.add(_ParticipantEntry()));
                    _recalculateShares();
                  },
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            ...List.generate(_participants.length, (index) {
              final p = _participants[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: colors.primaryContainer,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                  color: colors.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextFormField(
                              controller: p.nameController,
                              decoration: InputDecoration(
                                labelText: 'Name',
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Person ${index + 1}',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Name required'
                                  : null,
                            ),
                          ),
                          if (_participants.length > 2)
                            IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: colors.error, size: 20),
                              onPressed: () {
                                setState(() {
                                  _participants[index].dispose();
                                  _participants.removeAt(index);
                                });
                                _recalculateShares();
                              },
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 44), // align with name
                          Expanded(
                            child: TextFormField(
                              controller: p.contactController,
                              decoration: const InputDecoration(
                                labelText: 'Contact (optional)',
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Phone or email',
                              ),
                            ),
                          ),
                          if (_splitMethod != 0) // show amount for exact/pct
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                controller: p.amountController,
                                decoration: InputDecoration(
                                  labelText:
                                      _splitMethod == 2 ? '%' : 'Amount',
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[\d.]')),
                                ],
                                textAlign: TextAlign.end,
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(
                                  right: AppSpacing.md),
                              child: Text(
                                _equalShare(),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            // ── Validation summary ──
            if (_splitMethod == 2) _PercentageValidator(participants: _participants),
          ],
        ),
      ),
    );
  }

  String _equalShare() {
    final total = double.tryParse(_totalAmountController.text) ?? 0;
    if (_participants.isEmpty || total <= 0) return '\$0.00';
    final share = total / _participants.length;
    return '\$${share.toStringAsFixed(2)}';
  }

  void _recalculateShares() {
    if (_splitMethod != 0) return; // only auto-calc for equal
    setState(() {}); // trigger rebuild to update equal share display
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final total = double.parse(_totalAmountController.text);
    final participants = <SplitParticipant>[];

    for (int i = 0; i < _participants.length; i++) {
      final p = _participants[i];
      final participant = SplitParticipant()
        ..name = p.nameController.text.trim()
        ..contact = p.contactController.text.trim().isNotEmpty
            ? p.contactController.text.trim()
            : null
        ..isSettled = false;

      switch (_splitMethod) {
        case 0: // equal
          participant.amount = total / _participants.length;
          participant.percentage = 100.0 / _participants.length;
          break;
        case 1: // exact
          participant.amount =
              double.tryParse(p.amountController.text) ?? 0;
          participant.percentage =
              total > 0 ? (participant.amount / total * 100) : 0;
          break;
        case 2: // percentage
          final pct = double.tryParse(p.amountController.text) ?? 0;
          participant.percentage = pct;
          participant.amount = total * pct / 100;
          break;
      }

      participants.add(participant);
    }

    setState(() => _isSaving = true);

    try {
      final split = SplitModel()
        ..description = _descriptionController.text.trim()
        ..totalAmount = total
        ..splitMethod = _splitMethod
        ..participants = participants
        ..isFullySettled = false
        ..createdAt = DateTime.now();

      final repo = ref.read(splitRepositoryProvider);
      await repo.add(split);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Split created!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── Participant Entry Helper ────────────────────────────────────────────────

class _ParticipantEntry {
  final nameController = TextEditingController();
  final contactController = TextEditingController();
  final amountController = TextEditingController();

  void dispose() {
    nameController.dispose();
    contactController.dispose();
    amountController.dispose();
  }
}

// ── Percentage Validation Widget ────────────────────────────────────────────

class _PercentageValidator extends StatelessWidget {
  final List<_ParticipantEntry> participants;
  const _PercentageValidator({required this.participants});

  @override
  Widget build(BuildContext context) {
    double totalPct = 0;
    for (final p in participants) {
      totalPct += double.tryParse(p.amountController.text) ?? 0;
    }

    final isValid = (totalPct - 100).abs() < 0.01;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: isValid ? Colors.green : theme.colorScheme.error,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Total: ${totalPct.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isValid ? Colors.green : theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!isValid)
            Text(
              ' (must be 100%)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
