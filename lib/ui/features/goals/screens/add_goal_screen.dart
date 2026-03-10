import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/goal_model.dart';

/// Create or edit a savings goal with name, target, deadline, icon, and color.
class AddGoalScreen extends ConsumerStatefulWidget {
  final GoalModel? existingGoal;

  const AddGoalScreen({super.key, this.existingGoal});

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime? _deadline;
  String _selectedIcon = 'piggy-bank';
  int _selectedColor = 0xFF7C3AED;
  String? _linkedAccountId;
  bool _isSaving = false;

  bool get _isEditing => widget.existingGoal != null;

  static const _iconOptions = <String, FaIconData>{
    'piggy-bank': FontAwesomeIcons.piggyBank,
    'star': FontAwesomeIcons.star,
    'car': FontAwesomeIcons.car,
    'plane': FontAwesomeIcons.plane,
    'house': FontAwesomeIcons.house,
    'phone': FontAwesomeIcons.mobileScreen,
    'graduation-cap': FontAwesomeIcons.graduationCap,
    'gift': FontAwesomeIcons.gift,
    'heart': FontAwesomeIcons.heart,
    'gamepad': FontAwesomeIcons.gamepad,
    'laptop': FontAwesomeIcons.laptop,
    'ring': FontAwesomeIcons.ring,
    'camera': FontAwesomeIcons.camera,
    'bicycle': FontAwesomeIcons.bicycle,
    'umbrella-beach': FontAwesomeIcons.umbrellaBeach,
    'mountain-sun': FontAwesomeIcons.mountainSun,
  };

  static const _colorOptions = [
    0xFF7C3AED,
    0xFFEC4899,
    0xFFFF6B6B,
    0xFFF59E0B,
    0xFF22C55E,
    0xFF0D9488,
    0xFF3B82F6,
    0xFF6366F1,
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final g = widget.existingGoal!;
      _nameController.text = g.name;
      _amountController.text = g.targetAmount.toStringAsFixed(0);
      _deadline = g.deadline;
      _selectedIcon = g.icon;
      _selectedColor = g.color;
      _linkedAccountId = g.linkedAccountId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final goalRepo = ref.read(goalRepositoryProvider);
      final amount = double.parse(
        _amountController.text.replaceAll(',', '').trim(),
      );

      if (_isEditing) {
        final goal = widget.existingGoal!
          ..name = _nameController.text.trim()
          ..targetAmount = amount
          ..deadline = _deadline
          ..icon = _selectedIcon
          ..color = _selectedColor
          ..linkedAccountId = _linkedAccountId;
        await goalRepo.update(goal);
      } else {
        final goal = GoalModel()
          ..name = _nameController.text.trim()
          ..targetAmount = amount
          ..deadline = _deadline
          ..icon = _selectedIcon
          ..color = _selectedColor
          ..linkedAccountId = _linkedAccountId
          ..createdAt = DateTime.now();
        await goalRepo.add(goal);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving goal: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // FIX #16: runtime currency symbol
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Goal' : 'New Goal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Goal Name',
                hintText: 'e.g. New MacBook, Europe Trip',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a goal name' : null,
            ),
            const SizedBox(height: Spacing.lg),

            Text(
              'Target Amount',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            TextFormField(
              controller: _amountController,
              // FIX #16: runtime currency symbol as prefix
              decoration: InputDecoration(
                prefixText: '$currencySymbol ',
                hintText: '50,000',
                prefixIcon: const Icon(Icons.savings_outlined),
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

            Text(
              'Deadline (Optional)',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            InkWell(
              onTap: _pickDeadline,
              borderRadius: Radii.borderMd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: Radii.borderMd,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _deadline != null
                          ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'
                          : 'No deadline set',
                      style: textTheme.bodyLarge?.copyWith(
                        color: _deadline != null
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (_deadline != null)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => setState(() => _deadline = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),

            Text(
              'Icon',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _iconOptions.entries.map((entry) {
                final isSelected = entry.key == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = entry.key),
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      // FIX: withOpacity → withValues
                      color: isSelected
                          ? Color(_selectedColor).withValues(alpha: 0.15)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: Radii.borderMd,
                      border: isSelected
                          ? Border.all(color: Color(_selectedColor), width: 2)
                          : null,
                    ),
                    child: Center(
                      child: FaIcon(
                        entry.value,
                        size: 20,
                        color: isSelected
                            ? Color(_selectedColor)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: Spacing.lg),

            Text(
              'Color',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Row(
              children: _colorOptions.map((colorVal) {
                final isSelected = colorVal == _selectedColor;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorVal),
                    child: AnimatedContainer(
                      duration: AppDurations.fast,
                      width: isSelected ? 40 : 36,
                      height: isSelected ? 40 : 36,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  // FIX: withOpacity → withValues
                                  color: Color(colorVal).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: Spacing.lg),

            FutureBuilder(
              future: ref.read(accountRepositoryProvider).getActive(),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? [];
                if (accounts.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link to Account (Optional)',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    DropdownButtonFormField<String?>(
                      value: _linkedAccountId,
                      decoration: const InputDecoration(
                        hintText: 'Select an account',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...accounts.map(
                          (a) => DropdownMenuItem(
                            value: '${a.id}',
                            child: Text(a.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _linkedAccountId = v),
                    ),
                  ],
                );
              },
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
                : Text(_isEditing ? 'Update Goal' : 'Create Goal'),
          ),
        ),
      ),
    );
  }
}
