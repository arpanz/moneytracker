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
    final selectedTheme = ref.watch(themeProvider).themeName;
    final isListening = ref.watch(isListeningProvider);
    final navItemIds = ref.watch(floatingNavItemIdsProvider);
    final navItems = resolveFloatingNavItems(navItemIds);
    final availableNavItems = kFloatingNavDestinations
        .where((item) => !navItemIds.contains(item.id))
        .toList(growable: false);
    final currency = currencyOptionFor(_currency);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.surface,
              colors.surfaceContainerLow.withValues(alpha: 0.45),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            _SettingsSection(
              title: 'Quick Access',
              subtitle: 'Open frequently used tools in one tap.',
              child: _QuickActionWrap(
                children: [
                  _QuickActionChip(
                    icon: Icons.savings_outlined,
                    label: 'Goals',
                    accent: Colors.amber,
                    onTap: () => context.pushNamed(RouteNames.goals),
                  ),
                  _QuickActionChip(
                    icon: Icons.subscriptions_outlined,
                    label: 'Subscriptions',
                    accent: Colors.deepPurple,
                    onTap: () => context.pushNamed(RouteNames.subscriptions),
                  ),
                  _QuickActionChip(
                    icon: Icons.call_split_rounded,
                    label: 'Splits',
                    accent: Colors.teal,
                    onTap: () => context.pushNamed(RouteNames.split),
                  ),
                  _QuickActionChip(
                    icon: Icons.currency_exchange_rounded,
                    label: 'Loans',
                    accent: Colors.indigo,
                    onTap: () => context.pushNamed(RouteNames.loans),
                  ),
                  _QuickActionChip(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Accounts',
                    accent: Colors.green,
                    onTap: () => context.pushNamed(RouteNames.accounts),
                  ),
                  _QuickActionChip(
                    icon: Icons.pending_actions_outlined,
                    label: 'Pending',
                    accent: Colors.deepOrange,
                    onTap: () =>
                        context.pushNamed(RouteNames.pendingTransactions),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsSection(
              title: 'Preferences',
              subtitle: 'Appearance, currency, and account controls.',
              child: _SettingsPanel(
                children: [
                  _SettingsActionRow(
                    icon: Icons.palette_outlined,
                    title: 'Theme and vibes',
                    subtitle: selectedTheme,
                    accent: colors.primary,
                    onTap: () => context.pushNamed(RouteNames.themePicker),
                  ),
                  const Divider(height: 1),
                  _SettingsActionRow(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Currency',
                    subtitle: '${currency.name} (${currency.code})',
                    accent: Colors.blue,
                    onTap: _showCurrencyPicker,
                  ),
                  const Divider(height: 1),
                  _SettingsActionRow(
                    icon: Icons.receipt_long_rounded,
                    title: 'Transactions',
                    subtitle: 'Browse all entries',
                    accent: Colors.cyan,
                    onTap: () => context.pushNamed(RouteNames.transactions),
                  ),
                  const Divider(height: 1),
                  _SettingsActionRow(
                    icon: Icons.account_balance_rounded,
                    title: 'Manage accounts',
                    subtitle: 'Banks, cards, and wallets',
                    accent: Colors.green,
                    onTap: () => context.pushNamed(RouteNames.accounts),
                  ),
                ],
              ),
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
            _SettingsSection(
              title: 'Security and Alerts',
              subtitle: 'Secure the app and tune smart detection.',
              child: _SettingsPanel(
                children: [
                  _SettingsToggleRow(
                    icon: Icons.fingerprint_rounded,
                    title: 'Biometric lock',
                    subtitle: 'Require fingerprint or face to open app',
                    accent: Colors.deepPurple,
                    value: _biometricEnabled,
                    onChanged: (value) async {
                      final prefs = ref.read(sharedPreferencesProvider);
                      await prefs.setBool(
                        AppConstants.prefAppLockEnabled,
                        value,
                      );
                      setState(() => _biometricEnabled = value);
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsToggleRow(
                    icon: Icons.notifications_outlined,
                    title: 'Push notifications',
                    subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
                    accent: Colors.redAccent,
                    value: _notificationsEnabled,
                    onChanged: _onPushNotificationsToggled,
                  ),
                  const Divider(height: 1),
                  _SettingsToggleRow(
                    icon: Icons.sms_outlined,
                    title: 'Payment reader',
                    subtitle: isListening
                        ? 'Active and auto-detecting payments'
                        : 'Off until you grant access',
                    accent: Colors.orange,
                    value: isListening,
                    onChanged: _onListenerToggled,
                  ),
                  const Divider(height: 1),
                  _SettingsActionRow(
                    icon: Icons.pending_actions_outlined,
                    title: 'Pending transactions',
                    subtitle: 'Review transactions found from alerts',
                    accent: Colors.brown,
                    onTap: () =>
                        context.pushNamed(RouteNames.pendingTransactions),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsSection(
              title: 'Data and Backup',
              subtitle: 'Export, backup, and restore your data.',
              child: _SettingsPanel(
                children: [
                  _SettingsActionRow(
                    icon: Icons.file_download_outlined,
                    title: 'Export transactions',
                    subtitle: 'Download CSV or PDF files',
                    accent: Colors.blueGrey,
                    onTap: _showExportDialog,
                  ),
                  const Divider(height: 1),
                  _SettingsActionRow(
                    icon: Icons.backup_outlined,
                    title: 'Backup and restore',
                    subtitle: 'Create or restore JSON snapshot',
                    accent: Colors.blue,
                    onTap: _showBackupDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsSection(
              title: 'About',
              subtitle: 'Version details and sharing.',
              child: _SettingsPanel(
                children: [
                  _SettingsActionRow(
                    icon: Icons.info_outline_rounded,
                    title: 'About Cheddar',
                    subtitle: 'v${AppConstants.appVersion}',
                    accent: colors.primary,
                    onTap: _showAboutDialog,
                  ),
                  const Divider(height: 1),
                  _SettingsActionRow(
                    icon: Icons.star_outline_rounded,
                    title: 'Rate app',
                    subtitle: 'Play Store link placeholder',
                    accent: Colors.amber,
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  _SettingsActionRow(
                    icon: Icons.share_outlined,
                    title: 'Share app',
                    subtitle: 'Invite friends to try Cheddar',
                    accent: Colors.green,
                    onTap: () {},
                  ),
                ],
              ),
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

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _QuickActionWrap extends StatelessWidget {
  final List<Widget> children;

  const _QuickActionWrap({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
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

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  final List<Widget> children;

  const _SettingsPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _TileIcon(icon: icon, accent: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsActionRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accent: accent,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
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

    return _SettingsSection(
      title: 'Floating Navigation',
      subtitle: 'Pin and reorder up to $kMaxFloatingNavItems tabs.',
      child: _SettingsPanel(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
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
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add more tabs',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Wrap(
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
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
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

class _TileIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _TileIcon({required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Icon(icon, color: accent, size: 20),
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
