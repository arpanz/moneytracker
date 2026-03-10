import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/subscription_model.dart';

/// Add or edit a recurring subscription with name, amount, frequency,
/// next bill date, category, and notes.
class AddSubscriptionScreen extends ConsumerStatefulWidget {
  final SubscriptionModel? existingSubscription;

  const AddSubscriptionScreen({super.key, this.existingSubscription});

  @override
  ConsumerState<AddSubscriptionScreen> createState() =>
      _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  int _frequency = 1; // 0=weekly, 1=monthly, 2=quarterly, 3=yearly
  DateTime _nextBillDate = DateTime.now().add(const Duration(days: 30));
  String _category = 'Subscriptions';
  bool _isSaving = false;

  bool get _isEditing => widget.existingSubscription != null;

  static const _frequencyOptions = [
    {'value': 0, 'label': 'Weekly'},
    {'value': 1, 'label': 'Monthly'},
    {'value': 2, 'label': 'Quarterly'},
    {'value': 3, 'label': 'Yearly'},
  ];

  static const _categoryOptions = [
    'Subscriptions',
    'Entertainment',
    'Bills',
    'Health',
    'Education',
    'Shopping',
    'Food',
    'Transport',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final s = widget.existingSubscription!;
      _nameController.text = s.name;
      _amountController.text = s.amount.toStringAsFixed(0);
      _notesController.text = s.notes ?? '';
      _frequency = s.frequency;
      _nextBillDate = s.nextBillDate;
      _category = s.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickNextBillDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBillDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() => _nextBillDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final subRepo = ref.read(subscriptionRepositoryProvider);
      final amount =
          double.parse(_amountController.text.replaceAll(',', '').trim());

      if (_isEditing) {
        final sub = widget.existingSubscription!
          ..name = _nameController.text.trim()
          ..amount = amount
          ..frequency = _frequency
          ..nextBillDate = _nextBillDate
          ..category = _category
          ..notes = _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null;
        await subRepo.update(sub);
      } else {
        final sub = SubscriptionModel()
          ..name = _nameController.text.trim()
          ..amount = amount
          ..frequency = _frequency
          ..nextBillDate = _nextBillDate
          ..category = _category
          ..notes = _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null
          ..isActive = true
          ..isAutoDetected = false
          ..createdAt = DateTime.now();
        await subRepo.add(sub);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving subscription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Subscription' : 'New Subscription'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Subscription Name',
                hintText: 'e.g. Netflix, Spotify, Gym',
                prefixIcon: Icon(Icons.subscriptions_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: Spacing.lg),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'Rs. ',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter an amount';
                final amt = double.tryParse(v.replaceAll(',', ''));
                if (amt == null || amt <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: Spacing.lg),

            // Frequency picker
            Text('Frequency',
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: 8,
              children: _frequencyOptions.map((opt) {
                final value = opt['value'] as int;
                final label = opt['label'] as String;
                final isSelected = _frequency == value;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _frequency = value),
                );
              }).toList(),
            ),
            const SizedBox(height: Spacing.lg),

            // Next bill date
            Text('Next Bill Date',
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.sm),
            InkWell(
              onTap: _pickNextBillDate,
              borderRadius: Radii.borderMd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: Radii.borderMd,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      '${_nextBillDate.day}/${_nextBillDate.month}/${_nextBillDate.year}',
                      style: textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // Category dropdown
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _categoryOptions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: Spacing.lg),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any additional details...',
                prefixIcon: Icon(Icons.note_outlined),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: Radii.borderMd,
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isEditing ? 'Update' : 'Add Subscription'),
          ),
        ),
      ),
    );
  }
}
