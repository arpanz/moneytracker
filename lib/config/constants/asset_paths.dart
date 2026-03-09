/// Centralized asset path references for the Cheddar app.
///
/// All SVG, Lottie, and image assets are referenced through this class
/// to avoid magic strings and enable compile-time safety.
abstract class AssetPaths {
  // ── Onboarding ──
  static const String onboardingWelcome = 'assets/svg/onboarding/welcome.svg';
  static const String onboardingTrack = 'assets/svg/onboarding/track.svg';
  static const String onboardingInsights = 'assets/svg/onboarding/insights.svg';

  // ── Categories (16) ──
  static const String categoryFood = 'assets/svg/categories/food.svg';
  static const String categoryTransport = 'assets/svg/categories/transport.svg';
  static const String categoryShopping = 'assets/svg/categories/shopping.svg';
  static const String categoryBills = 'assets/svg/categories/bills.svg';
  static const String categoryEntertainment = 'assets/svg/categories/entertainment.svg';
  static const String categoryHealth = 'assets/svg/categories/health.svg';
  static const String categoryEducation = 'assets/svg/categories/education.svg';
  static const String categoryTravel = 'assets/svg/categories/travel.svg';
  static const String categoryGifts = 'assets/svg/categories/gifts.svg';
  static const String categorySalary = 'assets/svg/categories/salary.svg';
  static const String categoryFreelance = 'assets/svg/categories/freelance.svg';
  static const String categoryInvestments = 'assets/svg/categories/investments.svg';
  static const String categoryRent = 'assets/svg/categories/rent.svg';
  static const String categoryGroceries = 'assets/svg/categories/groceries.svg';
  static const String categoryPets = 'assets/svg/categories/pets.svg';
  static const String categorySubscriptions = 'assets/svg/categories/subscriptions.svg';

  // ── Personalities ──
  static const String personalityFoodie = 'assets/svg/personalities/foodie.svg';
  static const String personalityNomad = 'assets/svg/personalities/nomad.svg';
  static const String personalityShopaholic = 'assets/svg/personalities/shopaholic.svg';
  static const String personalitySaver = 'assets/svg/personalities/saver.svg';
  static const String personalityHustler = 'assets/svg/personalities/hustler.svg';

  // ── Empty States ──
  static const String emptyTransactions = 'assets/svg/empty_states/no_transactions.svg';
  static const String emptyGoals = 'assets/svg/empty_states/no_goals.svg';
  static const String emptySubscriptions = 'assets/svg/empty_states/no_subscriptions.svg';
  static const String emptyBudgets = 'assets/svg/empty_states/no_budgets.svg';
  static const String emptySplits = 'assets/svg/empty_states/no_splits.svg';

  // ── Misc ──
  static const String mascot = 'assets/svg/misc/cheddar_mascot.svg';
  static const String goalJar = 'assets/svg/misc/goal_jar.svg';
  static const String walletCrying = 'assets/svg/misc/wallet_crying.svg';
  static const String lockIcon = 'assets/svg/misc/lock.svg';
  static const String successCheck = 'assets/svg/misc/success.svg';
  static const String errorState = 'assets/svg/misc/error.svg';

  // ── Lottie Animations ──
  static const String confetti = 'assets/lottie/confetti.json';
  static const String moneyFlying = 'assets/lottie/money_flying.json';
  static const String liquidFill = 'assets/lottie/liquid_fill.json';
  static const String loading = 'assets/lottie/loading.json';
}
