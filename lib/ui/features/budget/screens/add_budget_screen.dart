import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../../../../domain/models/budget_model.dart';
import '../../../../domain/models/category_model.dart';
import '../providers/budget_providers.dart';
import '../../transactions/widgets/amount_input_widget.dart';

/// Screen for creating or editing a budget.
///
/// Pass an existing [BudgetModel] via GoRouter `extra` to enter edit mode.
class AddBudgetScreen extends ConsumerStatefulWidget {
  final BudgetModel? existingBudget;

  const AddBudgetScreen({super.key, this.existingBudget});

  @override
  ConsumerState<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends ConsumerState<AddBudgetScreen> {
  double _amount = 0.0;
  String? _selectedCategory;
  int _period = 1;
  DateTime _startDate = DateTime.now();
  bool _isSaving = false;
  int _currentStep = 0;

  bool get _isEditing => widget.existingBudget != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final budget = widget.existingBudget!;
      _selectedCategory = budget.category;
      _amount = budget.limitAmount;
      _period = budget.period;
      _startDate = budget.startDate;
      _currentStep = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Budget' : 'New Budget'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(theme),
          const SizedBox(height: Spacing.md),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _buildCurrentStep(),
            ),
          ),
          _buildBottomAction(theme),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    final labels = ['Category', 'Amount', 'Period'];
    return Padding(
      padding: Spacing.horizontalMd,
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == _currentStep;
          final isCompleted = i < _currentStep;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted || isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive || isCompleted
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: theme.colorScheme.onPrimary,
                              )
                            : Text(
                                '${i + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isActive
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.5,
                                        ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    if (i < 2)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  labels[i],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _CategoryPickerStep(
          key: const ValueKey('category_step'),
          selectedCategory: _selectedCategory,
          onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
        );
      case 1:
        // FIX: _AmountStep is now a StatefulWidget. The parent wires up
        // onAmountChanged to update _amount AND rebuild via setState so
        // _canProceed() reads the correct non-zero value immediately.
        return _AmountStep(
          key: const ValueKey('amount_step'),
          initialAmount: _amount,
          onAmountChanged: (amount) => setState(() => _amount = amount),
        );
      case 2:
        return _PeriodStep(
          key: const ValueKey('period_step'),
          period: _period,
          startDate: _startDate,
          onPeriodChanged: (p) => setState(() => _period = p),
          onDateChanged: (d) => setState(() => _startDate = d),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomAction(ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: Spacing.md),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _canProceed() ? _onNext : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_currentStep == 2 ? 'Save Budget' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceed() {
    if (_isSaving) return false;
    switch (_currentStep) {
      case 0:
        return _selectedCategory != null;
      case 1:
        // FIX: _amount is now updated via setState in _buildCurrentStep so
        // this guard correctly reflects the typed value.
        return _amount > 0;
      case 2:
        return true;
      default:
        return false;
    }
  }

  Future<void> _onNext() async {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final budget = widget.existingBudget!
          ..category = _selectedCategory!
          ..limitAmount = _amount
          ..period = _period
          ..startDate = _startDate;
        await ref.read(updateBudgetProvider(budget).future);
      } else {
        final budget = BudgetModel()
          ..category = _selectedCategory!
          ..limitAmount = _amount
          ..period = _period
          ..startDate = _startDate
          ..isActive = true
          ..createdAt = DateTime.now();
        await ref.read(addBudgetProvider(budget).future);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Budget updated' : 'Budget created'),
            behavior: SnackBarBehavior.floating,
            duration: AppConstants.snackBarDuration,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(
              context,
            ).extension<CheddarColors>()!.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── Category Picker Step ──────────────────────────────────────────────────

class _CategoryPickerStep extends ConsumerStatefulWidget {
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const _CategoryPickerStep({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  ConsumerState<_CategoryPickerStep> createState() =>
      _CategoryPickerStepState();
}

class _CategoryPickerStepState extends ConsumerState<_CategoryPickerStep> {
  // FIX: track locally-created custom categories so the grid refreshes
  // immediately after the bottom-sheet form is submitted.
  final List<CategoryModel> _localCustom = [];

  void _showCreateCategorySheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: Spacing.lg,
            left: Spacing.md,
            right: Spacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.lg,
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
                    color: Theme.of(
                      ctx,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: Radii.borderFull,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'New Category',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Category name',
                  border: OutlineInputBorder(borderRadius: Radii.borderMd),
                ),
                onSubmitted: (_) async {
                  await _submitCustomCategory(ctx, nameCtrl.text);
                },
              ),
              const SizedBox(height: Spacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await _submitCustomCategory(ctx, nameCtrl.text);
                  },
                  child: const Text('Create & Select'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitCustomCategory(
    BuildContext sheetCtx,
    String rawName,
  ) async {
    final name = rawName.trim();
    if (name.isEmpty) return;

    final categoryRepo = ref.read(categoryRepositoryProvider);
    final newCat = CategoryModel()
      ..name = name
      ..icon = AssetPaths.categoryDefault
      ..color = 0xFF9E9E9E
      ..type = 0
      ..isCustom = true
      ..sortOrder = 999
      ..createdAt = DateTime.now();

    await categoryRepo.add(newCat);

    if (mounted) {
      setState(() => _localCustom.add(newCat));
      widget.onCategorySelected(name);
    }
    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final categoryRepo = ref.watch(categoryRepositoryProvider);
    final budgets = ref.watch(allBudgetsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Spacing.horizontalMd,
          child: Text(
            'Choose a category',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Padding(
          padding: Spacing.horizontalMd,
          child: Text(
            'Select a spending category to budget',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        Expanded(
          child: FutureBuilder<List<CategoryModel>>(
            future: categoryRepo.getByType(0),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Merge DB categories with any newly created local ones,
              // deduplicating by name.
              final dbCats = snapshot.data!;
              final existingNames = dbCats.map((c) => c.name).toSet();
              final merged = [
                ...dbCats,
                ..._localCustom.where((c) => !existingNames.contains(c.name)),
              ];

              final budgetedCategories =
                  budgets.valueOrNull?.map((b) => b.category).toSet() ?? {};

              return GridView.builder(
                padding: Spacing.horizontalMd,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: Spacing.sm,
                  crossAxisSpacing: Spacing.sm,
                  childAspectRatio: 0.85,
                ),
                // FIX: +1 for the trailing '+ New Category' tile.
                itemCount: merged.length + 1,
                itemBuilder: (context, index) {
                  // Last tile: create custom category.
                  if (index == merged.length) {
                    return GestureDetector(
                          onTap: () => _showCreateCategorySheet(context),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: Radii.borderMd,
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1.5,
                                // dashed border approximation via solid thin line
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 28,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: Spacing.xs),
                                Text(
                                  'New',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 30 * merged.length),
                          duration: 300.ms,
                        )
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1.0, 1.0),
                          delay: Duration(milliseconds: 30 * merged.length),
                          duration: 300.ms,
                        );
                  }

                  final cat = merged[index];
                  final isSelected = widget.selectedCategory == cat.name;
                  final isAlreadyBudgeted = budgetedCategories.contains(
                    cat.name,
                  );
                  final color =
                      cheddarColors.categoryColors[cat.name.toLowerCase()] ??
                      theme.colorScheme.primary;

                  return GestureDetector(
                        onTap: isAlreadyBudgeted
                            ? null
                            : () => widget.onCategorySelected(cat.name),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.15)
                                : isAlreadyBudgeted
                                ? theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5)
                                : theme.colorScheme.surfaceContainerLow,
                            borderRadius: Radii.borderMd,
                            border: Border.all(
                              color: isSelected ? color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(cat.icon, width: 28, height: 28),
                              const SizedBox(height: Spacing.xs),
                              Container(
                                width: 18,
                                height: 3,
                                margin: const EdgeInsets.only(
                                  bottom: Spacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: isAlreadyBudgeted
                                      ? theme.colorScheme.onSurface.withValues(
                                          alpha: 0.18,
                                        )
                                      : color.withValues(alpha: 0.55),
                                  borderRadius: Radii.borderFull,
                                ),
                              ),
                              Text(
                                cat.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isAlreadyBudgeted
                                      ? theme.colorScheme.onSurface.withValues(
                                          alpha: 0.3,
                                        )
                                      : null,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isAlreadyBudgeted)
                                Text(
                                  'Budgeted',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 8,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 30 * index),
                        duration: 300.ms,
                      )
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.0, 1.0),
                        delay: Duration(milliseconds: 30 * index),
                        duration: 300.ms,
                      );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Amount Step ────────────────────────────────────────────────────────────

// FIX: Converted from StatelessWidget to StatefulWidget so that the
// AmountInputWidget's onAmountChanged callback triggers a local setState.
// Without this, typing a value calls onAmountChanged on the parent but the
// parent's _canProceed() guard read _amount = 0 because no setState was
// wrapped around the assignment in _buildCurrentStep (StatelessWidget
// can't rebuild the parent's button state). Now the parent uses setState
// in the onAmountChanged callback AND the step itself refreshes correctly.
class _AmountStep extends StatefulWidget {
  final double initialAmount;
  final ValueChanged<double> onAmountChanged;

  const _AmountStep({
    super.key,
    required this.initialAmount,
    required this.onAmountChanged,
  });

  @override
  State<_AmountStep> createState() => _AmountStepState();
}

class _AmountStepState extends State<_AmountStep> {
  late double _localAmount;

  @override
  void initState() {
    super.initState();
    _localAmount = widget.initialAmount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: Spacing.horizontalMd,
          child: Text(
            'Set budget limit',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Padding(
          padding: Spacing.horizontalMd,
          child: Text(
            'Maximum amount you want to spend',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xl),
        Expanded(
          child: AmountInputWidget(
            initialAmount: _localAmount,
            onAmountChanged: (value) {
              setState(() => _localAmount = value);
              widget.onAmountChanged(value);
            },
            amountColor: theme.colorScheme.primary,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ── Period Step ──────────────────────────────────────────────────────────────

class _PeriodStep extends StatelessWidget {
  final int period;
  final DateTime startDate;
  final ValueChanged<int> onPeriodChanged;
  final ValueChanged<DateTime> onDateChanged;

  const _PeriodStep({
    super.key,
    required this.period,
    required this.startDate,
    required this.onPeriodChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final periods = [
      {'label': 'Weekly', 'value': 0, 'icon': Icons.view_week_rounded},
      {'label': 'Monthly', 'value': 1, 'icon': Icons.calendar_month_rounded},
      {'label': 'Yearly', 'value': 2, 'icon': Icons.calendar_today_rounded},
    ];

    return SingleChildScrollView(
      padding: Spacing.horizontalMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget period',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'How often should this budget reset?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Wrap(
            spacing: Spacing.sm,
            children: periods.map((p) {
              final isSelected = period == p['value'];
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      p['icon'] as IconData,
                      size: 18,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(p['label'] as String),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => onPeriodChanged(p['value'] as int),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.xl),
          Text(
            'Start date',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(now.year + 10, now.month, now.day),
              );
              if (picked != null) onDateChanged(picked);
            },
            borderRadius: Radii.borderMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: Radii.borderMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    DateFormat('MMMM d, y').format(startDate),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Container(
            width: double.infinity,
            padding: Spacing.paddingMd,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: Radii.borderMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'This budget will reset ${_periodLabel(period).toLowerCase()} '
                  'starting ${DateFormat('MMM d, y').format(startDate)}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  String _periodLabel(int period) {
    switch (period) {
      case 0:
        return 'Weekly';
      case 1:
        return 'Monthly';
      case 2:
        return 'Yearly';
      default:
        return 'Monthly';
    }
  }
}
