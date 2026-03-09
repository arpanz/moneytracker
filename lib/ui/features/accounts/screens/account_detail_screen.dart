import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/account_model.dart';
import '../../../../domain/models/transaction_model.dart';

/// Account detail screen showing balance, recent transactions, and actions.
class AccountDetailScreen extends ConsumerStatefulWidget {
  final String accountId;
  const AccountDetailScreen({super.key, required this.accountId});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  AccountModel? _account;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = int.tryParse(widget.accountId);
    if (id == null) return;

    final accountRepo = ref.read(accountRepositoryProvider);
    final txnRepo = ref.read(transactionRepositoryProvider);

    final account = await accountRepo.getById(id);
    final transactions = await txnRepo.getByAccount(id);

    if (mounted) {
      setState(() {
        _account = account;
        _transactions = transactions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_account == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Account not found')),
      );
    }

    final account = _account!;
    final income = _transactions
        .where((t) => t.type == 0)
        .fold<double>(0, (s, t) => s + t.amount);
    final expenses = _transactions
        .where((t) => t.type == 1)
        .fold<double>(0, (s, t) => s + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _editAccount();
              if (v == 'delete') _deleteAccount();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Balance card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primaryContainer, colors.secondaryContainer],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              children: [
                Text(_accountTypeLabel(account.type),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onPrimaryContainer.withOpacity(0.7))),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '\$${account.balance.toStringAsFixed(2)}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MiniStat(
                      label: 'Income',
                      value: '\$${income.toStringAsFixed(0)}',
                      color: Colors.green,
                    ),
                    Container(width: 1, height: 30,
                        color: colors.onPrimaryContainer.withOpacity(0.2)),
                    _MiniStat(
                      label: 'Expenses',
                      value: '\$${expenses.toStringAsFixed(0)}',
                      color: colors.error,
                    ),
                    Container(width: 1, height: 30,
                        color: colors.onPrimaryContainer.withOpacity(0.2)),
                    _MiniStat(
                      label: 'Transactions',
                      value: '${_transactions.length}',
                      color: colors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),

          const SizedBox(height: AppSpacing.lg),

          // Recent transactions
          Text('Recent Transactions', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),

          if (_transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text('No transactions for this account.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant)),
              ),
            )
          else
            ...List.generate(
              _transactions.take(20).length,
              (i) {
                final txn = _transactions[i];
                final isIncome = txn.type == 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isIncome
                        ? Colors.green.withOpacity(0.15)
                        : colors.errorContainer,
                    child: Icon(
                      isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: isIncome ? Colors.green : colors.error,
                      size: 20,
                    ),
                  ),
                  title: Text(txn.category, style: theme.textTheme.bodyMedium),
                  subtitle: Text(
                    txn.note ?? _formatDate(txn.date),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${isIncome ? '+' : '-'}\$${txn.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isIncome ? Colors.green : colors.error,
                    ),
                  ),
                ).animate(delay: (i * 40).ms)
                    .fadeIn(duration: 200.ms);
              },
            ),
        ],
      ),
    );
  }

  String _accountTypeLabel(int type) {
    switch (type) {
      case 0: return 'Bank Account';
      case 1: return 'Digital Wallet';
      case 2: return 'Credit Card';
      case 3: return 'Cash';
      default: return 'Account';
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _editAccount() {
    // TODO: Navigate to edit screen or show edit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit coming soon')),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will remove the account but keep its transactions. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && _account != null) {
      final repo = ref.read(accountRepositoryProvider);
      await repo.delete(_account!.id);
      if (mounted) context.pop();
    }
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.6))),
      ],
    );
  }
}
