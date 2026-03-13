import 'package:file_picker/file_picker.dart';
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
import '../../../core/shell/floating_nav_config.dart';
import '../../notifications/providers/notification_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _biometricEnabled = false;
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

  Future<void> _refreshNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _notificationsEnabled = status.isGranted);
    }
  }

  Future<void> _refreshListenerStatus() async {
    final service = ref.read(notificationServiceProvider);
    final granted = await service.isPermissionGranted();
    if (!granted) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(AppConstants.prefNotificationListener, false);
      ref.read(isListeningProvider.notifier).state = false;
    }
  }

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
        setState(() => _notificationsEnabled = false);
      }
    } else {
      await openAppSettings();
    }
  }

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
                            'Auto-detect payments from UPI and bank alerts',
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
                const _PermissionPoint(
                  icon: Icons.payment_outlined,
                  title: 'Payment notifications',
                  subtitle: 'Google Pay, PhonePe, Paytm, and bank SMS alerts',
                ),
                const SizedBox(height: 12),
                const _PermissionPoint(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Auto-fills transactions',
                  subtitle:
                      'Amount and merchant are detected and you confirm before saving',
                ),
                const SizedBox(height: 12),
                const _PermissionPoint(
                  icon: Icons.lock_outline_rounded,
                  title: 'Private by design',
                  subtitle:
                      'Nothing leaves your device and no data is uploaded anywhere.',
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
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
                          'Android will open Notification Access settings. Find Cheddar in the list and toggle it on.',
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

  Future<void> _addFloatingNavItem(String id) async {
    final current = [...ref.read(floatingNavItemIdsProvider)];
    if (current.contains(id)) return;
    if (current.length >= kMaxFloatingNavItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Floating nav can show up to 4 items.')),
      );
      return;
    }
    current.add(id);
    await persistFloatingNavItemIds(ref, current);
  }

  Future<void> _removeFloatingNavItem(String id) async {
    final destination = kFloatingNavDestinations.firstWhere(
      (item) => item.id == id,
    );
    if (!destination.removable) return;
    final current = [...ref.read(floatingNavItemIdsProvider)]..remove(id);
    await persistFloatingNavItemIds(ref, current);
  }

  Future<void> _reorderFloatingNavItems(int oldIndex, int newIndex) async {
    final current = [...ref.read(floatingNavItemIdsProvider)];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    await persistFloatingNavItemIds(ref, current);
  }

  Future<void> _setCurrency(
    String value,
    BuildContext bottomSheetContext,
  ) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(AppConstants.prefCurrency, value);
    ref.read(currencyCodeProvider.notifier).state = value;
    setState(() => _currency = value);
    if (bottomSheetContext.mounted) {
      Navigator.pop(bottomSheetContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isListening = ref.watch(isListeningProvider);
    final navItemIds = ref.watch(floatingNavItemIdsProvider);
    final navItems = resolveFloatingNavItems(navItemIds);
    final availableNavItems = kFloatingNavDestinations
        .where((item) => !navItemIds.contains(item.id))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroCard(
              title: 'Everything in one place',
              subtitle:
                  'Tighter controls, faster shortcuts, and a nav bar you can reorganize.',
              trailing: Icon(
                Icons.tune_rounded,
                size: 28,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionHeader(
              title: 'Quick Access',
              subtitle: 'Frequently used screens in a compact grid.',
            ),
            _AdaptiveCardGrid(
              children: [
                _SettingsActionCard(
                  icon: Icons.savings_outlined,
                  title: 'Goals',
                  subtitle: 'Track savings targets',
                  accent: Colors.amber,
                  onTap: () => context.pushNamed(RouteNames.goals),
                ),
                _SettingsActionCard(
                  icon: Icons.subscriptions_outlined,
                  title: 'Subscriptions',
                  subtitle: 'Recurring payments',
                  accent: Colors.purple,
                  onTap: () => context.pushNamed(RouteNames.subscriptions),
                ),
                _SettingsActionCard(
                  icon: Icons.call_split_rounded,
                  title: 'Splits',
                  subtitle: 'Shared expenses',
                  accent: Colors.teal,
                  onTap: () => context.pushNamed(RouteNames.split),
                ),
                _SettingsActionCard(
                  icon: Icons.currency_exchange_rounded,
                  title: 'Loans',
                  subtitle: 'Lendings and borrowings',
                  accent: Colors.indigo,
                  onTap: () => context.pushNamed(RouteNames.loans),
                ),
                _SettingsActionCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Accounts',
                  subtitle: 'Wallets and banks',
                  accent: Colors.green,
                  onTap: () => context.pushNamed(RouteNames.accounts),
                ),
                _SettingsActionCard(
                  icon: Icons.pending_actions_outlined,
                  title: 'Pending',
                  subtitle: 'Review detected alerts',
                  accent: Colors.deepOrange,
                  onTap: () =>
                      context.pushNamed(RouteNames.pendingTransactions),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionHeader(
              title: 'Preferences',
              subtitle: 'Core app controls with a cleaner, denser layout.',
            ),
            _AdaptiveCardGrid(
              children: [
                _SettingsActionCard(
                  icon: Icons.palette_outlined,
                  title: 'Theme and vibes',
                  subtitle: ref.watch(themeProvider).themeName,
                  accent: colors.primary,
                  onTap: () => context.pushNamed(RouteNames.themePicker),
                ),
                _SettingsActionCard(
                  icon: Icons.currency_exchange_rounded,
                  title: 'Currency',
                  subtitle: '${currencyOptionFor(_currency).name} ($_currency)',
                  accent: Colors.blue,
                  onTap: _showCurrencyPicker,
                ),
                _SettingsActionCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Activity',
                  subtitle: 'Browse all transactions',
                  accent: Colors.cyan,
                  onTap: () => context.pushNamed(RouteNames.transactions),
                ),
                _SettingsActionCard(
                  icon: Icons.account_balance_rounded,
                  title: 'Manage accounts',
                  subtitle: 'Banks, cards, wallets',
                  accent: Colors.green,
                  onTap: () => context.pushNamed(RouteNames.accounts),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _FloatingNavEditorCard(
              items: navItems,
              availableItems: availableNavItems,
              onAdd: _addFloatingNavItem,
              onRemove: _removeFloatingNavItem,
              onReorder: _reorderFloatingNavItems,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionHeader(
              title: 'Security and Alerts',
              subtitle: 'Lock access and manage the notification pipeline.',
            ),
            _AdaptiveCardGrid(
              children: [
                _SettingsToggleCard(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric lock',
                  subtitle: 'Require fingerprint or face to open the app.',
                  accent: Colors.deepPurple,
                  value: _biometricEnabled,
                  onChanged: (value) async {
                    final prefs = ref.read(sharedPreferencesProvider);
                    await prefs.setBool(AppConstants.prefAppLockEnabled, value);
                    setState(() => _biometricEnabled = value);
                  },
                ),
                _SettingsToggleCard(
                  icon: Icons.notifications_outlined,
                  title: 'Push notifications',
                  subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
                  accent: Colors.redAccent,
                  value: _notificationsEnabled,
                  onChanged: _onPushNotificationsToggled,
                ),
                _SettingsToggleCard(
                  icon: Icons.sms_outlined,
                  title: 'Payment reader',
                  subtitle: isListening
                      ? 'Active and auto-detecting payments'
                      : 'Off until you grant access',
                  accent: Colors.orange,
                  value: isListening,
                  onChanged: _onListenerToggled,
                ),
                _SettingsActionCard(
                  icon: Icons.pending_actions_outlined,
                  title: 'Pending transactions',
                  subtitle: 'Approve transactions found from alerts.',
                  accent: Colors.brown,
                  onTap: () =>
                      context.pushNamed(RouteNames.pendingTransactions),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionHeader(
              title: 'Data and Backup',
              subtitle:
                  'Export, back up, and restore without digging through lists.',
            ),
            _AdaptiveCardGrid(
              children: [
                _SettingsActionCard(
                  icon: Icons.file_download_outlined,
                  title: 'Export transactions',
                  subtitle: 'CSV or PDF output',
                  accent: Colors.blueGrey,
                  onTap: _showExportDialog,
                ),
                _SettingsActionCard(
                  icon: Icons.backup_outlined,
                  title: 'Backup and restore',
                  subtitle: 'JSON snapshot of all app data',
                  accent: Colors.blue,
                  onTap: _showBackupDialog,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionHeader(
              title: 'About',
              subtitle: 'Version details and app metadata.',
            ),
            _AdaptiveCardGrid(
              children: [
                _SettingsActionCard(
                  icon: Icons.info_outline_rounded,
                  title: 'About Cheddar',
                  subtitle: 'v${AppConstants.appVersion}',
                  accent: colors.primary,
                  onTap: _showAboutDialog,
                ),
                _SettingsActionCard(
                  icon: Icons.star_outline_rounded,
                  title: 'Rate app',
                  subtitle: 'Play Store link placeholder',
                  accent: Colors.amber,
                  onTap: () {},
                ),
                _SettingsActionCard(
                  icon: Icons.share_outlined,
                  title: 'Share app',
                  subtitle: 'Invite friends to try Cheddar',
                  accent: Colors.green,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
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
          ],
        ),
      ),
    );
  }

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
                                await _setCurrency(value, ctx);
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
          'Choose a format to export your transactions. The file will be saved to your Downloads folder.',
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
        title: const Text('Backup and Restore'),
        content: const Text(
          'Create a JSON backup of all your data or restore from a previous backup file.',
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
          'Cheddar is a personal finance tracker built with Flutter. It helps you track expenses, set budgets, and keep your money organized.',
        ),
      ],
    );
  }

  Future<void> _exportData(String format) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Exporting as $format...')));
  }

  Future<void> _createBackup() async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      scaffold.showSnackBar(
        const SnackBar(content: Text('Creating backup...')),
      );
      await ref.read(exportServiceProvider).shareBackup();
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _restoreBackup() async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Cheddar backup file',
      );
      if (result == null || result.files.single.path == null) return;

      scaffold.showSnackBar(
        const SnackBar(content: Text('Restoring backup...')),
      );
      final counts = await ref
          .read(exportServiceProvider)
          .restoreFromBackup(result.files.single.path!);

      final total = counts.values.fold(0, (a, b) => a + b);
      if (mounted) {
        scaffold.showSnackBar(
          SnackBar(content: Text('Restored $total items successfully.')),
        );
      }
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer.withValues(alpha: 0.9),
            colors.surfaceContainerHighest.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          trailing,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveCardGrid extends StatelessWidget {
  final List<Widget> children;

  const _AdaptiveCardGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        final columns = isWide ? 3 : 2;
        final spacing = AppSpacing.sm;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _SettingsActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _SettingsActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsCardFrame(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardIcon(icon: icon, accent: accent),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsCardFrame(
      onTap: () => onChanged(!value),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardIcon(icon: icon, accent: accent),
              const Spacer(),
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavEditorCard extends StatelessWidget {
  final List<FloatingNavDestination> items;
  final List<FloatingNavDestination> availableItems;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  const _FloatingNavEditorCard({
    required this.items,
    required this.availableItems,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardIcon(
                icon: Icons.dashboard_customize_rounded,
                accent: colors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Floating nav bar',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Reorder pinned screens, remove extras, or add up to $kMaxFloatingNavItems items.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final item = items[index];
                return _PinnedNavTile(
                  key: ValueKey(item.id),
                  index: index,
                  destination: item,
                  onRemove: item.removable ? () => onRemove(item.id) : null,
                );
              },
            ),
          ),
          if (availableItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Add items',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final item in availableItems)
                  ActionChip(
                    avatar: Icon(
                      navSettingsIconFor(item.id),
                      size: 18,
                      color: colors.primary,
                    ),
                    label: Text(item.label),
                    onPressed: () => onAdd(item.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PinnedNavTile extends StatelessWidget {
  final int index;
  final FloatingNavDestination destination;
  final VoidCallback? onRemove;

  const _PinnedNavTile({
    super.key,
    required this.index,
    required this.destination,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            navSettingsIconFor(destination.id),
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              destination.label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Remove from floating nav',
            ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.xs),
              child: Icon(Icons.drag_handle_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCardFrame extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _SettingsCardFrame({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 156),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CardIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _CardIcon({required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Icon(icon, color: accent, size: 22),
    );
  }
}

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
          child: Icon(icon, size: 18, color: theme.colorScheme.secondary),
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
