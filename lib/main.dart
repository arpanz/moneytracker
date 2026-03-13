import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/di/providers.dart';
import 'data/local/database_service.dart';
import 'data/repositories/category_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // FIX: Do NOT set SystemUiOverlayStyle at boot with a hardcoded brightness —
  // that caused white status-bar icons on a white background in light theme.
  // Instead we set transparent bars only and let the theme's AppBarTheme
  // (or AnnotatedRegion in each screen) control icon brightness dynamically.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Initialize services
  final sharedPreferences = await SharedPreferences.getInstance();
  final databaseService = DatabaseService();
  await databaseService.initialize();

  // Seed default categories (no-op if already seeded).
  // Run on a microtask so it does not block runApp.
  // The `ref.read` call cannot be used directly in `main` before `ProviderScope` is set up.
  // We will keep the direct instantiation for now, and rename the method.
  final categoryRepo = CategoryRepository(databaseService);
  categoryRepo.seedDefaultsIfEmpty().ignore();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        databaseServiceProvider.overrideWithValue(databaseService),
      ],
      child: const CheddarApp(),
    ),
  );
}
