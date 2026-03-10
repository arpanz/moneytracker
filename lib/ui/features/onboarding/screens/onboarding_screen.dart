import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/constants/currency_catalog.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  late final TextEditingController _nameController;
  late final TextEditingController _accountNameController;
  late final TextEditingController _openingBalanceController;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _biometricsAvailable = false;

  static const _totalPages = 7;
  static const _accountTypes = [
    (
      label: 'Bank',
      subtitle: 'Primary bank account',
      value: 0,
      icon: Icons.account_balance_rounded,
    ),
    (
      label: 'Wallet',
      subtitle: 'UPI or digital wallet',
      value: 1,
      icon: Icons.account_balance_wallet_rounded,
    ),
    (
      label: 'Card',
      subtitle: 'Credit card spending',
      value: 2,
      icon: Icons.credit_card_rounded,
    ),
    (
      label: 'Cash',
      subtitle: 'Cash in hand',
      value: 3,
      icon: Icons.payments_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingProvider);
    _pageController = PageController();
    _nameController = TextEditingController(text: state.userName);
    _accountNameController = TextEditingController(text: state.accountName);
    _openingBalanceController = TextEditingController(
      text: state.openingBalance == 0 ? '' : state.openingBalance.toString(),
    );
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _biometricsAvailable = canCheck && isDeviceSupported;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _accountNameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: AppDurations.medium,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _nextPage(OnboardingState state) async {
    if (state.currentPage == _totalPages - 1) {
      await _completeOnboarding();
      return;
    }

    if (state.currentPage == 4) {
      ref
          .read(onboardingProvider.notifier)
          .setUserName(_nameController.text.trim());
    }

    if (state.currentPage == 5) {
      final parsed =
          double.tryParse(_openingBalanceController.text.trim()) ?? 0;
      ref
          .read(onboardingProvider.notifier)
          .setAccountName(_accountNameController.text.trim());
      ref.read(onboardingProvider.notifier).setOpeningBalance(parsed);
    }

    _goToPage(state.currentPage + 1);
  }

  Future<void> _completeOnboarding() async {
    final notifier = ref.read(onboardingProvider.notifier);
    notifier.setUserName(_nameController.text.trim());
    notifier.setAccountName(_accountNameController.text.trim());
    notifier.setOpeningBalance(
      double.tryParse(_openingBalanceController.text.trim()) ?? 0,
    );
    await notifier.completeOnboarding();
    ref.read(currencyCodeProvider.notifier).state = ref
        .read(onboardingProvider)
        .currency;

    if (mounted) {
      context.goNamed(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canSkip = state.currentPage < _totalPages - 2;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (state.currentPage + 1) / _totalPages,
                      minHeight: 8,
                      borderRadius: Radii.borderFull,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    '${state.currentPage + 1}/$_totalPages',
                    style: theme.textTheme.labelMedium,
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: canSkip ? 1 : 0,
                    duration: AppDurations.fast,
                    child: TextButton(
                      onPressed: canSkip
                          ? () => _goToPage(_totalPages - 1)
                          : null,
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  ref.read(onboardingProvider.notifier).setPage(page);
                },
                children: [
                  _FeaturePage(
                    theme: theme,
                    svgPath: AssetPaths.mascot,
                    badge: 'Welcome',
                    title: 'Cheddar keeps your money life in one place.',
                    subtitle:
                        'Track spending, understand patterns, and stay on top of what matters.',
                    bullets: const [
                      'Fast transaction entry',
                      'Clean account-based balances',
                      'Insights without spreadsheet work',
                    ],
                  ),
                  _FeaturePage(
                    theme: theme,
                    svgPath: AssetPaths.onboardingTrack,
                    badge: 'Tracking',
                    title: 'Log expenses, income, and transfers in seconds.',
                    subtitle:
                        'Categories, notes, receipts, and account routing are built into the flow.',
                    bullets: const [
                      'Quick amount entry',
                      'Custom categories',
                      'Receipt attachment support',
                    ],
                  ),
                  _FeaturePage(
                    theme: theme,
                    svgPath: AssetPaths.onboardingInsights,
                    badge: 'Insights',
                    title: 'See where your money actually goes.',
                    subtitle:
                        'Home, stats, budgets, and trends work together so your spending story is obvious.',
                    bullets: const [
                      'Monthly income vs expense',
                      'Category breakdowns',
                      'Recent activity at a glance',
                    ],
                  ),
                  _FeaturePage(
                    theme: theme,
                    svgPath: AssetPaths.onboardingWelcome,
                    badge: 'Features',
                    title: 'Cheddar also helps you build better habits.',
                    subtitle:
                        'You can set budgets, manage subscriptions, review goals, and lock the app when needed.',
                    bullets: const [
                      'Budget alerts and reminders',
                      'Subscription tracking',
                      'Biometric protection',
                    ],
                  ),
                  _PersonalSetupPage(
                    theme: theme,
                    state: state,
                    nameController: _nameController,
                    onNameChanged: (value) {
                      ref.read(onboardingProvider.notifier).setUserName(value);
                    },
                    onCurrencyChanged: (value) {
                      if (value != null) {
                        ref
                            .read(onboardingProvider.notifier)
                            .setCurrency(value);
                      }
                    },
                  ),
                  _AccountSetupPage(
                    theme: theme,
                    state: state,
                    accountNameController: _accountNameController,
                    openingBalanceController: _openingBalanceController,
                    onAccountNameChanged: (value) {
                      ref
                          .read(onboardingProvider.notifier)
                          .setAccountName(value);
                    },
                    onAccountTypeChanged: (value) {
                      ref
                          .read(onboardingProvider.notifier)
                          .setAccountType(value);
                    },
                    onOpeningBalanceChanged: (value) {
                      ref
                          .read(onboardingProvider.notifier)
                          .setOpeningBalance(double.tryParse(value) ?? 0);
                    },
                  ),
                  _ReadyPage(
                    theme: theme,
                    state: state,
                    biometricsAvailable: _biometricsAvailable,
                    onBiometricToggle: () {
                      ref.read(onboardingProvider.notifier).toggleBiometric();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (index) {
                  final isActive = index == state.currentPage;
                  return AnimatedContainer(
                    duration: AppDurations.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.16),
                      borderRadius: Radii.borderFull,
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                0,
                Spacing.lg,
                Spacing.lg,
              ),
              child: Row(
                children: [
                  if (state.currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _goToPage(state.currentPage - 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: Radii.borderMd,
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (state.currentPage > 0) const SizedBox(width: Spacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => _nextPage(state),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: Radii.borderMd,
                        ),
                      ),
                      child: Text(
                        state.currentPage == _totalPages - 1
                            ? 'Finish Setup'
                            : 'Continue',
                      ),
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

class _FeaturePage extends StatelessWidget {
  final ThemeData theme;
  final String svgPath;
  final String badge;
  final String title;
  final String subtitle;
  final List<String> bullets;

  const _FeaturePage({
    required this.theme,
    required this.svgPath,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;

    return Padding(
      padding: Spacing.paddingLg,
      child:
          Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: SvgPicture.asset(svgPath, height: 180),
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: Radii.borderFull,
                    ),
                    child: Text(
                      badge,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  ...bullets.map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: Spacing.sm),
                          Expanded(child: Text(bullet)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              )
              .animate()
              .fadeIn(duration: AppDurations.medium)
              .slideY(
                begin: 0.06,
                end: 0,
                duration: AppDurations.medium,
                curve: Curves.easeOut,
              ),
    );
  }
}

class _PersonalSetupPage extends StatelessWidget {
  final ThemeData theme;
  final OnboardingState state;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String?> onCurrencyChanged;

  const _PersonalSetupPage({
    required this.theme,
    required this.state,
    required this.nameController,
    required this.onNameChanged,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: Spacing.paddingLg,
      child:
          Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Spacing.lg),
                  Text(
                    'Tell Cheddar about you',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'This helps personalize greetings, symbols, and your starting experience.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),
                  TextField(
                    controller: nameController,
                    onChanged: onNameChanged,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Your name',
                      hintText: 'e.g. Aarya',
                      prefixIcon: const Icon(Icons.person_rounded),
                      border: OutlineInputBorder(borderRadius: Radii.borderMd),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: state.currency,
                    decoration: InputDecoration(
                      labelText: 'Preferred currency',
                      prefixIcon: const Icon(Icons.currency_exchange_rounded),
                      border: OutlineInputBorder(borderRadius: Radii.borderMd),
                    ),
                    items: currencyCatalog.map((currency) {
                      return DropdownMenuItem(
                        value: currency.code,
                        child: Text(
                          '${currency.name} (${currency.code})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: onCurrencyChanged,
                  ),
                ],
              )
              .animate()
              .fadeIn(duration: AppDurations.medium)
              .slideY(
                begin: 0.06,
                end: 0,
                duration: AppDurations.medium,
                curve: Curves.easeOut,
              ),
    );
  }
}

class _AccountSetupPage extends StatelessWidget {
  final ThemeData theme;
  final OnboardingState state;
  final TextEditingController accountNameController;
  final TextEditingController openingBalanceController;
  final ValueChanged<String> onAccountNameChanged;
  final ValueChanged<int> onAccountTypeChanged;
  final ValueChanged<String> onOpeningBalanceChanged;

  const _AccountSetupPage({
    required this.theme,
    required this.state,
    required this.accountNameController,
    required this.openingBalanceController,
    required this.onAccountNameChanged,
    required this.onAccountTypeChanged,
    required this.onOpeningBalanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: Spacing.paddingLg,
      child:
          Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Spacing.lg),
                  Text(
                    'Set up your first account',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'This becomes your starting account for balances and new transactions.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  TextField(
                    controller: accountNameController,
                    onChanged: onAccountNameChanged,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Account name',
                      hintText: 'e.g. Main Wallet',
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_rounded,
                      ),
                      border: OutlineInputBorder(borderRadius: Radii.borderMd),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Account type',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  ..._OnboardingScreenState._accountTypes.map((type) {
                    final isSelected = state.accountType == type.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: InkWell(
                        borderRadius: Radii.borderMd,
                        onTap: () => onAccountTypeChanged(type.value),
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          padding: const EdgeInsets.all(Spacing.md),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.08,
                                  )
                                : theme.colorScheme.surfaceContainerLow,
                            borderRadius: Radii.borderMd,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.14),
                                child: Icon(
                                  type.icon,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type.label,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      type.subtitle,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: Spacing.md),
                  TextField(
                    controller: openingBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: onOpeningBalanceChanged,
                    decoration: InputDecoration(
                      labelText: 'Opening balance',
                      hintText: '0.00',
                      prefixIcon: const Icon(Icons.savings_rounded),
                      helperText:
                          'Use a negative value if this starts as debt.',
                      border: OutlineInputBorder(borderRadius: Radii.borderMd),
                    ),
                  ),
                ],
              )
              .animate()
              .fadeIn(duration: AppDurations.medium)
              .slideY(
                begin: 0.06,
                end: 0,
                duration: AppDurations.medium,
                curve: Curves.easeOut,
              ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  final ThemeData theme;
  final OnboardingState state;
  final bool biometricsAvailable;
  final VoidCallback onBiometricToggle;

  const _ReadyPage({
    required this.theme,
    required this.state,
    required this.biometricsAvailable,
    required this.onBiometricToggle,
  });

  @override
  Widget build(BuildContext context) {
    final currency = currencyOptionFor(state.currency);

    return SingleChildScrollView(
      padding: Spacing.paddingLg,
      child:
          Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Spacing.lg),
                  Text(
                    'You are ready to start',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Review the setup before Cheddar creates your starting workspace.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  _SummaryTile(
                    icon: Icons.person_rounded,
                    title: 'Profile',
                    value: state.userName.trim().isEmpty
                        ? 'No name added yet'
                        : state.userName,
                  ),
                  _SummaryTile(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Currency',
                    value: '${currency.name} (${currency.code})',
                  ),
                  _SummaryTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'First account',
                    value:
                        '${state.accountName.trim().isEmpty ? 'Cash' : state.accountName} • ${_OnboardingScreenState._accountTypes.firstWhere((type) => type.value == state.accountType).label}',
                  ),
                  _SummaryTile(
                    icon: Icons.savings_rounded,
                    title: 'Opening balance',
                    value:
                        '${currency.symbol} ${state.openingBalance.toStringAsFixed(2)}',
                  ),
                  if (biometricsAvailable) ...[
                    const SizedBox(height: Spacing.md),
                    SwitchListTile.adaptive(
                      value: state.biometricEnabled,
                      onChanged: (_) => onBiometricToggle(),
                      title: const Text('Enable biometric lock'),
                      subtitle: const Text(
                        'Use fingerprint or face unlock when opening the app.',
                      ),
                      secondary: const Icon(Icons.fingerprint_rounded),
                      shape: RoundedRectangleBorder(
                        borderRadius: Radii.borderMd,
                      ),
                      tileColor: theme.colorScheme.surfaceContainerLow,
                    ),
                  ],
                ],
              )
              .animate()
              .fadeIn(duration: AppDurations.medium)
              .slideY(
                begin: 0.06,
                end: 0,
                duration: AppDurations.medium,
                curve: Curves.easeOut,
              ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: Radii.borderMd,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
