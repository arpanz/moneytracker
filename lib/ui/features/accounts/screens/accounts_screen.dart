import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/currency_catalog.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/account_model.dart';

/// Screen listing all user accounts (bank, wallet, credit card, cash).
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  List<AccountModel> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(accountRepositoryProvider);
    final accounts = await repo.getAll();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appCurrencySymbol = ref.watch(currencySymbolProvider);
    final totalBalance = _accounts.fold<double>(0, (s, a) => s + a.balance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              await context.pushNamed(RouteNames.addAccount);
              _load();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Total balance header
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primaryContainer,
                        colors.secondaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Balance',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onPrimaryContainer.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$appCurrencySymbol${totalBalance.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${_accounts.length} account${_accounts.length != 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onPrimaryContainer.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),

                const SizedBox(height: AppSpacing.lg),

                if (_accounts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No accounts yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Add your first account to start tracking.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(_accounts.length, (i) {
                    final account = _accounts[i];
                    return _AccountCard(
                          account: account,
                          onTap: () async {
                            await context.pushNamed(
                              RouteNames.accountDetail,
                              pathParameters: {'id': account.id.toString()},
                            );
                            _load();
                          },
                        )
                        .animate(delay: (i * 60).ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.05);
                  }),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.pushNamed(RouteNames.addAccount);
          _load();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AccountModel account;
  final VoidCallback onTap;
  const _AccountCard({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final typeIcon = _accountTypeIcon(account.accountType);
    final accountCurrency = currencySymbolFor(account.currency);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Icon(typeIcon, color: colors.onPrimaryContainer, size: 20),
        ),
        title: Text(account.name, style: theme.textTheme.titleSmall),
        subtitle: Text(
          '${_accountTypeLabel(account.accountType)} • ${account.currency}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          '$accountCurrency${account.balance.toStringAsFixed(2)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: account.balance >= 0 ? colors.primary : colors.error,
          ),
        ),
      ),
    );
  }

  IconData _accountTypeIcon(int type) {
    switch (type) {
      case 0:
        return Icons.account_balance_rounded;
      case 1:
        return Icons.account_balance_wallet_rounded;
      case 2:
        return Icons.credit_card_rounded;
      case 3:
        return Icons.money_rounded;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  String _accountTypeLabel(int type) {
    switch (type) {
      case 0:
        return 'Bank Account';
      case 1:
        return 'Digital Wallet';
      case 2:
        return 'Credit Card';
      case 3:
        return 'Cash';
      default:
        return 'Other';
    }
  }
}
