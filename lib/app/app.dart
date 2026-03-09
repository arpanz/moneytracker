import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/router/app_router.dart';
import '../config/theme/app_theme.dart';
import '../config/theme/theme_provider.dart';

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
    );
  }
}
