import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../providers/onboarding_provider.dart';

/// Full onboarding flow with 4 swipeable pages.
///
/// Pages 1-3 are informational; Page 4 collects user setup data.
/// On completion, preferences are persisted and navigation moves to /home.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  late final TextEditingController _nameController;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricsAvailable = false;

  static const _totalPages = 4;
  static const _supportedCurrencies = ['INR', 'USD', 'EUR', 'GBP'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _nameController = TextEditingController();
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
    } catch (_) {
      // Biometrics unavailable on this device.
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: Durations.medium,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    final notifier = ref.read(onboardingProvider.notifier);
    await notifier.completeOnboarding();
    if (mounted) {
      context.goNamed(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ──
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: state.currentPage < _totalPages - 1 ? 1.0 : 0.0,
                duration: Durations.fast,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: Spacing.sm,
                    right: Spacing.md,
                  ),
                  child: TextButton(
                    onPressed: state.currentPage < _totalPages - 1
                        ? () => _goToPage(_totalPages - 1)
                        : null,
                    child: Text(
                      'Skip',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── PageView ──
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  ref.read(onboardingProvider.notifier).setPage(page);
                },
                children: [
                  _WelcomePage(theme: theme),
                  _TrackPage(theme: theme),
                  _InsightsPage(theme: theme),
                  _SetupPage(
                    theme: theme,
                    nameController: _nameController,
                    biometricsAvailable: _biometricsAvailable,
                    state: state,
                    onNameChanged: (name) {
                      ref.read(onboardingProvider.notifier).setUserName(name);
                    },
                    onCurrencyChanged: (currency) {
                      if (currency != null) {
                        ref
                            .read(onboardingProvider.notifier)
                            .setCurrency(currency);
                      }
                    },
                    onBiometricToggle: () {
                      ref.read(onboardingProvider.notifier).toggleBiometric();
                    },
                  ),
                ],
              ),
            ),

            // ── Page indicator dots ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (index) {
                  final isActive = index == state.currentPage;
                  return AnimatedContainer(
                    duration: Durations.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: Radii.borderFull,
                    ),
                  );
                }),
              ),
            ),

            // ── Next / Get Started button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                0,
                Spacing.lg,
                Spacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (state.currentPage < _totalPages - 1) {
                      _goToPage(state.currentPage + 1);
                    } else {
                      _completeOnboarding();
                    }
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: Radii.borderMd,
                    ),
                  ),
                  child: Text(
                    state.currentPage < _totalPages - 1
                        ? 'Next'
                        : 'Get Started',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 1: Welcome ──────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final ThemeData theme;

  const _WelcomePage({required this.theme});

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      theme: theme,
      svgPath: AssetPaths.mascot,
      svgHeight: 220,
      title: 'Welcome to Cheddar',
      subtitle: 'Your playful money companion',
    );
  }
}

// ── Page 2: Track ────────────────────────────────────────────────────────────

class _TrackPage extends StatelessWidget {
  final ThemeData theme;

  const _TrackPage({required this.theme});

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      theme: theme,
      svgPath: AssetPaths.onboardingTrack,
      svgHeight: 200,
      title: 'Track Everything',
      subtitle: 'Expenses, income, receipts \u2014 all in one place',
    );
  }
}

// ── Page 3: Insights ─────────────────────────────────────────────────────────

class _InsightsPage extends StatelessWidget {
  final ThemeData theme;

  const _InsightsPage({required this.theme});

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      theme: theme,
      svgPath: AssetPaths.onboardingInsights,
      svgHeight: 200,
      title: 'Smart Insights',
      subtitle: 'See where your money goes with beautiful charts',
    );
  }
}

// ── Shared layout for info pages ─────────────────────────────────────────────

class _OnboardingPageLayout extends StatelessWidget {
  final ThemeData theme;
  final String svgPath;
  final double svgHeight;
  final String title;
  final String subtitle;

  const _OnboardingPageLayout({
    required this.theme,
    required this.svgPath,
    required this.svgHeight,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Spacing.horizontalLg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            svgPath,
            height: svgHeight,
          ),
          const SizedBox(height: Spacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: Durations.medium)
          .slideY(
            begin: 0.1,
            end: 0,
            duration: Durations.medium,
            curve: Curves.easeOut,
          ),
    );
  }
}

// ── Page 4: Setup ────────────────────────────────────────────────────────────

class _SetupPage extends StatelessWidget {
  final ThemeData theme;
  final TextEditingController nameController;
  final bool biometricsAvailable;
  final OnboardingState state;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String?> onCurrencyChanged;
  final VoidCallback onBiometricToggle;

  const _SetupPage({
    required this.theme,
    required this.nameController,
    required this.biometricsAvailable,
    required this.state,
    required this.onNameChanged,
    required this.onCurrencyChanged,
    required this.onBiometricToggle,
  });

  static const _currencies = ['INR', 'USD', 'EUR', 'GBP'];
  static const _currencyLabels = {
    'INR': 'INR (Rs.)',
    'USD': 'USD (\$)',
    'EUR': 'EUR (\u20AC)',
    'GBP': 'GBP (\u00A3)',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: Spacing.horizontalLg,
      child: Column(
        children: [
          const SizedBox(height: Spacing.xl),
          Icon(
            Icons.person_outline_rounded,
            size: 72,
            color: colorScheme.primary,
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Let\'s set up',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Just a few quick things',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xl),

          // ── Name input ──
          TextField(
            controller: nameController,
            onChanged: onNameChanged,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Your name',
              hintText: 'e.g. Astral',
              prefixIcon: const Icon(Icons.person_rounded),
              border: OutlineInputBorder(
                borderRadius: Radii.borderMd,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),

          // ── Currency dropdown ──
          DropdownButtonFormField<String>(
            value: state.currency,
            decoration: InputDecoration(
              labelText: 'Currency',
              prefixIcon: const Icon(Icons.currency_exchange_rounded),
              border: OutlineInputBorder(
                borderRadius: Radii.borderMd,
              ),
            ),
            items: _currencies.map((code) {
              return DropdownMenuItem(
                value: code,
                child: Text(_currencyLabels[code] ?? code),
              );
            }).toList(),
            onChanged: onCurrencyChanged,
          ),
          const SizedBox(height: Spacing.md),

          // ── Biometric toggle ──
          if (biometricsAvailable)
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: Radii.borderMd,
              ),
              child: SwitchListTile(
                value: state.biometricEnabled,
                onChanged: (_) => onBiometricToggle(),
                title: Text(
                  'Enable biometric lock',
                  style: theme.textTheme.bodyLarge,
                ),
                subtitle: Text(
                  'Secure the app with fingerprint or face',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                secondary: Icon(
                  Icons.fingerprint_rounded,
                  color: colorScheme.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: Radii.borderMd,
                ),
              ),
            ),
        ],
      )
          .animate()
          .fadeIn(duration: Durations.medium)
          .slideY(
            begin: 0.1,
            end: 0,
            duration: Durations.medium,
            curve: Curves.easeOut,
          ),
    );
  }
}
