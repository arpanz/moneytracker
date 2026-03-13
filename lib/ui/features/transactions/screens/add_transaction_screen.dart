import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../providers/transaction_providers.dart';

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

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  // ── Amount state ──────────────────────────────────────────────────────────
  String _rawInput = '';
  bool _hasDecimal = false;
  int _decimalDigits = 0;
  static const int _maxIntDigits = 10;
  static const int _maxDecDigits = 2;
  final _formatter = NumberFormat('#,##,###.##', 'en_IN');

  // ── Form state ────────────────────────────────────────────────────────────
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
  bool _showMore = false;

  // ── Edit restore ─────────────────────────────────────────────────────────
  String? _editCategoryName;
  String? _editAccountId;
  String? _editToAccountId;

  bool get _isEditing => widget.existingTransaction != null;

  // ── Amount helpers ────────────────────────────────────────────────────────

  double get _amount {
    if (_rawInput.isEmpty) return 0.0;
    if (!_hasDecimal) return double.tryParse(_rawInput) ?? 0.0;
    final intLen = _rawInput.length - _decimalDigits;
    final ip = _rawInput.substring(0, intLen);
    final dp = _rawInput.substring(intLen);
    return double.tryParse('$ip.$dp') ?? 0.0;
  }

  String get _displayAmount {
    if (_rawInput.isEmpty) return '0';
    if (!_hasDecimal) return _formatter.format(_amount.truncate());
    final ip = _amount.truncate();
    final intLen = _rawInput.length - _decimalDigits;
    final dp = _rawInput.substring(intLen);
    return '${_formatter.format(ip)}.$dp';
  }

  void _initAmountFromDouble(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final ip = parts[0];
    final dp = parts[1];
    if (dp == '00') {
      _rawInput = ip;
      _hasDecimal = false;
      _decimalDigits = 0;
    } else if (dp.endsWith('0')) {
      _rawInput = '$ip${dp[0]}';
      _hasDecimal = true;
      _decimalDigits = 1;
    } else {
      _rawInput = '$ip$dp';
      _hasDecimal = true;
      _decimalDigits = 2;
    }
  }

  void _digit(String d) {
    HapticFeedback.lightImpact();
    if (_hasDecimal) {
      if (_decimalDigits >= _maxDecDigits) return;
      _decimalDigits++;
    } else {
      if (_rawInput.length >= _maxIntDigits) return;
      if (_rawInput == '0' && d == '0') return;
      if (_rawInput == '0' && d != '0') _rawInput = '';
    }
    setState(() => _rawInput += d);
  }

  void _decimal() {
    HapticFeedback.lightImpact();
    if (_hasDecimal) return;
    setState(() {
      _hasDecimal = true;
      if (_rawInput.isEmpty) _rawInput = '0';
    });
  }

  void _backspace() {
    HapticFeedback.mediumImpact();
    if (_rawInput.isEmpty) return;
    setState(() {
      if (_hasDecimal && _decimalDigits > 0) {
        _rawInput = _rawInput.substring(0, _rawInput.length - 1);
        _decimalDigits--;
        if (_decimalDigits == 0) _hasDecimal = false;
      } else if (_hasDecimal) {
        _hasDecimal = false;
      } else {
        _rawInput = _rawInput.substring(0, _rawInput.length - 1);
      }
    });
  }

  void _clearAmount() {
    HapticFeedback.heavyImpact();
    setState(() {
      _rawInput = '';
      _hasDecimal = false;
      _decimalDigits = 0;
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 1;
    if (_isEditing) _populateFromExisting();
  }

  void _populateFromExisting() {
    final txn = widget.existingTransaction!;
    _initAmountFromDouble(txn.amount);
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
    if (accounts.isEmpty) return;
    bool changed = false;
    if (_editAccountId != null && _selectedAccount == null) {
      final m = accounts
          .where((a) => a.id.toString() == _editAccountId)
          .firstOrNull;
      if (m != null) { _selectedAccount = m; changed = true; }
    }
    if (_editToAccountId != null && _selectedToAccount == null) {
      final m = accounts
          .where((a) => a.id.toString() == _editToAccountId)
          .firstOrNull;
      if (m != null) { _selectedToAccount = m; changed = true; }
    }
    if (!_isEditing && _selectedAccount == null) {
      _selectedAccount = accounts.first;
      changed = true;
    }
    if (_type == 2 && !_isEditing && _selectedToAccount == null) {
      _selectedToAccount = accounts.length > 1
          ? accounts.firstWhere((a) => a.id != _selectedAccount?.id)
          : accounts.last;
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ── Accent colour helper ──────────────────────────────────────────────────

  Color _accentColor(CheddarColors cc) => switch (_type) {
        0 => cc.income,
        2 => cc.transfer,
        _ => cc.expense,
      };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cc = theme.extension<CheddarColors>()!;
    final accent = _accentColor(cc);
    final accountsAsync = ref.watch(_activeAccountsProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            _TopBar(
              isEditing: _isEditing,
              onClose: () => context.pop(),
            ),

            // ── Type selector ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.xs,
              ),
              child: _TypeSelector(
                selected: _type,
                cc: cc,
                onChanged: (t) => setState(() {
                  if (_type == t) return;
                  _type = t;
                  _selectedCategory = null;
                  _editCategoryName = null;
                  if (_type != 2) _selectedToAccount = null;
                }),
              ),
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.fast,
                child: _buildBody(
                  context,
                  theme,
                  cc,
                  accent,
                  accountsAsync,
                  currencySymbol,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    CheddarColors cc,
    Color accent,
    AsyncValue<List<AccountModel>> accountsAsync,
    String currencySymbol,
  ) {
    return Column(
      key: ValueKey(_type),
      children: [
        // ── Category grid (hidden for Transfer) ───────────────────────────
        if (_type != 2)
          _CategoryGrid(
            transactionType: _type,
            selected: _selectedCategory,
            editCategoryName: _editCategoryName,
            onSelected: (cat) => setState(() => _selectedCategory = cat),
          ),

        if (_type == 2)
          _TransferAccountPicker(
            accountsAsync: accountsAsync,
            selectedFrom: _selectedAccount,
            selectedTo: _selectedToAccount,
            onRestoreAccounts: _tryRestoreAccounts,
            onFromChanged: (a) => setState(() => _selectedAccount = a),
            onToChanged: (a) => setState(() => _selectedToAccount = a),
            onCreateAccount: () => _showCreateAccountSheet(context),
          ),

        const Divider(height: 1),

        // ── Meta row: account + date ──────────────────────────────────────
        if (_type != 2)
          _MetaRow(
            accountsAsync: accountsAsync,
            selectedAccount: _selectedAccount,
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            onRestoreAccounts: _tryRestoreAccounts,
            onAccountChanged: (a) => setState(() => _selectedAccount = a),
            onCreateAccount: () => _showCreateAccountSheet(context),
            onPickDate: _pickDate,
            onPickTime: _pickTime,
          ),

        const Divider(height: 1),

        // ── Amount display ────────────────────────────────────────────────
        _AmountDisplay(
          displayText: _hasDecimal && _decimalDigits == 0
              ? '$_displayAmount.'
              : _displayAmount,
          accent: accent,
          currencySymbol: currencySymbol,
        ),

        // ── Note field (inline, compact) ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.xs,
          ),
          child: TextField(
            controller: _noteController,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Add a note...',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: Radii.borderMd,
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: Radii.borderMd,
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.25),
                ),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 1,
          ),
        ),

        // ── More options toggle ───────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _showMore = !_showMore),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  _showMore
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _showMore ? 'Less options' : 'More options',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_isRecurring || _tags.isNotEmpty || _isSplit) ...[
                  const SizedBox(width: Spacing.xs),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (_showMore)
          _MoreOptions(
            theme: theme,
            accent: accent,
            tags: _tags,
            tagController: _tagController,
            isRecurring: _isRecurring,
            recurringFrequency: _recurringFrequency,
            isSplit: _isSplit,
            onTagAdded: (t) => setState(() => _tags.add(t)),
            onTagRemoved: (t) => setState(() => _tags.remove(t)),
            onRecurringChanged: (v) => setState(() => _isRecurring = v),
            onFrequencyChanged: (f) => setState(() => _recurringFrequency = f),
            onSplitChanged: (v) {
              setState(() => _isSplit = v);
              if (v) context.pushNamed(RouteNames.addSplit);
            },
            onReceiptTap: () => context.pushNamed(RouteNames.scanner),
          ),

        const Spacer(),

        // ── Numpad ────────────────────────────────────────────────────────
        _Numpad(
          accent: accent,
          isSaving: _isSaving,
          onDigit: _digit,
          onDecimal: _decimal,
          onBackspace: _backspace,
          onClear: _clearAmount,
          onConfirm: _onSave,
        ),

        const SizedBox(height: Spacing.sm),
      ],
    );
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

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

  // ── Inline account creation ───────────────────────────────────────────────

  void _showCreateAccountSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    int selectedType = 0;
    const accountTypes = [
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: Radii.borderFull,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text('New Account',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
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
              Text('Account type',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                children: accountTypes.map((t) => ChoiceChip(
                  avatar: Icon(t.icon, size: 16),
                  label: Text(t.label),
                  selected: selectedType == t.value,
                  onSelected: (_) => setS(() => selectedType = t.value),
                  shape: RoundedRectangleBorder(borderRadius: Radii.borderFull),
                )).toList(),
              ),
              const SizedBox(height: Spacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final repo = ref.read(accountRepositoryProvider);
                    final currency = ref.read(currencyCodeProvider);
                    final acc = AccountModel()
                      ..name = name
                      ..accountType = selectedType
                      ..balance = 0.0
                      ..currency = currency
                      ..color = 0xFF9E9E9E
                      ..icon = switch (selectedType) {
                        0 => 'building-columns',
                        1 => 'wallet',
                        2 => 'credit-card',
                        3 => 'money-bill',
                        _ => 'wallet',
                      }
                      ..isArchived = false
                      ..createdAt = DateTime.now();
                    await repo.add(acc);
                    ref.invalidate(_activeAccountsProvider);
                    if (mounted) setState(() => _selectedAccount = acc);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Create & Select'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _onSave() async {
    if (_amount <= 0) {
      _snack('Please enter an amount greater than zero.');
      return;
    }
    if (_type != 2 && _selectedCategory == null) {
      _snack('Please select a category.');
      return;
    }
    if (_selectedAccount == null) {
      _snack('Please select an account.');
      return;
    }
    if (_type == 2 && _selectedToAccount == null) {
      _snack('Please select a destination account.');
      return;
    }
    if (_type == 2 && _selectedAccount?.id == _selectedToAccount?.id) {
      _snack('Source and destination accounts must be different.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dt = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );
      final txn = _isEditing ? widget.existingTransaction! : TransactionModel();
      txn
        ..amount = _amount
        ..type = _type
        ..category = _type == 2 ? 'Transfer' : _selectedCategory!.name
        ..accountId = _selectedAccount!.id.toString()
        ..toAccountId = _type == 2 ? _selectedToAccount?.id.toString() : null
        ..date = dt
        ..note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim()
        ..tags = List<String>.from(_tags)
        ..isRecurring = _isRecurring
        ..recurringRule = _isRecurring
            ? json.encode({'frequency': _recurringFrequency.toLowerCase(), 'interval': 1, 'endDate': null})
            : null;

      if (_isEditing) {
        await ref.read(updateTransactionProvider(txn).future);
      } else {
        await ref.read(addTransactionProvider(txn).future);
      }
      if (mounted) context.pop();
    } catch (e) {
      _snack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: AppConstants.snackBarDuration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onClose;

  const _TopBar({required this.isEditing, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              isEditing ? 'Edit Transaction' : 'New Transaction',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ── Type Selector ─────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final int selected;
  final CheddarColors cc;
  final ValueChanged<int> onChanged;

  const _TypeSelector({
    required this.selected,
    required this.cc,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = [
      (label: 'Expense', value: 1, color: cc.expense),
      (label: 'Income', value: 0, color: cc.income),
      (label: 'Transfer', value: 2, color: cc.transfer),
    ];
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: Radii.borderFull,
      ),
      child: Row(
        children: types.map((t) {
          final isSelected = selected == t.value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(t.value),
              child: AnimatedContainer(
                duration: AppDurations.fast,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? t.color : Colors.transparent,
                  borderRadius: Radii.borderFull,
                  boxShadow: isSelected
                      ? [BoxShadow(color: t.color.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Category Grid ─────────────────────────────────────────────────────────────

class _CategoryGrid extends ConsumerWidget {
  final int transactionType;
  final CategoryModel? selected;
  final String? editCategoryName;
  final ValueChanged<CategoryModel> onSelected;

  const _CategoryGrid({
    required this.transactionType,
    required this.selected,
    required this.editCategoryName,
    required this.onSelected,
  });

  static const IconData _svgFallback = Icons.category_rounded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(_categoriesByTypeProvider(transactionType));
    final theme = Theme.of(context);
    final cc = theme.extension<CheddarColors>();

    return SizedBox(
      height: 108,
      child: categoriesAsync.when(
        data: (cats) => ListView.separated(
          key: ValueKey(transactionType),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
          itemBuilder: (context, i) {
            final cat = cats[i];
            final isSelected = selected?.id == cat.id ||
                (selected == null && editCategoryName == cat.name);

            // Prefer the CheddarColors map, fall back to stored color
            final catColor = cc?.categoryColors[cat.name.toLowerCase()] ??
                Color(cat.color);

            return GestureDetector(
              onTap: () => onSelected(cat),
              child: AnimatedContainer(
                duration: AppDurations.fast,
                width: 72,
                decoration: BoxDecoration(
                  color: isSelected
                      ? catColor.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: Radii.borderMd,
                  border: Border.all(
                    color: isSelected
                        ? catColor
                        : theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: catColor.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // SVG icon in a rounded square container — same style as
                    // CategoryPickerRow._buildCategoryTile
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: isSelected
                              ? catColor.withValues(alpha: 0.4)
                              : theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: SvgPicture.asset(
                          cat.icon,
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                          placeholderBuilder: (_) => Icon(
                            _svgFallback,
                            size: 20,
                            color: catColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? catColor
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── Transfer Account Picker ────────────────────────────────────────────────────

class _TransferAccountPicker extends StatelessWidget {
  final AsyncValue<List<AccountModel>> accountsAsync;
  final AccountModel? selectedFrom;
  final AccountModel? selectedTo;
  final ValueChanged<List<AccountModel>> onRestoreAccounts;
  final ValueChanged<AccountModel> onFromChanged;
  final ValueChanged<AccountModel> onToChanged;
  final VoidCallback onCreateAccount;

  const _TransferAccountPicker({
    required this.accountsAsync,
    required this.selectedFrom,
    required this.selectedTo,
    required this.onRestoreAccounts,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onCreateAccount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: accountsAsync.when(
        data: (accounts) {
          onRestoreAccounts(accounts);
          return Row(
            children: [
              Expanded(
                child: _AccountColumn(
                  label: 'From',
                  accounts: accounts,
                  selected: selectedFrom,
                  onChanged: onFromChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: _AccountColumn(
                  label: 'To',
                  accounts: accounts,
                  selected: selectedTo,
                  onChanged: onToChanged,
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }
}

class _AccountColumn extends StatelessWidget {
  final String label;
  final List<AccountModel> accounts;
  final AccountModel? selected;
  final ValueChanged<AccountModel> onChanged;

  const _AccountColumn({
    required this.label,
    required this.accounts,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: Spacing.xs),
        DropdownButtonFormField<AccountModel>(
          value: selected,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm, vertical: Spacing.sm),
            border: OutlineInputBorder(borderRadius: Radii.borderMd),
          ),
          items: accounts.map((a) => DropdownMenuItem(
            value: a,
            child: Text(a.name, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (a) { if (a != null) onChanged(a); },
        ),
      ],
    );
  }
}

// ── Meta Row (account + date) ─────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final AsyncValue<List<AccountModel>> accountsAsync;
  final AccountModel? selectedAccount;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final ValueChanged<List<AccountModel>> onRestoreAccounts;
  final ValueChanged<AccountModel> onAccountChanged;
  final VoidCallback onCreateAccount;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _MetaRow({
    required this.accountsAsync,
    required this.selectedAccount,
    required this.selectedDate,
    required this.selectedTime,
    required this.onRestoreAccounts,
    required this.onAccountChanged,
    required this.onCreateAccount,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d').format(selectedDate);
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    final timeStr = DateFormat('hh:mm a').format(
      DateTime(0, 1, 1, selectedTime.hour, selectedTime.minute),
    );

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: accountsAsync.when(
              data: (accounts) {
                onRestoreAccounts(accounts);
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: Spacing.xs),
                  itemCount: accounts.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
                  itemBuilder: (ctx, i) {
                    if (i == accounts.length) {
                      return ActionChip(
                        avatar: const Icon(Icons.add, size: 14),
                        label: const Text('New'),
                        onPressed: onCreateAccount,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelStyle: const TextStyle(fontSize: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: Radii.borderFull),
                      );
                    }
                    final acc = accounts[i];
                    final isSel = selectedAccount?.id == acc.id;
                    final accColor = Color(acc.color);
                    return ChoiceChip(
                      label: Text(acc.name,
                          style: const TextStyle(fontSize: 11)),
                      selected: isSel,
                      onSelected: (s) { if (s) onAccountChanged(acc); },
                      selectedColor: accColor.withValues(alpha: 0.15),
                      side: BorderSide(
                        color: isSel
                            ? accColor
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: Radii.borderFull),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    );
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          GestureDetector(
            onTap: onPickDate,
            child: Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: Spacing.xs, vertical: Spacing.xs),
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm, vertical: Spacing.xs),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: Radii.borderFull,
              ),
              child: Text(
                isToday ? 'Today' : dateStr,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          GestureDetector(
            onTap: onPickTime,
            child: Container(
              margin: const EdgeInsets.only(
                  right: Spacing.sm, top: Spacing.xs, bottom: Spacing.xs),
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm, vertical: Spacing.xs),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: Radii.borderFull,
              ),
              child: Text(
                timeStr,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Amount Display ────────────────────────────────────────────────────────────

class _AmountDisplay extends StatelessWidget {
  final String displayText;
  final Color accent;
  final String currencySymbol;

  const _AmountDisplay({
    required this.displayText,
    required this.accent,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              currencySymbol,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: accent.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              displayText,
              style: theme.textTheme.displayMedium?.copyWith(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: -2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── More Options ─────────────────────────────────────────────────────────────

class _MoreOptions extends StatelessWidget {
  final ThemeData theme;
  final Color accent;
  final List<String> tags;
  final TextEditingController tagController;
  final bool isRecurring;
  final String recurringFrequency;
  final bool isSplit;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onTagRemoved;
  final ValueChanged<bool> onRecurringChanged;
  final ValueChanged<String> onFrequencyChanged;
  final ValueChanged<bool> onSplitChanged;
  final VoidCallback onReceiptTap;

  const _MoreOptions({
    required this.theme,
    required this.accent,
    required this.tags,
    required this.tagController,
    required this.isRecurring,
    required this.recurringFrequency,
    required this.isSplit,
    required this.onTagAdded,
    required this.onTagRemoved,
    required this.onRecurringChanged,
    required this.onFrequencyChanged,
    required this.onSplitChanged,
    required this.onReceiptTap,
  });

  @override
  Widget build(BuildContext context) {
    const frequencies = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: [
              ...tags.map((tag) => InputChip(
                label: Text(tag, style: const TextStyle(fontSize: 12)),
                onDeleted: () => onTagRemoved(tag),
                deleteIcon: const Icon(Icons.close, size: 14),
                shape: RoundedRectangleBorder(borderRadius: Radii.borderFull),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )),
              ActionChip(
                avatar: const Icon(Icons.label_outline, size: 14),
                label: const Text('Tag', style: TextStyle(fontSize: 12)),
                onPressed: () => _addTagDialog(context),
                shape: RoundedRectangleBorder(borderRadius: Radii.borderFull),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          const SizedBox(height: Spacing.xs),

          Row(
            children: [
              Expanded(
                child: _ToggleTile(
                  icon: FontAwesomeIcons.repeat,
                  label: 'Recurring',
                  value: isRecurring,
                  onChanged: onRecurringChanged,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _ToggleTile(
                  icon: FontAwesomeIcons.peopleLine,
                  label: 'Split',
                  value: isSplit,
                  onChanged: onSplitChanged,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              InkWell(
                onTap: onReceiptTap,
                borderRadius: Radii.borderMd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm, vertical: Spacing.sm + 2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                    borderRadius: Radii.borderMd,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.camera, size: 13,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('Receipt',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (isRecurring) ...[
            const SizedBox(height: Spacing.xs),
            Row(
              children: frequencies.map((f) {
                final isSel = recurringFrequency == f;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(f, style: const TextStyle(fontSize: 11)),
                      selected: isSel,
                      onSelected: (s) { if (s) onFrequencyChanged(f); },
                      shape: RoundedRectangleBorder(
                          borderRadius: Radii.borderFull),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _addTagDialog(BuildContext context) {
    tagController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: tagController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tag name...'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) {
            final t = tagController.text.trim();
            if (t.isNotEmpty && !tags.contains(t)) onTagAdded(t);
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final t = tagController.text.trim();
              if (t.isNotEmpty && !tags.contains(t)) onTagAdded(t);
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.sm + 2),
        decoration: BoxDecoration(
          color: value
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          border: Border.all(
            color: value
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: Radii.borderMd,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: 13,
                color: value
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                  color: value
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Numpad ────────────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final Color accent;
  final bool isSaving;
  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  const _Numpad({
    required this.accent,
    required this.isSaving,
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    required this.onClear,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final btnColor = theme.colorScheme.surfaceContainerHighest;
    final txtColor = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Column(
        children: [
          _row(['1', '2', '3'], btnColor, txtColor),
          const SizedBox(height: Spacing.xs),
          _row(['4', '5', '6'], btnColor, txtColor),
          const SizedBox(height: Spacing.xs),
          _row(['7', '8', '9'], btnColor, txtColor),
          const SizedBox(height: Spacing.xs),
          _bottomRow(theme, btnColor, txtColor),
        ],
      ),
    );
  }

  Widget _row(List<String> digits, Color bg, Color fg) {
    return Row(
      children: digits.map((d) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _Btn(label: d, color: bg, textColor: fg, onTap: () => onDigit(d)),
        ),
      )).toList(),
    );
  }

  Widget _bottomRow(ThemeData theme, Color bg, Color fg) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _Btn(label: '.', color: bg, textColor: fg, onTap: onDecimal),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _Btn(label: '0', color: bg, textColor: fg, onTap: () => onDigit('0')),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _Btn(
              icon: Icons.backspace_outlined,
              color: bg,
              textColor: fg,
              onTap: onBackspace,
              onLongPress: onClear,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _Btn(
              icon: isSaving ? null : Icons.check_rounded,
              color: accent,
              textColor: Colors.white,
              onTap: onConfirm,
              child: isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? child;

  const _Btn({
    this.label,
    this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.onLongPress,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: Radii.borderMd,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: Radii.borderMd,
        child: SizedBox(
          height: 52,
          child: Center(
            child: child ??
                (icon != null
                    ? Icon(icon, color: textColor, size: 22)
                    : Text(label ?? '',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ))),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Providers
// ═══════════════════════════════════════════════════════════════════════════════

final _activeAccountsProvider = FutureProvider<List<AccountModel>>((ref) {
  return ref.watch(accountRepositoryProvider).getActive();
});

final _categoriesByTypeProvider =
    FutureProvider.family<List<CategoryModel>, int>((ref, type) {
  return ref.watch(categoryRepositoryProvider).getByType(type);
});
