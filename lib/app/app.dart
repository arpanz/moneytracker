import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/router/app_router.dart';
import '../config/theme/app_theme.dart';
import '../config/theme/theme_provider.dart';
import '../ui/features/notifications/providers/notification_provider.dart';

class CheddarApp extends ConsumerWidget {
  const CheddarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Cheddar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(themeState.vibeTheme),
      darkTheme: AppTheme.darkTheme(themeState.vibeTheme),
      themeMode: themeState.themeMode,
      routerConfig: router,
      // FIX: wrap in NotificationBootstrap so the notification listener
      // service is restarted on every app launch if it was previously enabled.
      builder: (context, child) => NotificationBootstrap(child: child!),
    );
  }
}

/// Runs once when the widget tree is first built and auto-starts the
/// notification listener service if it was enabled in a previous session.
///
/// This fixes the core bug where the service was never restarted after an
/// app restart: [isListeningProvider] read the pref as `true` but nobody
/// actually called [NotificationService.initialize()] again.
class NotificationBootstrap extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationBootstrap({super.key, required this.child});

  @override
  ConsumerState<NotificationBootstrap> createState() =>
      _NotificationBootstrapState();
}

class _NotificationBootstrapState
    extends ConsumerState<NotificationBootstrap> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so ref is fully available before we read it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeIfEnabled(ref);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
