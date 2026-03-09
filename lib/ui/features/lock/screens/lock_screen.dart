import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../config/constants/asset_paths.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../providers/lock_provider.dart' as app_lock;

/// Biometric authentication screen displayed when app lock is enabled.
///
/// Auto-triggers authentication on mount. On success, navigates to /home.
/// On failure, shows a "Try again" button with a shake animation.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  String _userName = '';
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadUserName();
  }

  void _loadUserName() {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _userName = prefs.getString(AppConstants.prefUserName) ?? '';
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasTriggered) {
      _hasTriggered = true;
      // Slight delay so the screen is fully rendered before biometric prompt.
      Future.delayed(const Duration(milliseconds: 400), _triggerAuth);
    }
  }

  Future<void> _triggerAuth() async {
    final notifier = ref.read(app_lock.lockProvider.notifier);
    final available = await notifier.checkBiometricAvailability();
    if (!available) {
      // Biometrics not available -- navigate straight through.
      if (mounted) context.goNamed(RouteNames.home);
      return;
    }
    await notifier.authenticate();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(app_lock.lockProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Navigate to home on successful authentication.
    ref.listen<app_lock.LockState>(app_lock.lockProvider, (previous, next) {
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        context.goNamed(RouteNames.home);
      }
      if (next.error != null && previous?.error == null) {
        _shakeController.forward(from: 0);
      }
    });

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withValues(alpha: 0.7),
              colorScheme.surface,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Lock icon with pulse animation ──
              _ShakeWidget(
                controller: _shakeController,
                child:
                    SvgPicture.asset(
                          AssetPaths.lockIcon,
                          height: 120,
                          colorFilter: ColorFilter.mode(
                            colorScheme.onPrimary,
                            BlendMode.srcIn,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.06, 1.06),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeInOut,
                        ),
              ),

              const SizedBox(height: Spacing.xl),

              // ── Welcome text ──
              Text(
                'Welcome back${_userName.isNotEmpty ? ', $_userName' : ''}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Authenticate to continue',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
              ),

              const Spacer(),

              // ── Error / Try again section ──
              if (state.error != null) ...[
                Text(
                  state.error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.md),
                FilledButton.icon(
                      onPressed: state.isAuthenticating ? null : _triggerAuth,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Try Again'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.onPrimary,
                        foregroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: Radii.borderMd,
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: AppDurations.fast)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.0, 1.0),
                      duration: AppDurations.fast,
                    ),
              ],

              if (state.isAuthenticating)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.md),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),

              const Spacer(),

              // ── PIN fallback ──
              TextButton(
                onPressed: () {
                  // PIN screen would be added in a future iteration.
                  // For now, attempt biometric auth as fallback.
                  _triggerAuth();
                },
                child: Text(
                  'Use PIN instead',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.7),
                    decoration: TextDecoration.underline,
                    decorationColor: colorScheme.onPrimary.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shake animation widget ───────────────────────────────────────────────────────

class _ShakeWidget extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _ShakeWidget({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final sineValue = _shakeTween.evaluate(controller);
        return Transform.translate(offset: Offset(sineValue, 0), child: child);
      },
      child: child,
    );
  }

  static final _shakeTween = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 8, end: -4), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
  ]);
}
