import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../../../../domain/models/account_model.dart';
import '../../../../domain/models/category_model.dart';
import '../../../../domain/models/transaction_model.dart';
import '../../../widgets/category_picker.dart';
import '../providers/transaction_providers.dart';
import '../widgets/amount_input_widget.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionModel? existingTransaction;
  final int? initialType;

  const AddTransactionScreen({
    super.key,
    this.existingTransaction,
    this.initialType,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  double _amount = 0.0;
  late int _type;
  CategoryModel? _selectedCategory;
  AccountModel? _selectedAccount;
  AccountModel? _selectedToAccount;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _noteController = TextEditingController();
  final List<String> _tags = [];
  final _tagController = TextEditingController();
  bool _isRecurring = false;
  String _recurringFrequency = 'Monthly';
  bool _isSplit = false;
  bool _isSaving = false;

  String? _editCategoryName;
  String? _editAccountId;
  String? _editToAccountId;

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 1;
    if (_isEditing) {
      _populateFromExisting();
    }
  }

  void _populateFromExisting() {
    final txn = widget.existingTransaction!;
    _amount = txn.amount;
    _type = txn.type;
    _selectedDate = txn.date;
    _selectedTime = TimeOfDay.fromDateTime(txn.date);
    _noteController.text = txn.note ?? '';
    _tags.addAll(txn.tags);
    _isRecurring = txn.isRecurring;
    _editCategoryName = txn.category;
    _editAccountId = txn.accountId;
    _editToAccountId = txn.toAccountId;
    if (txn.recurringRule != null) {
      try {
        final rule = json.decode(txn.recurringRule!) as Map<String, dynamic>;
        _recurringFrequency = (rule['frequency'] as String?) ?? 'Monthly';
        _recurringFrequency =
            _recurringFrequency[0].toUpperCase() +
            _recurringFrequency.substring(1);
      } catch (_) {
        _recurringFrequency = 'Monthly';
      }
    }
    _isSplit = txn.splitId != null;
  }

  void _tryRestoreAccounts(List<AccountModel> accounts) {
    bool changed = false;
    if (_editAccountId != null && _selectedAccount == null) {
      final match = accounts
          .where((a) => a.id.toString() == _editAccountId)
          .firstOrNull;
      if (match != null) {
        _selectedAccount = match;
        changed = true;
      }
    }
    if (_editToAccountId != null && _selectedToAccount == null) {
      final match = accounts
          .where((a) => a.id.toString() == _editToAccountId)
          .firstOrNull;
      if (match != null) {
        _selectedToAccount = match;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  String get _appBarTitle {
    if (_isEditing) return 'Edit Transaction';
    switch (_type) {
      case 0:
        return 'Add Income';
      case 2:
        return 'Add Transfer';
      default:
        return 'Add Expense';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheddarColors = theme.extension<CheddarColors>()!;
    final accountsAsync = ref.watch(_activeAccountsProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: Spacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.md),

              _AmountDisplayButton(
                amount: _amount,
                type: _type,
                cheddarColors: cheddarColors,
                currencySymbol: currencySymbol,
                onTap: () => _showAmountInput(context, cheddarColors),
              ),

              const SizedBox(height: Spacing.lg),

              _buildTypeSelector(cheddarColors),

              const SizedBox(height: Spacing.lg),

              if (_type != 2) ...[
                Text(
                  'Category',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                // CategoryPickerRow shows a compact preview grid and a full picker dialog.
                CategoryPickerRow(
                  key: ValueKey('cat_picker_$_type'),
                  selected: _selectedCategory,
                  selectedCategoryName: _selectedCategory == null
                      ? _editCategoryName
                      : null,
                  transactionType: _type,
                  onSelected: (cat) {
                    setState(() => _selectedCategory = cat);
                  },
                ),
                const SizedBox(height: Spacing.lg),
              ],

              Row(
                children: [
                  Text(
                    _type == 2 ? 'From Account' : 'Account',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showCreateAccountSheet(context),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              accountsAsync.when(
                data: (accounts) {
                  _tryRestoreAccounts(accounts);
                  return _buildAccountChips(accounts, false);
                },
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Error loading accounts: $e'),
              ),

              if (_type == 2) ...[
                const SizedBox(height: Spacing.md),
                Text(
                  'To Account',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                accountsAsync.when(
                  data: (accounts) => _buildAccountChips(accounts, true),
                  loading: () => const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],

              const SizedBox(height: Spacing.lg),

              _buildDateTimePicker(theme),

              const SizedBox(height: Spacing.lg),

              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'Add a note...',
                  prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: Radii.borderMd),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 200,
              ),

              const SizedBox(height: Spacing.md),

              _buildTagsSection(theme),

              const SizedBox(height: Spacing.md),

              OutlinedButton.icon(
                onPressed: () => context.pushNamed(RouteNames.scanner),
                icon: const FaIcon(FontAwesomeIcons.camera, size: 16),
                label: const Text('Attach Receipt'),
                style: OutlinedButton.styleFrom(
                  padding: Spacing.paddingMd,
                  shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
                ),
              ),

              const SizedBox(height: Spacing.md),

              _buildRecurringSection(theme),

              const SizedBox(height: Spacing.sm),

              _buildSplitSection(theme),

              const SizedBox(height: Spacing.xl),

              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isSaving ? null : _onSave,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing
                              ? 'Update Transaction'
                              : 'Save Transaction',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: Spacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  // ── Amount Bottom Sheet ──

  void _showAmountInput(BuildContext context, CheddarColors cheddarColors) {
    final Color accentColor;
    switch (_type) {
      case 0:
        accentColor = cheddarColors.income;
        break;
      case 2:
        accentColor = cheddarColors.transfer;
        break;
      default:
        accentColor = cheddarColors.expense;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: Radii.borderFull,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              AmountInputWidget(
                initialAmount: _amount,
                amountColor: accentColor,
                onAmountChanged: (value) {
                  setState(() => _amount = value);
                },
              ),
              const SizedBox(height: Spacing.lg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Inline Account Creation Sheet ──

  void _showCreateAccountSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    int selectedType = 0;
    final accountTypes = [
      (label: 'Bank', value: 0, icon: Icons.account_balance_rounded),
      (label: 'Wallet', value: 1, icon: Icons.account_balance_wallet_rounded),
      (label: 'Card', value: 2, icon: Icons.credit_card_rounded),
      (label: 'Cash', value: 3, icon: Icons.money_rounded),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
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
                    'New Account',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Account name',
                      border: OutlineInputBorder(borderRadius: Radii.borderMd),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Account type',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Wrap(
                    spacing: Spacing.sm,
                    children: accountTypes.map((t) {
                      return ChoiceChip(
                        avatar: Icon(t.icon, size: 16),
                        label: Text(t.label),
                        selected: selectedType == t.value,
                        onSelected: (_) =>
                            setSheetState(() => selectedType = t.value),
                        shape: RoundedRectangleBorder(
                          borderRadius: Radii.borderFull,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: Spacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await _submitNewAccount(
                          ctx,
                          nameCtrl.text,
                          selectedType,
                        );
                      },
                      child: const Text('Create & Select'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitNewAccount(
    BuildContext sheetCtx,
    String rawName,
    int accountType,
  ) async {
    final name = rawName.trim();
    if (name.isEmpty) return;

    final accountRepo = ref.read(accountRepositoryProvider);
    final newAccount = AccountModel()
      ..name = name
      ..accountType = accountType
      ..balance = 0.0
      ..color = 0xFF9E9E9E
      ..icon = 'wallet'
      ..isArchived = false
      ..createdAt = DateTime.now();

    await accountRepo.add(newAccount);
    ref.invalidate(_activeAccountsProvider);
    if (mounted) setState(() => _selectedAccount = newAccount);
    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
  }

  // ── Type Selector ──

  Widget _buildTypeSelector(CheddarColors cheddarColors) {
    final types = [
      _TypeOption(
        'Expense',
        1,
        cheddarColors.expense,
        FontAwesomeIcons.arrowDown,
      ),
      _TypeOption('Income', 0, cheddarColors.income, FontAwesomeIcons.arrowUp),
      _TypeOption(
        'Transfer',
        2,
        cheddarColors.transfer,
        FontAwesomeIcons.arrowRightArrowLeft,
      ),
    ];

    return Row(
      children: types.map((option) {
        final isSelected = _type == option.value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              decoration: BoxDecoration(
                color: isSelected
                    ? option.color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: Radii.borderMd,
                border: Border.all(
                  color: isSelected
                      ? option.color
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() {
                    if (_type != option.value) {
                      _type = option.value;
                      _selectedCategory = null;
                      _editCategoryName = null;
                    }
                  }),
                  borderRadius: Radii.borderMd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Spacing.sm + 2,
                      horizontal: Spacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          option.icon,
                          size: 14,
                          color: isSelected
                              ? option.color
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? option.color
                                : Theme.of(context).colorScheme.onSurface,
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
      }).toList(),
    );
  }

  // ── Account Chips ──

  Widget _buildAccountChips(List<AccountModel> accounts, bool isToAccount) {
    final selected = isToAccount ? _selectedToAccount : _selectedAccount;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
        itemBuilder: (context, index) {
          final account = accounts[index];
          final isSelected = selected?.id == account.id;
          final accountColor = Color(account.color);

          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  _accountIcon(account.icon),
                  size: 14,
                  color: isSelected
                      ? accountColor
                      : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
                Text(account.name),
              ],
            ),
            selected: isSelected,
            onSelected: (sel) {
              if (!sel) return;
              setState(() {
                if (isToAccount) {
                  _selectedToAccount = account;
                } else {
                  _selectedAccount = account;
                }
              });
            },
            selectedColor: accountColor.withValues(alpha: 0.15),
            side: BorderSide(
              color: isSelected
                  ? accountColor
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
            ),
            shape: RoundedRectangleBorder(borderRadius: Radii.borderFull),
          );
        },
      ),
    );
  }

  // ── Date & Time Picker ──

  Widget _buildDateTimePicker(ThemeData theme) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _pickDate,
            borderRadius: Radii.borderMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm + 4,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: Radii.borderMd,
              ),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.calendar,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      dateFormat.format(_selectedDate),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        InkWell(
          onTap: _pickTime,
          borderRadius: Radii.borderMd,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm + 4,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: Radii.borderMd,
            ),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.clock,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  timeFormat.format(
                    DateTime(0, 1, 1, _selectedTime.hour, _selectedTime.minute),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 10, now.month, now.day),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── Tags Section ──

  Widget _buildTagsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: [
            ..._tags.map((tag) {
              return InputChip(
                label: Text(tag),
                onDeleted: () => setState(() => _tags.remove(tag)),
                deleteIcon: const Icon(Icons.close, size: 16),
                shape: RoundedRectangleBorder(borderRadius: Radii.borderFull),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add Tag'),
              onPressed: () => _showAddTagDialog(theme),
              shape: RoundedRectangleBorder(borderRadius: Radii.borderFull),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddTagDialog(ThemeData theme) {
    _tagController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Tag'),
          content: TextField(
            controller: _tagController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Tag name...'),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _submitTag(ctx),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _submitTag(ctx),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _submitTag(BuildContext dialogContext) {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
    }
    Navigator.of(dialogContext).pop();
  }

  // ── Recurring Section ──

  Widget _buildRecurringSection(ThemeData theme) {
    const frequencies = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        child: Column(
          children: [
            Row(
              children: [
                const FaIcon(FontAwesomeIcons.repeat, size: 16),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'Recurring',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: _isRecurring,
                  onChanged: (val) => setState(() => _isRecurring = val),
                ),
              ],
            ),
            if (_isRecurring) ...[
              const Divider(height: 1),
              const SizedBox(height: Spacing.sm),
              Row(
                children: frequencies.map((freq) {
                  final isSelected = _recurringFrequency == freq;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(freq, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (sel) {
                          if (sel) {
                            setState(() => _recurringFrequency = freq);
                          }
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: Radii.borderFull,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: Spacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  // ── Split Section ──

  Widget _buildSplitSection(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        child: Row(
          children: [
            const FaIcon(FontAwesomeIcons.peopleLine, size: 16),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                'Split this expense',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch(
              value: _isSplit,
              onChanged: (val) {
                setState(() => _isSplit = val);
                if (val) context.pushNamed(RouteNames.addSplit);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Save Logic ──

  Future<void> _onSave() async {
    if (_amount <= 0) {
      _showSnackBar('Please enter an amount greater than zero.');
      return;
    }
    if (_type != 2 && _selectedCategory == null) {
      _showSnackBar('Please select a category.');
      return;
    }
    if (_selectedAccount == null) {
      _showSnackBar('Please select an account.');
      return;
    }
    if (_type == 2 && _selectedToAccount == null) {
      _showSnackBar('Please select a destination account for transfer.');
      return;
    }
    if (_type == 2 && _selectedAccount?.id == _selectedToAccount?.id) {
      _showSnackBar('Source and destination accounts must be different.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final TransactionModel txn;
      if (_isEditing) {
        txn = widget.existingTransaction!;
      } else {
        txn = TransactionModel();
      }

      txn.amount = _amount;
      txn.type = _type;
      txn.category = _type == 2 ? 'Transfer' : _selectedCategory!.name;
      txn.accountId = _selectedAccount!.id.toString();
      txn.toAccountId = _type == 2 ? _selectedToAccount?.id.toString() : null;
      txn.date = dateTime;
      txn.note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();
      txn.tags = List<String>.from(_tags);
      txn.isRecurring = _isRecurring;
      txn.recurringRule = _isRecurring
          ? json.encode({
              'frequency': _recurringFrequency.toLowerCase(),
              'interval': 1,
              'endDate': null,
            })
          : null;

      if (_isEditing) {
        await ref.read(updateTransactionProvider(txn).future);
      } else {
        await ref.read(addTransactionProvider(txn).future);
      }

      if (mounted) context.pop();
    } catch (e) {
      _showSnackBar('Failed to save transaction: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: AppConstants.snackBarDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
      ),
    );
  }

  FaIconData _accountIcon(String iconName) {
    switch (iconName) {
      case 'wallet':
        return FontAwesomeIcons.wallet;
      case 'credit-card':
        return FontAwesomeIcons.creditCard;
      case 'piggy-bank':
        return FontAwesomeIcons.piggyBank;
      case 'money-bill':
        return FontAwesomeIcons.moneyBill;
      case 'chart-line':
        return FontAwesomeIcons.chartLine;
      case 'building-columns':
        return FontAwesomeIcons.buildingColumns;
      case 'landmark':
        return FontAwesomeIcons.landmark;
      default:
        return FontAwesomeIcons.wallet;
    }
  }
}

// ── Type Option ────────────────────────────────────────────────────────────────

class _TypeOption {
  final String label;
  final int value;
  final Color color;
  final FaIconData icon;

  const _TypeOption(this.label, this.value, this.color, this.icon);
}

// ── Amount Display Button ─────────────────────────────────────────────────────

class _AmountDisplayButton extends StatelessWidget {
  final double amount;
  final int type;
  final CheddarColors cheddarColors;
  final String currencySymbol;
  final VoidCallback onTap;

  const _AmountDisplayButton({
    required this.amount,
    required this.type,
    required this.cheddarColors,
    required this.currencySymbol,
    required this.onTap,
  });

  Color get _amountColor {
    switch (type) {
      case 0:
        return cheddarColors.income;
      case 2:
        return cheddarColors.transfer;
      default:
        return cheddarColors.expense;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat('#,##,###.##', 'en_IN');
    final displayAmount = amount == 0 ? '0' : formatter.format(amount);

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.borderLg,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.lg,
          horizontal: Spacing.md,
        ),
        decoration: BoxDecoration(
          color: _amountColor.withValues(alpha: 0.08),
          borderRadius: Radii.borderLg,
          border: Border.all(color: _amountColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              'Tap to enter amount',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currencySymbol,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: _amountColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayAmount,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: _amountColor,
                      letterSpacing: -1,
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
}

// ── Internal Provider ────────────────────────────────────────────────────────────

final _activeAccountsProvider = FutureProvider<List<AccountModel>>((ref) async {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.getActive();
});
