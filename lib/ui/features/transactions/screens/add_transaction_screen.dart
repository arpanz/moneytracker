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
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_extensions.dart';
import '../../../../domain/models/account_model.dart';
import '../../../../domain/models/category_model.dart';
import '../../../../domain/models/transaction_model.dart';
import '../providers/transaction_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

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
  // ── Phase ─────────────────────────────────────────────────────────────────
  // Phase 0 = category selection (or transfer account picker for type==2)
  // Phase 1 = amount entry (category collapsed to pill)
  bool _categorySelected = false;

  // ── Transaction type ──────────────────────────────────────────────────────
  late int _type; // 0=income 1=expense 2=transfer

  // ── Category ──────────────────────────────────────────────────────────────
  CategoryModel? _selectedCategory;
  String? _editCategoryName;

  // ── Accounts ──────────────────────────────────────────────────────────────
  AccountModel? _selectedAccount;
  AccountModel? _selectedToAccount;
  String? _editAccountId;
  String? _editToAccountId;

  // ── Date / time ───────────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  // ── Note / tags / extras ──────────────────────────────────────────────────
  final _noteController = TextEditingController();
  final List<String> _tags = [];
  final _tagController = TextEditingController();
  bool _isRecurring = false;
  String _recurringFrequency = 'Monthly';
  bool _isSplit = false;
  bool _showMore = false;

  // ── Save state ────────────────────────────────────────────────────────────
  bool _isSaving = false;

  // ── Calculator state ──────────────────────────────────────────────────────
  // We store a list of tokens: numbers (as strings) + operators (+,-,*,/)
  // e.g. ['123', '+', '45'] means 123 + 45
  String _currentInput = ''; // the number currently being typed
  String? _pendingOperator; // operator waiting to be applied
  double? _accumulator; // result so far
  bool _justEvaluated = false; // true after = so next digit starts fresh

  static const int _maxIntDigits = 10;
  static const int _maxDecDigits = 2;
  final _formatter = NumberFormat('#,##,###.##', 'en_IN');

  bool get _isEditing => widget.existingTransaction != null;

  // ── Amount helpers ────────────────────────────────────────────────────────

  double get _currentInputValue {
    if (_currentInput.isEmpty || _currentInput == '.') return 0.0;
    return double.tryParse(_currentInput) ?? 0.0;
  }

  double get _effectiveAmount {
    if (_accumulator != null && _pendingOperator != null) {
      return _applyOp(_accumulator!, _pendingOperator!, _currentInputValue);
    }
    if (_accumulator != null && _pendingOperator == null) return _accumulator!;
    return _currentInputValue;
  }

  double _applyOp(double a, String op, double b) {
    switch (op) {
      case '+':
        return a + b;
      case '−':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        return b == 0 ? a : a / b;
      default:
        return b;
    }
  }

  String _formatNumber(double v) {
    if (v == v.truncateToDouble()) {
      return _formatter.format(v.truncate());
    }
    final parts = v.toStringAsFixed(2).split('.');
    return '${_formatter.format(int.parse(parts[0]))}.${parts[1]}';
  }

  String get _displayAmount {
    if (_currentInput.isEmpty && _accumulator == null) return '0';
    if (_currentInput.isNotEmpty) {
      // Show what user is typing, formatted
      final parts = _currentInput.split('.');
      final intPart = int.tryParse(parts[0]) ?? 0;
      final formatted = _formatter.format(intPart);
      if (parts.length == 2) return '$formatted.${parts[1]}';
      if (_currentInput.endsWith('.')) return '$formatted.';
      return formatted;
    }
    return _formatNumber(_accumulator!);
  }

  String get _expressionDisplay {
    if (_accumulator == null && _pendingOperator == null) return '';
    final accStr = _formatNumber(_accumulator ?? 0);
    if (_pendingOperator == null) return '';
    if (_currentInput.isEmpty) return '$accStr $_pendingOperator';
    return '$accStr $_pendingOperator';
  }

  // ── Calculator actions ────────────────────────────────────────────────────

  void _inputDigit(String d) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_justEvaluated) {
        // After =, start a brand new number
        _accumulator = null;
        _pendingOperator = null;
        _currentInput = '';
        _justEvaluated = false;
      }
      final hasDecimal = _currentInput.contains('.');
      final parts = _currentInput.split('.');
      if (hasDecimal) {
        if (parts.length == 2 && parts[1].length >= _maxDecDigits) return;
      } else {
        if (parts[0].length >= _maxIntDigits) return;
        if (_currentInput == '0' && d == '0') return;
        if (_currentInput == '0' && d != '0') _currentInput = '';
      }
      _currentInput += d;
    });
  }

  void _inputDecimal() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_justEvaluated) {
        _accumulator = null;
        _pendingOperator = null;
        _currentInput = '0';
        _justEvaluated = false;
      }
      if (_currentInput.contains('.')) return;
      if (_currentInput.isEmpty) _currentInput = '0';
      _currentInput += '.';
    });
  }

  void _inputOperator(String op) {
    HapticFeedback.lightImpact();
    setState(() {
      _justEvaluated = false;
      if (_currentInput.isNotEmpty) {
        final val = _currentInputValue;
        if (_accumulator != null && _pendingOperator != null) {
          _accumulator = _applyOp(_accumulator!, _pendingOperator!, val);
        } else {
          _accumulator = val;
        }
        _currentInput = '';
      } else if (_accumulator == null) {
        // Nothing typed yet — ignore operator
        return;
      }
      // Replace pending operator if user taps another
      _pendingOperator = op;
    });
  }

  void _evaluate() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_pendingOperator != null && _currentInput.isNotEmpty) {
        _accumulator = _applyOp(
          _accumulator ?? 0,
          _pendingOperator!,
          _currentInputValue,
        );
        _currentInput = '';
        _pendingOperator = null;
        _justEvaluated = true;
      } else if (_currentInput.isNotEmpty) {
        _accumulator = _currentInputValue;
        _currentInput = '';
        _justEvaluated = true;
      }
    });
  }

  void _backspace() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_currentInput.isNotEmpty) {
        _currentInput = _currentInput.substring(0, _currentInput.length - 1);
      } else if (_pendingOperator != null) {
        _pendingOperator = null;
      } else if (_accumulator != null) {
        // Restore accumulator to editable string
        _currentInput = _formatNumber(_accumulator!).replaceAll(',', '');
        _accumulator = null;
      }
      _justEvaluated = false;
    });
  }

  void _clearAll() {
    HapticFeedback.heavyImpact();
    setState(() {
      _currentInput = '';
      _accumulator = null;
      _pendingOperator = null;
      _justEvaluated = false;
    });
  }

  // ── Init from existing transaction ────────────────────────────────────────

  void _initAmountFromDouble(double amount) {
    _accumulator = amount;
    _currentInput = '';
    _justEvaluated = true;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 1;
    if (_isEditing) _populateFromExisting();
    // Transfer mode skips category phase
    if (_type == 2) _categorySelected = true;
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
    // When editing, we start at phase 1 directly
    _categorySelected = true;
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
      if (m != null) {
        _selectedAccount = m;
        changed = true;
      }
    }
    if (_editToAccountId != null && _selectedToAccount == null) {
      final m = accounts
          .where((a) => a.id.toString() == _editToAccountId)
          .firstOrNull;
      if (m != null) {
        _selectedToAccount = m;
        changed = true;
      }
    }
    if (!_isEditing && _selectedAccount == null && accounts.isNotEmpty) {
      _selectedAccount = accounts.first;
      changed = true;
    }
    if (_type == 2 &&
        !_isEditing &&
        _selectedToAccount == null &&
        accounts.length > 1) {
      _selectedToAccount = accounts.firstWhere(
        (a) => a.id != _selectedAccount?.id,
        orElse: () => accounts.last,
      );
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

  // ── Accent colour ─────────────────────────────────────────────────────────

  Color _accentColor(CheddarColors cc) => switch (_type) {
    0 => cc.income,
    2 => cc.transfer,
    _ => cc.expense,
  };

  // ── Category color ────────────────────────────────────────────────────────

  Color _catColor(CategoryModel cat, CheddarColors? cc) =>
      cc?.categoryColors[cat.name.toLowerCase()] ?? Color(cat.color);

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
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: close + title + type tabs ────────────────────────
            _TopBar(
              isEditing: _isEditing,
              type: _type,
              cc: cc,
              onClose: () => context.pop(),
              onTypeChanged: (t) {
                if (_type == t) return;
                setState(() {
                  _type = t;
                  _selectedCategory = null;
                  _editCategoryName = null;
                  _selectedToAccount = null;
                  // Transfer goes straight to phase 1
                  _categorySelected = (t == 2) ? true : false;
                });
              },
            ),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: _categorySelected
                  ? _buildInputPhase(
                      context,
                      theme,
                      cc,
                      accent,
                      accountsAsync,
                      currencySymbol,
                    )
                  : _buildCategoryPhase(context, theme, cc),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 0: category selection ───────────────────────────────────────────

  Widget _buildCategoryPhase(
    BuildContext context,
    ThemeData theme,
    CheddarColors cc,
  ) {
    return _CategorySelectionPhase(
      transactionType: _type,
      editCategoryName: _editCategoryName,
      cc: cc,
      onSelected: (cat) {
        setState(() {
          _selectedCategory = cat;
          _categorySelected = true;
        });
      },
      onNewCategory: () => _showNewCategoryDialog(context),
    );
  }

  // ── Phase 1: amount entry ─────────────────────────────────────────────────

  Widget _buildInputPhase(
    BuildContext context,
    ThemeData theme,
    CheddarColors cc,
    Color accent,
    AsyncValue<List<AccountModel>> accountsAsync,
    String currencySymbol,
  ) {
    final hasExpr = _expressionDisplay.isNotEmpty;

    return Column(
      children: [
        // ── Collapsed header: category pill (or transfer pickers) ─────────
        AnimatedSize(
          duration: AppDurations.medium,
          curve: Curves.easeInOutCubic,
          child: _type == 2
              ? _TransferHeader(
                  accountsAsync: accountsAsync,
                  selectedFrom: _selectedAccount,
                  selectedTo: _selectedToAccount,
                  onRestoreAccounts: _tryRestoreAccounts,
                  onFromChanged: (a) => setState(() => _selectedAccount = a),
                  onToChanged: (a) => setState(() => _selectedToAccount = a),
                  onCreateAccount: () => _showCreateAccountSheet(context),
                )
              : _CategoryPill(
                  category: _selectedCategory,
                  editCategoryName: _editCategoryName,
                  catColor: _selectedCategory != null
                      ? _catColor(_selectedCategory!, cc)
                      : theme.colorScheme.primary,
                  onTap: () => setState(() => _categorySelected = false),
                ),
        ),

        const SizedBox(height: Spacing.xs),

        // ── Meta row: account picker + date + time ────────────────────────
        _MetaRow(
          accountsAsync: accountsAsync,
          selectedAccount: _selectedAccount,
          selectedDate: _selectedDate,
          selectedTime: _selectedTime,
          accent: accent,
          onRestoreAccounts: _tryRestoreAccounts,
          onPickAccount: () => _showAccountPicker(context, accountsAsync),
          onCreateAccount: () => _showCreateAccountSheet(context),
          onPickDate: _pickDate,
          onPickTime: _pickTime,
          showForTransfer: _type == 2,
        ),

        const Divider(height: 1, thickness: 0.5),

        // ── Amount display ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Expression (e.g. "1,200 +")
              AnimatedSwitcher(
                duration: AppDurations.fast,
                child: hasExpr
                    ? Text(
                        key: ValueKey(_expressionDisplay),
                        _expressionDisplay,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: accent.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
              // Main amount
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      currencySymbol,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: accent.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedSwitcher(
                      duration: AppDurations.fast,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        _displayAmount,
                        key: ValueKey(_displayAmount),
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Note field ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.xs,
          ),
          child: _NoteField(controller: _noteController, accent: accent),
        ),

        // ── More options ──────────────────────────────────────────────────
        _MoreOptionsToggle(
          accent: accent,
          showMore: _showMore,
          hasActiveOptions: _isRecurring || _tags.isNotEmpty || _isSplit,
          onToggle: () => setState(() => _showMore = !_showMore),
        ),

        AnimatedSize(
          duration: AppDurations.medium,
          curve: Curves.easeInOutCubic,
          child: _showMore
              ? _MoreOptions(
                  accent: accent,
                  tags: _tags,
                  tagController: _tagController,
                  isRecurring: _isRecurring,
                  recurringFrequency: _recurringFrequency,
                  isSplit: _isSplit,
                  onTagAdded: (t) => setState(() => _tags.add(t)),
                  onTagRemoved: (t) => setState(() => _tags.remove(t)),
                  onRecurringChanged: (v) => setState(() => _isRecurring = v),
                  onFrequencyChanged: (f) =>
                      setState(() => _recurringFrequency = f),
                  onSplitChanged: (v) {
                    setState(() => _isSplit = v);
                    if (v) context.pushNamed(RouteNames.addSplit);
                  },
                  onReceiptTap: () => context.pushNamed(RouteNames.scanner),
                )
              : const SizedBox.shrink(),
        ),

        const Spacer(),

        // ── Calculator numpad ─────────────────────────────────────────────
        _CalcPad(
          accent: accent,
          isSaving: _isSaving,
          pendingOperator: _pendingOperator,
          onDigit: _inputDigit,
          onDecimal: _inputDecimal,
          onOperator: _inputOperator,
          onBackspace: _backspace,
          onClear: _clearAll,
          onEvaluate: _evaluate,
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

  void _showAccountPicker(
    BuildContext context,
    AsyncValue<List<AccountModel>> accountsAsync,
  ) {
    final accounts = accountsAsync.valueOrNull ?? [];
    if (accounts.isEmpty) {
      _showCreateAccountSheet(context);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.md,
              Spacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: Radii.borderFull,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  'Select Account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                ...accounts.map((acc) {
                  final isSel = _selectedAccount?.id == acc.id;
                  final accColor = Color(acc.color);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Spacing.xs,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accColor.withValues(alpha: 0.12),
                        borderRadius: Radii.borderMd,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: accColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      acc.name,
                      style: TextStyle(
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: isSel
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: accColor,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      setState(() => _selectedAccount = acc);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
                const Divider(height: Spacing.md),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Spacing.xs,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: Radii.borderMd,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'New Account',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showCreateAccountSheet(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      ctx,
                    ).colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: Radii.borderFull,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'New Account',
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
                  labelText: 'Account name',
                  border: OutlineInputBorder(borderRadius: Radii.borderMd),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'Account type',
                style: Theme.of(
                  ctx,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                children: accountTypes
                    .map(
                      (t) => ChoiceChip(
                        avatar: Icon(t.icon, size: 16),
                        label: Text(t.label),
                        selected: selectedType == t.value,
                        onSelected: (_) => setS(() => selectedType = t.value),
                        shape: RoundedRectangleBorder(
                          borderRadius: Radii.borderFull,
                        ),
                      ),
                    )
                    .toList(),
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

  // ── New category dialog ───────────────────────────────────────────────────

  // FontAwesome icon options for custom categories
  static const _iconOptions = [
    (icon: FontAwesomeIcons.utensils, label: 'food'),
    (icon: FontAwesomeIcons.car, label: 'transport'),
    (icon: FontAwesomeIcons.cartShopping, label: 'shopping'),
    (icon: FontAwesomeIcons.fileInvoiceDollar, label: 'bills'),
    (icon: FontAwesomeIcons.film, label: 'entertainment'),
    (icon: FontAwesomeIcons.heartPulse, label: 'health'),
    (icon: FontAwesomeIcons.graduationCap, label: 'education'),
    (icon: FontAwesomeIcons.plane, label: 'travel'),
    (icon: FontAwesomeIcons.gift, label: 'gifts'),
    (icon: FontAwesomeIcons.sackDollar, label: 'salary'),
    (icon: FontAwesomeIcons.laptop, label: 'freelance'),
    (icon: FontAwesomeIcons.chartLine, label: 'investments'),
    (icon: FontAwesomeIcons.houseChimney, label: 'rent'),
    (icon: FontAwesomeIcons.basketShopping, label: 'groceries'),
    (icon: FontAwesomeIcons.paw, label: 'pets'),
    (icon: FontAwesomeIcons.tv, label: 'subscriptions'),
    (icon: FontAwesomeIcons.bolt, label: 'other'),
    (icon: FontAwesomeIcons.droplet, label: 'other'),
    (icon: FontAwesomeIcons.wifi, label: 'other'),
    (icon: FontAwesomeIcons.dumbbell, label: 'other'),
    (icon: FontAwesomeIcons.mugHot, label: 'food'),
    (icon: FontAwesomeIcons.gamepad, label: 'entertainment'),
    (icon: FontAwesomeIcons.music, label: 'entertainment'),
    (icon: FontAwesomeIcons.bookOpen, label: 'education'),
    (icon: FontAwesomeIcons.baby, label: 'health'),
    (icon: FontAwesomeIcons.shirt, label: 'shopping'),
    (icon: FontAwesomeIcons.toolbox, label: 'other'),
    (icon: FontAwesomeIcons.moneyBill, label: 'salary'),
    (icon: FontAwesomeIcons.circleQuestion, label: 'other'),
    (icon: FontAwesomeIcons.mobileScreen, label: 'subscriptions'),
  ];

  int get _categoryType => switch (_type) {
    0 => 1,
    1 => 0,
    _ => 2,
  };

  String _svgForLabel(String label) => switch (label) {
    'food' => AssetPaths.categoryFood,
    'transport' => AssetPaths.categoryTransport,
    'shopping' => AssetPaths.categoryShopping,
    'bills' => AssetPaths.categoryBills,
    'entertainment' => AssetPaths.categoryEntertainment,
    'health' => AssetPaths.categoryHealth,
    'education' => AssetPaths.categoryEducation,
    'travel' => AssetPaths.categoryTravel,
    'gifts' => AssetPaths.categoryGifts,
    'salary' => AssetPaths.categorySalary,
    'freelance' => AssetPaths.categoryFreelance,
    'investments' => AssetPaths.categoryInvestments,
    'rent' => AssetPaths.categoryRent,
    'groceries' => AssetPaths.categoryGroceries,
    'pets' => AssetPaths.categoryPets,
    'subscriptions' => AssetPaths.categorySubscriptions,
    _ => AssetPaths.categoryDefault,
  };

  void _showNewCategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    FaIconData selectedIcon = FontAwesomeIcons.circleQuestion;
    String selectedLabel = 'other';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: Radii.borderLg),
            title: const Text('New Category'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Category name',
                      border: OutlineInputBorder(borderRadius: Radii.borderMd),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Choose icon',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  SizedBox(
                    height: 180,
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: Spacing.sm,
                            crossAxisSpacing: Spacing.sm,
                            childAspectRatio: 1,
                          ),
                      itemCount: _iconOptions.length,
                      itemBuilder: (_, i) {
                        final opt = _iconOptions[i];
                        final isSel = selectedIcon == opt.icon;
                        return GestureDetector(
                          onTap: () => setD(() {
                            selectedIcon = opt.icon;
                            selectedLabel = opt.label;
                          }),
                          child: AnimatedContainer(
                            duration: AppDurations.fast,
                            decoration: BoxDecoration(
                              color: isSel
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    )
                                  : theme.colorScheme.surfaceContainerLow,
                              borderRadius: Radii.borderMd,
                              border: Border.all(
                                color: isSel
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: FaIcon(
                                opt.icon,
                                size: 18,
                                color: isSel
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final categoryRepo = ref.read(categoryRepositoryProvider);
                  final existing = await categoryRepo.getByType(_categoryType);
                  final dup = existing.any(
                    (c) => c.name.trim().toLowerCase() == name.toLowerCase(),
                  );
                  if (dup) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"$name" already exists.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }
                  final newCat = CategoryModel()
                    ..name = name
                    ..icon = _svgForLabel(selectedLabel)
                    ..color = 0xFF9E9E9E
                    ..type = _categoryType
                    ..isCustom = true
                    ..sortOrder = 999
                    ..createdAt = DateTime.now();
                  final newId = await categoryRepo.add(newCat);
                  newCat.id = newId;
                  ref.invalidate(_categoriesByTypeProvider);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    setState(() {
                      _selectedCategory = newCat;
                      _categorySelected = true;
                    });
                  }
                },
                child: const Text('Create & Select'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _onSave() async {
    // Evaluate any pending expression first
    if (_pendingOperator != null && _currentInput.isNotEmpty) {
      _evaluate();
    }
    final amount = _effectiveAmount;

    if (amount <= 0) {
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
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final txn = _isEditing ? widget.existingTransaction! : TransactionModel();
      txn
        ..amount = amount
        ..type = _type
        ..category = _type == 2 ? 'Transfer' : _selectedCategory!.name
        ..accountId = _selectedAccount!.id.toString()
        ..toAccountId = _type == 2 ? _selectedToAccount?.id.toString() : null
        ..date = dt
        ..note = _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim()
        ..tags = List<String>.from(_tags)
        ..isRecurring = _isRecurring
        ..recurringRule = _isRecurring
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
      _snack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: AppConstants.snackBarDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.borderMd),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isEditing;
  final int type;
  final CheddarColors cc;
  final VoidCallback onClose;
  final ValueChanged<int> onTypeChanged;

  const _TopBar({
    required this.isEditing,
    required this.type,
    required this.cc,
    required this.onClose,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = [
      (label: 'Expense', value: 1, color: cc.expense),
      (label: 'Income', value: 0, color: cc.income),
      (label: 'Transfer', value: 2, color: cc.transfer),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xs,
        Spacing.xs,
        Spacing.md,
        Spacing.xs,
      ),
      child: Row(
        children: [
          // Close button
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),

          // Type tabs — takes remaining space
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: Radii.borderFull,
              ),
              child: Row(
                children: types.map((t) {
                  final isSel = type == t.value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTypeChanged(t.value),
                      child: AnimatedContainer(
                        duration: AppDurations.fast,
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isSel ? t.color : Colors.transparent,
                          borderRadius: Radii.borderFull,
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: t.color.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSel
                                  ? Colors.white
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Phase 0: Category Selection ───────────────────────────────────────────────

class _CategorySelectionPhase extends ConsumerStatefulWidget {
  final int transactionType;
  final String? editCategoryName;
  final CheddarColors cc;
  final ValueChanged<CategoryModel> onSelected;
  final VoidCallback onNewCategory;

  const _CategorySelectionPhase({
    required this.transactionType,
    required this.editCategoryName,
    required this.cc,
    required this.onSelected,
    required this.onNewCategory,
  });

  @override
  ConsumerState<_CategorySelectionPhase> createState() =>
      _CategorySelectionPhaseState();
}

class _CategorySelectionPhaseState
    extends ConsumerState<_CategorySelectionPhase> {
  static const IconData _fallback = Icons.category_rounded;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(
      _categoriesByTypeProvider(widget.transactionType),
    );
    final theme = Theme.of(context);

    return categoriesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cats) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                Spacing.xs,
              ),
              child: Text(
                'Choose a category',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  Spacing.xs,
                  Spacing.md,
                  Spacing.md,
                ),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: Spacing.sm,
                  crossAxisSpacing: Spacing.sm,
                  childAspectRatio: 1.0,
                ),
                itemCount: cats.length + 1, // +1 for New
                itemBuilder: (context, i) {
                  // Last tile = New category
                  if (i == cats.length) {
                    return _NewCategoryTile(onTap: widget.onNewCategory);
                  }

                  final cat = cats[i];
                  final isPreSelected = widget.editCategoryName == cat.name;
                  final catColor =
                      widget.cc.categoryColors[cat.name.toLowerCase()] ??
                      Color(cat.color);

                  return _CategoryTile(
                    category: cat,
                    catColor: catColor,
                    isPreSelected: isPreSelected,
                    fallbackIcon: _fallback,
                    onTap: () => widget.onSelected(cat),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final CategoryModel category;
  final Color catColor;
  final bool isPreSelected;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.catColor,
    required this.isPreSelected,
    required this.fallbackIcon,
    required this.onTap,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(_pressCtrl);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isPreSelected
                ? widget.catColor.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: Radii.borderMd,
            border: Border.all(
              color: widget.isPreSelected
                  ? widget.catColor
                  : theme.colorScheme.outline.withValues(alpha: 0.18),
              width: widget.isPreSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: widget.catColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: widget.catColor.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SvgPicture.asset(
                    widget.category.icon,
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => Icon(
                      widget.fallbackIcon,
                      size: 22,
                      color: widget.catColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                child: Text(
                  widget.category.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: widget.isPreSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: widget.isPreSelected
                        ? widget.catColor
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
      ),
    );
  }
}

class _NewCategoryTile extends StatelessWidget {
  final VoidCallback onTap;
  const _NewCategoryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: Radii.borderMd,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.add_rounded,
                color: theme.colorScheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'New',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Pill (collapsed) ─────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  final CategoryModel? category;
  final String? editCategoryName;
  final Color catColor;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.category,
    required this.editCategoryName,
    required this.catColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = category?.name ?? editCategoryName ?? 'Category';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          Spacing.md,
          Spacing.sm,
          Spacing.md,
          Spacing.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: catColor.withValues(alpha: 0.1),
          borderRadius: Radii.borderFull,
          border: Border.all(
            color: catColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (category != null)
              ...([
                SvgPicture.asset(
                  category!.icon,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                  placeholderBuilder: (_) =>
                      Icon(Icons.category_rounded, size: 16, color: catColor),
                ),
                const SizedBox(width: Spacing.xs),
              ]),
            Text(
              name,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: catColor,
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: catColor.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transfer Header ───────────────────────────────────────────────────────────

class _TransferHeader extends StatelessWidget {
  final AsyncValue<List<AccountModel>> accountsAsync;
  final AccountModel? selectedFrom;
  final AccountModel? selectedTo;
  final ValueChanged<List<AccountModel>> onRestoreAccounts;
  final ValueChanged<AccountModel> onFromChanged;
  final ValueChanged<AccountModel> onToChanged;
  final VoidCallback onCreateAccount;

  const _TransferHeader({
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
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.xs,
      ),
      child: accountsAsync.when(
        data: (accounts) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onRestoreAccounts(accounts),
          );
          return Row(
            children: [
              Expanded(
                child: _TransferAccountDrop(
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
                  size: 20,
                ),
              ),
              Expanded(
                child: _TransferAccountDrop(
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
          height: 52,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }
}

class _TransferAccountDrop extends StatelessWidget {
  final String label;
  final List<AccountModel> accounts;
  final AccountModel? selected;
  final ValueChanged<AccountModel> onChanged;

  const _TransferAccountDrop({
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
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.xxs),
        DropdownButtonFormField<AccountModel>(
          value: selected,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.sm,
            ),
            border: OutlineInputBorder(borderRadius: Radii.borderMd),
          ),
          items: accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a,
                  child: Text(
                    a.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )
              .toList(),
          onChanged: (a) {
            if (a != null) onChanged(a);
          },
        ),
      ],
    );
  }
}

// ── Meta Row ──────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final AsyncValue<List<AccountModel>> accountsAsync;
  final AccountModel? selectedAccount;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final Color accent;
  final ValueChanged<List<AccountModel>> onRestoreAccounts;
  final VoidCallback onPickAccount;
  final VoidCallback onCreateAccount;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final bool showForTransfer;

  const _MetaRow({
    required this.accountsAsync,
    required this.selectedAccount,
    required this.selectedDate,
    required this.selectedTime,
    required this.accent,
    required this.onRestoreAccounts,
    required this.onPickAccount,
    required this.onCreateAccount,
    required this.onPickDate,
    required this.onPickTime,
    required this.showForTransfer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d').format(selectedDate);
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    final timeStr = DateFormat(
      'hh:mm a',
    ).format(DateTime(0, 1, 1, selectedTime.hour, selectedTime.minute));

    // Restore accounts on data load
    accountsAsync.whenData(
      (accounts) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => onRestoreAccounts(accounts),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          // Account tap pill (not shown for transfer since it has its own picker)
          if (!showForTransfer)
            ...([
              GestureDetector(
                onTap: onPickAccount,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: Radii.borderFull,
                    border: Border.all(
                      color: selectedAccount != null
                          ? Color(selectedAccount!.color).withValues(alpha: 0.4)
                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 13,
                        color: selectedAccount != null
                            ? Color(selectedAccount!.color)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Spacing.xxs + 2),
                      Text(
                        selectedAccount?.name ?? 'Account',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selectedAccount != null
                              ? Color(selectedAccount!.color)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: Spacing.xxs),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
            ]),

          if (showForTransfer) const Spacer(),

          // Date pill
          GestureDetector(
            onTap: onPickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                borderRadius: Radii.borderFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.xxs + 2),
                  Text(
                    isToday ? 'Today' : dateStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: Spacing.xs),

          // Time pill
          GestureDetector(
            onTap: onPickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                borderRadius: Radii.borderFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.xxs + 2),
                  Text(
                    timeStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Note Field ────────────────────────────────────────────────────────────────

class _NoteField extends StatelessWidget {
  final TextEditingController controller;
  final Color accent;

  const _NoteField({required this.controller, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      style: theme.textTheme.bodyMedium,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 1,
      decoration: InputDecoration(
        hintText: 'Add a note…',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: Radii.borderMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.borderMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.borderMd,
          borderSide: BorderSide(
            color: accent.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── More Options Toggle ───────────────────────────────────────────────────────

class _MoreOptionsToggle extends StatelessWidget {
  final Color accent;
  final bool showMore;
  final bool hasActiveOptions;
  final VoidCallback onToggle;

  const _MoreOptionsToggle({
    required this.accent,
    required this.showMore,
    required this.hasActiveOptions,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              showMore ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              showMore ? 'Less options' : 'More options',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasActiveOptions) ...[
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
    );
  }
}

// ── More Options Panel ────────────────────────────────────────────────────────

class _MoreOptions extends StatelessWidget {
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
    final theme = Theme.of(context);
    const frequencies = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: [
              ...tags.map(
                (tag) => InputChip(
                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                  onDeleted: () => onTagRemoved(tag),
                  deleteIcon: const Icon(Icons.close, size: 13),
                  shape: RoundedRectangleBorder(borderRadius: Radii.borderFull),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.label_outline, size: 13),
                label: const Text('Tag', style: TextStyle(fontSize: 11)),
                onPressed: () => _addTagDialog(context),
                shape: RoundedRectangleBorder(borderRadius: Radii.borderFull),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),

          // Recurring + Split + Receipt
          Row(
            children: [
              Expanded(
                child: _ToggleTile(
                  icon: FontAwesomeIcons.repeat,
                  label: 'Recurring',
                  value: isRecurring,
                  accent: accent,
                  onChanged: onRecurringChanged,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _ToggleTile(
                  icon: FontAwesomeIcons.peopleLine,
                  label: 'Split',
                  value: isSplit,
                  accent: accent,
                  onChanged: onSplitChanged,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              _ReceiptButton(onTap: onReceiptTap),
            ],
          ),

          // Recurring frequency
          if (isRecurring) ...[
            const SizedBox(height: Spacing.xs),
            Row(
              children: frequencies.map((f) {
                final isSel = recurringFrequency == f;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(f, style: const TextStyle(fontSize: 10)),
                      selected: isSel,
                      onSelected: (s) {
                        if (s) onFrequencyChanged(f);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: Radii.borderFull,
                      ),
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
        shape: RoundedRectangleBorder(borderRadius: Radii.borderLg),
        title: const Text('Add Tag'),
        content: TextField(
          controller: tagController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tag name…'),
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
            child: const Text('Cancel'),
          ),
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
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: value ? accent.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: value
                ? accent.withValues(alpha: 0.45)
                : theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: Radii.borderMd,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              size: 12,
              color: value ? accent : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                color: value ? accent : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReceiptButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: Radii.borderMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.camera,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              'Receipt',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Calculator Numpad ─────────────────────────────────────────────────────────

class _CalcPad extends StatelessWidget {
  final Color accent;
  final bool isSaving;
  final String? pendingOperator;
  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final ValueChanged<String> onOperator;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEvaluate;
  final VoidCallback onConfirm;

  const _CalcPad({
    required this.accent,
    required this.isSaving,
    required this.pendingOperator,
    required this.onDigit,
    required this.onDecimal,
    required this.onOperator,
    required this.onBackspace,
    required this.onClear,
    required this.onEvaluate,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest;
    final fg = theme.colorScheme.onSurface;
    final opBg = theme.colorScheme.secondaryContainer;
    final opFg = theme.colorScheme.onSecondaryContainer;

    // Layout:
    // Row 1: 7  8  9  ÷
    // Row 2: 4  5  6  ×
    // Row 3: 1  2  3  −
    // Row 4: .  0  ⌫  +
    // Row 5: [  =  ] [  confirm (full-width half)  ]

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _calcRow([
            _CalcKey(label: '7', bg: bg, fg: fg, onTap: () => onDigit('7')),
            _CalcKey(label: '8', bg: bg, fg: fg, onTap: () => onDigit('8')),
            _CalcKey(label: '9', bg: bg, fg: fg, onTap: () => onDigit('9')),
            _CalcKey(
              label: '÷',
              bg: pendingOperator == '÷' ? accent.withValues(alpha: 0.2) : opBg,
              fg: pendingOperator == '÷' ? accent : opFg,
              onTap: () => onOperator('÷'),
              fontWeight: FontWeight.w600,
            ),
          ]),
          const SizedBox(height: Spacing.xs),
          _calcRow([
            _CalcKey(label: '4', bg: bg, fg: fg, onTap: () => onDigit('4')),
            _CalcKey(label: '5', bg: bg, fg: fg, onTap: () => onDigit('5')),
            _CalcKey(label: '6', bg: bg, fg: fg, onTap: () => onDigit('6')),
            _CalcKey(
              label: '×',
              bg: pendingOperator == '×' ? accent.withValues(alpha: 0.2) : opBg,
              fg: pendingOperator == '×' ? accent : opFg,
              onTap: () => onOperator('×'),
              fontWeight: FontWeight.w600,
            ),
          ]),
          const SizedBox(height: Spacing.xs),
          _calcRow([
            _CalcKey(label: '1', bg: bg, fg: fg, onTap: () => onDigit('1')),
            _CalcKey(label: '2', bg: bg, fg: fg, onTap: () => onDigit('2')),
            _CalcKey(label: '3', bg: bg, fg: fg, onTap: () => onDigit('3')),
            _CalcKey(
              label: '−',
              bg: pendingOperator == '−' ? accent.withValues(alpha: 0.2) : opBg,
              fg: pendingOperator == '−' ? accent : opFg,
              onTap: () => onOperator('−'),
              fontWeight: FontWeight.w600,
            ),
          ]),
          const SizedBox(height: Spacing.xs),
          _calcRow([
            _CalcKey(
              label: '.',
              bg: bg,
              fg: fg,
              onTap: onDecimal,
              fontWeight: FontWeight.w700,
            ),
            _CalcKey(label: '0', bg: bg, fg: fg, onTap: () => onDigit('0')),
            _CalcKey(
              icon: Icons.backspace_outlined,
              bg: bg,
              fg: fg,
              onTap: onBackspace,
              onLongPress: onClear,
            ),
            _CalcKey(
              label: '+',
              bg: pendingOperator == '+' ? accent.withValues(alpha: 0.2) : opBg,
              fg: pendingOperator == '+' ? accent : opFg,
              onTap: () => onOperator('+'),
              fontWeight: FontWeight.w600,
            ),
          ]),
          const SizedBox(height: Spacing.xs),
          // Bottom row: = (evaluate) | confirm (save)
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _CalcKey(
                    label: '=',
                    bg: theme.colorScheme.surfaceContainerHighest,
                    fg: accent,
                    onTap: onEvaluate,
                    fontWeight: FontWeight.w700,
                    height: 52,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _CalcKey(
                    icon: isSaving ? null : Icons.check_rounded,
                    bg: accent,
                    fg: Colors.white,
                    onTap: onConfirm,
                    height: 52,
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calcRow(List<_CalcKey> keys) {
    return Row(
      children: keys.map((k) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: k,
          ),
        );
      }).toList(),
    );
  }
}

class _CalcKey extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final FontWeight fontWeight;
  final double height;
  final Widget? child;

  const _CalcKey({
    this.label,
    this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.onLongPress,
    this.fontWeight = FontWeight.w500,
    this.height = 50,
    this.child,
  });

  @override
  State<_CalcKey> createState() => _CalcKeyState();
}

class _CalcKeyState extends State<_CalcKey>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: Radii.borderMd,
          ),
          child: Center(
            child:
                widget.child ??
                (widget.icon != null
                    ? Icon(widget.icon, color: widget.fg, size: 22)
                    : Text(
                        widget.label ?? '',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: widget.fontWeight,
                          color: widget.fg,
                        ),
                      )),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Providers
// ═════════════════════════════════════════════════════════════════════════════

final _activeAccountsProvider = FutureProvider<List<AccountModel>>((ref) {
  return ref.watch(accountRepositoryProvider).getActive();
});

final _categoriesByTypeProvider =
    FutureProvider.family<List<CategoryModel>, int>((ref, type) {
      // Transaction types are 0=income,1=expense while category types are
      // 0=expense,1=income. Map before querying categories.
      final categoryType = switch (type) {
        0 => 1,
        1 => 0,
        _ => 2,
      };
      return ref.watch(categoryRepositoryProvider).getByType(categoryType);
    });
