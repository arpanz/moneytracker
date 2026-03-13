/// App-wide constants for the Cheddar money tracker.
abstract class AppConstants {
  static const String appName = 'Cheddar';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String appTagline = 'Your money, your vibe.';

  // Currency defaults
  static const String defaultCurrency = 'INR';
  static const String currencySymbol = 'Rs.';

  // Transaction display
  static const int maxRecentTransactions = 10;
  static const int transactionPageSize = 20;

  // Budget thresholds
  static const double budgetWarningThreshold = 0.8;
  static const double budgetDangerThreshold = 1.0;

  // Rage tap easter egg
  static const int rageTapCount = 5;
  static const Duration rageTapWindow = Duration(seconds: 2);

  // Receipt scanner
  static const int maxReceiptImageSizeKb = 5120;
  static const double receiptConfidenceThreshold = 0.7;

  // Notification listener
  static const List<String> trackedNotificationApps = [
    'com.google.android.apps.messaging',
    'com.whatsapp',
    'com.phonepe.app',
    'net.one97.paytm',
    'com.google.android.apps.nbu.paisa.user',
  ];

  // Goal savings jar
  static const int maxActiveGoals = 10;
  static const double goalMinAmount = 100.0;

  // Split bill
  static const int maxSplitMembers = 20;

  // Animation
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration splashDuration = Duration(seconds: 2);

  // SharedPreferences keys
  static const String prefVibeTheme = 'vibe_theme';
  static const String prefThemeMode = 'theme_mode';
  static const String prefOnboardingComplete = 'onboarding_complete';
  static const String prefAppLockEnabled = 'app_lock_enabled';
  static const String prefDefaultAccount = 'default_account';
  static const String prefCurrency = 'currency';
  static const String prefUserName = 'user_name';
  static const String prefNotificationListener = 'notification_listener';
  static const String prefShowValues = 'show_values';
  static const String prefActiveAccountId = 'active_account_id';
}
