import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../config/constants/currency_catalog.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../config/theme/theme_provider.dart';
import '../../notifications/providers/notification_provider.dart';

/// Main settings / "More" screen with all app configuration options.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _biometricEnabled = false;
  // Push notifications: live permission status, not just a pref
  bool _notificationsEnabled = false;
  String _currency = 'INR';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _refreshNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check permissions when user comes back from system settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationPermission();
      _refreshListenerStatus();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _biometricEnabled =
          prefs.getBool(AppConstants.prefAppLockEnabled) ?? false;
      _currency =
          prefs.getString(AppConstants.prefCurrency) ??
          AppConstants.defaultCurrency;
    });
  }

  /// Read the REAL OS-level notification permission status.
  Future<void> _refreshNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _notificationsEnabled = status.isGranted);
    }
  }

  /// Re-sync the listener toggle with the service's actual state.
  Future<void> _refreshListenerStatus() async {
    final service = ref.read(notificationServiceProvider);
    final granted = await service.isPermissionGranted();
    if (!granted) {
      // Permission was revoked in system settings — update state
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(AppConstants.prefNotificationListener, false);
      ref.read(isListeningProvider.notifier).state = false;
    }
  }

  // ── Push Notifications toggle ──────────────────────────────────────────

  Future<void> _onPushNotificationsToggled(bool enable) async {
    if (enable) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        setState(() => _notificationsEnabled = true);
      } else if (status.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Notification permission is blocked. Enable it in Settings.',
            ),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: openAppSettings,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _notificationsEnabled = false);
      } else {
        // Denied but not permanently — just reflect reality
        setState(() => _notificationsEnabled = false);
      }
    } else {
      // Can't programmatically revoke — open settings for the user
      await openAppSettings();
    }
  }

  // ── Notification Listener (SMS/bank alerts) toggle ─────────────────────

  Future<void> _onListenerToggled(bool enable) async {
    if (enable) {
      await _showListenerExplanationSheet();
    } else {
      stopListening(ref);
    }
  }

  Future<void> _showListenerExplanationSheet() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable Notification Reader',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Auto-detect payments from UPI & bank alerts',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // What it reads
                _PermissionPoint(
                  icon: Icons.payment_outlined,
                  title: 'Payment notifications',
                  subtitle:
                      'Google Pay, PhonePe, Paytm, and bank SMS alerts',
                ),
                const SizedBox(height: 12),
                _PermissionPoint(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Auto-fills transactions',
                  subtitle:
                      'Amount and merchant are detected — you confirm before saving',
                ),
                const SizedBox(height: 12),
                _PermissionPoint(
                  icon: Icons.lock_outline_rounded,
                  title: 'Private by design',
                  subtitle:
                      'Nothing leaves your device. No data is uploaded anywhere.',
                ),

                const SizedBox(height: 8),

                // Note about system settings
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Android will open Notification Access settings. '  
                          'Find Cheddar in the list and toggle it on.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Enable'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      await startListening(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isListening = ref.watch(isListeningProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          // ── Quick Links ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth =
                    (constraints.maxWidth - (AppSpacing.sm * 3)) / 4;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _QuickLink(
                        icon: Icons.savings_outlined,
                        label: 'Goals',
                        color: Colors.amber,
                        onTap: () => context.pushNamed(RouteNames.goals),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _QuickLink(
                        icon: Icons.subscriptions_outlined,
                        label: 'Subscriptions',
                        color: Colors.purple,
                        onTap: () =>
                            context.pushNamed(RouteNames.subscriptions),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _QuickLink(
                        icon: Icons.call_split_rounded,
                        label: 'Splits',
                        color: Colors.teal,
                        onTap: () => context.pushNamed(RouteNames.split),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _QuickLink(
                        icon: Icons.currency_exchange_rounded,
                        label: 'Loans',
                        color: Colors.indigo,
                        onTap: () => context.pushNamed(RouteNames.loans),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _QuickLink(
                        icon: Icons.psychology_outlined,
                        label: 'Personality',
                        color: Colors.deepOrange,
                        onTap: () => context.pushNamed(RouteNames.personality),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: AppSpacing.lg),

          // ── Appearance ──
          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme & Vibes'),
            subtitle: Text(
              ref.watch(themeProvider).themeName,
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.pushNamed(RouteNames.themePicker),
          ),

          // ── Currency ──
          _SectionHeader(title: 'General'),
          ListTile(
            leading: const Icon(Icons.currency_exchange_rounded),
            title: const Text('Currency'),
            subtitle: Text('${currencyOptionFor(_currency).name} ($_currency)'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showCurrencyPicker(),
          ),

          // ── Security ──
          _SectionHeader(title: 'Security'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint_rounded),
            title: const Text('Biometric Lock'),
            subtitle: const Text('Require fingerprint or face to open app'),
            value: _biometricEnabled,
            onChanged: (v) async {
              final prefs = ref.read(sharedPreferencesProvider);
              await prefs.setBool(AppConstants.prefAppLockEnabled, v);
              setState(() => _biometricEnabled = v);
            },
          ),

          // ── Notifications ──
          _SectionHeader(title: 'Notifications'),

          // Push notifications — requests OS permission via permission_handler
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Push Notifications'),
            subtitle: Text(
              _notificationsEnabled ? 'Enabled' : 'Disabled',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _notificationsEnabled
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
            value: _notificationsEnabled,
            onChanged: _onPushNotificationsToggled,
          ),

          // Notification listener — reads payment/bank notifications
          SwitchListTile(
            secondary: const Icon(Icons.sms_outlined),
            title: const Text('Payment Notification Reader'),
            subtitle: Text(
              isListening
                  ? 'Active — auto-detecting payments'
                  : 'Off — tap to enable',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isListening
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
            value: isListening,
            onChanged: _onListenerToggled,
          ),

          // View detected pending transactions
          ListTile(
            leading: const Icon(Icons.pending_actions_outlined),
            title: const Text('Pending Transactions'),
            subtitle: const Text('Review transactions detected from alerts'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.pushNamed(RouteNames.pendingTransactions),
          ),

          // ── Accounts ──
          _SectionHeader(title: 'Accounts'),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Manage Accounts'),
            subtitle: const Text('Bank accounts, wallets, credit cards'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.pushNamed(RouteNames.accounts),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange_rounded),
            title: const Text('Loan Tracker'),
            subtitle: const Text('Track lendings and borrowings'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.pushNamed(RouteNames.loans),
          ),

          // ── Data ──
          _SectionHeader(title: 'Data & Backup'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export Transactions'),
            subtitle: const Text('CSV or PDF format'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showExportDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & Restore'),
            subtitle: const Text('JSON backup of all app data'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showBackupDialog(),
          ),

          // ── About ──
          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About Cheddar'),
            subtitle: Text('v${AppConstants.appVersion}'),
            onTap: () => _showAboutDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline_rounded),
            title: const Text('Rate on Play Store'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share with Friends'),
            onTap: () {},
          ),

          const SizedBox(height: AppSpacing.xxl),

          Center(
            child: Column(
              children: [
                Text(
                  'Made with cheese in India',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Cheddar v${AppConstants.appVersion}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var query = '';
        return FractionallySizedBox(
          heightFactor: 0.84,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final filtered = currencyCatalog.where((currency) {
                final normalized = query.trim().toLowerCase();
                if (normalized.isEmpty) return true;
                return currency.code.toLowerCase().contains(normalized) ||
                    currency.name.toLowerCase().contains(normalized) ||
                    currency.symbol.toLowerCase().contains(normalized);
              }).toList();

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    top: AppSpacing.md,
                    bottom:
                        MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Select Currency',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Text(
                            '${filtered.length} options',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        onChanged: (value) {
                          setModalState(() => query = value);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search by code, name, or symbol',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            final currency = filtered[index];
                            final isSelected = currency.code == _currency;
                            return RadioListTile<String>(
                              value: currency.code,
                              groupValue: _currency,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              secondary: _CurrencyBadge(currency: currency),
                              title: Text(currency.name),
                              subtitle: Text(
                                '${currency.code} • ${currency.symbol}',
                              ),
                              selected: isSelected,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                              onChanged: (value) async {
                                if (value == null) return;
                                final prefs =
                                    ref.read(sharedPreferencesProvider);
                                await prefs.setString(
                                  AppConstants.prefCurrency,
                                  value,
                                );
                                ref
                                    .read(currencyCodeProvider.notifier)
                                    .state = value;
                                setState(() => _currency = value);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Transactions'),
        content: const Text(
          'Choose a format to export your transactions. '
          'The file will be saved to your Downloads folder.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportData('csv');
            },
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportData('pdf');
            },
            child: const Text('PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup & Restore'),
        content: const Text(
          'Create a JSON backup of all your data, '
          'or restore from a previous backup file.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createBackup();
            },
            child: const Text('Create Backup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restoreBackup();
            },
            child: const Text('Restore'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Cheddar',
      applicationVersion: AppConstants.appVersion,
      applicationLegalese: 'Track your money like it matters.',
      children: [
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Cheddar is a personal finance tracker built with '
          'Flutter. It helps you track expenses, set budgets, '
          'and understand your spending personality.',
        ),
      ],
    );
  }

  Future<void> _exportData(String format) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting as $format...')),
    );
  }

  Future<void> _createBackup() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating backup...')),
    );
  }

  Future<void> _restoreBackup() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select a backup file...')),
    );
  }
}

// ── Permission Explanation Point ────────────────────────────────────────────

class _PermissionPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermissionPoint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Quick Link Card ──────────────────────────────────────────────────────────

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  final CurrencyOption currency;
  const _CurrencyBadge({required this.currency});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        currency.symbol,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
      ),
    );
  }
}
