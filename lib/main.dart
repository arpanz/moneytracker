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

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize services
  final sharedPreferences = await SharedPreferences.getInstance();
  final databaseService = DatabaseService();
  await databaseService.initialize();

  // FIX: Seed default categories so they're available on first launch.
  // seedDefaults() is a no-op if categories already exist.
  final categoryRepo = CategoryRepository(databaseService);
  await categoryRepo.seedDefaults();

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
