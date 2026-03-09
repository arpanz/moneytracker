import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/account_model.dart';

/// Screen to add or edit a financial account.
class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  int _type = 0;
  bool _isSaving = false;

  static const _types = [
    {'label': 'Bank Account', 'icon': Icons.account_balance_rounded, 'value': 0},
    {'label': 'Digital Wallet', 'icon': Icons.account_balance_wallet_rounded, 'value': 1},
    {'label': 'Credit Card', 'icon': Icons.credit_card_rounded, 'value': 2},
    {'label': 'Cash', 'icon': Icons.money_rounded, 'value': 3},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Account'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Account type picker
            Text('Account Type', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _types.map((t) {
                final value = t['value'] as int;
                final isSelected = _type == value;
                return ChoiceChip(
                  avatar: Icon(t['icon'] as IconData, size: 18,
                      color: isSelected ? colors.onPrimary : colors.onSurfaceVariant),
                  label: Text(t['label'] as String),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _type = value),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name',
                hintText: 'e.g. HDFC Savings',
                prefixIcon: Icon(Icons.label_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Opening balance
            TextFormField(
              controller: _balanceController,
              decoration: const InputDecoration(
                labelText: 'Opening Balance',
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Info text
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: colors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Transactions will automatically update this account\'s balance.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final account = AccountModel()
        ..name = _nameController.text.trim()
        ..accountType = _type
        ..balance = double.parse(_balanceController.text)
        ..createdAt = DateTime.now();

      final repo = ref.read(accountRepositoryProvider);
      await repo.add(account);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account added!')),
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
