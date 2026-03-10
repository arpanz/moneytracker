import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/di/providers.dart';
import '../../config/constants/app_constants.dart';
import '../../ui/features/onboarding/screens/onboarding_screen.dart';
import '../../ui/features/lock/screens/lock_screen.dart';
import '../../ui/features/home/screens/home_screen.dart';
import '../../ui/features/transactions/screens/transaction_list_screen.dart';
import '../../ui/features/transactions/screens/add_transaction_screen.dart';
import '../../ui/features/transactions/screens/transaction_detail_screen.dart';
import '../../ui/features/stats/screens/stats_screen.dart';
import '../../ui/features/budget/screens/budget_screen.dart';
import '../../ui/features/budget/screens/budget_detail_screen.dart';
import '../../ui/features/budget/screens/add_budget_screen.dart';
import '../../ui/features/goals/screens/goals_screen.dart';
import '../../ui/features/goals/screens/add_goal_screen.dart';
import '../../ui/features/goals/screens/goal_detail_screen.dart';
import '../../ui/features/subscriptions/screens/subscriptions_screen.dart';
import '../../ui/features/subscriptions/screens/add_subscription_screen.dart';
import '../../ui/features/split/screens/split_screen.dart';
import '../../ui/features/split/screens/add_split_screen.dart';
import '../../ui/features/accounts/screens/accounts_screen.dart';
import '../../ui/features/accounts/screens/add_account_screen.dart';
import '../../ui/features/accounts/screens/account_detail_screen.dart';
import '../../ui/features/settings/screens/settings_screen.dart';
import '../../ui/features/settings/screens/theme_picker_screen.dart';
import '../../ui/features/scanner/screens/scanner_screen.dart';
import '../../ui/features/personality/screens/personality_screen.dart';
import '../../ui/features/personality/screens/weekly_wrap_screen.dart';
import '../../ui/features/notifications/screens/pending_transactions_screen.dart';
import '../../ui/core/shell/app_shell.dart';
import 'route_names.dart';

/// Track whether the user has authenticated through the lock screen
/// in the current app session. Reset on cold start.
bool _isSessionAuthenticated = false;

/// Called by LockScreen after successful authentication.
void markSessionAuthenticated() {
  _isSessionAuthenticated = true;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  return GoRouter(
    initialLocation: '/',
    // FIX: show diagnostics in debug builds only.
    debugLogDiagnostics: kDebugMode,

    redirect: (context, state) {
      final onboardingComplete =
          prefs.getBool(AppConstants.prefOnboardingComplete) ?? false;
      final lockEnabled =
          prefs.getBool(AppConstants.prefAppLockEnabled) ?? false;
      final currentPath = state.uri.path;

      if (!onboardingComplete) {
        if (currentPath == '/') return null;
        return '/';
      }

      if (lockEnabled && !_isSessionAuthenticated) {
        if (currentPath == '/lock') return null;
        return '/lock';
      }

      if (currentPath == '/' || currentPath == '/lock') {
        return '/home';
      }

      return null;
    },

    routes: [
      // ── Onboarding ──
      GoRoute(
        path: '/',
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/lock',
        name: RouteNames.lock,
        builder: (context, state) => const LockScreen(),
      ),

      // ── Main App Shell with Bottom Nav ──
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/transactions',
            name: RouteNames.transactions,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const TransactionListScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/stats',
            name: RouteNames.stats,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const StatsScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/budget',
            name: RouteNames.budget,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const BudgetScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/more',
            name: RouteNames.more,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
        ],
      ),

      // ── Detail / Modal Routes ──

      GoRoute(
        path: '/transaction/add',
        name: RouteNames.addTransaction,
        builder: (context, state) {
          final initialType = state.extra is int ? state.extra as int : null;
          return AddTransactionScreen(initialType: initialType);
        },
      ),
      GoRoute(
        path: '/transaction/:id',
        name: RouteNames.transactionDetail,
        builder: (context, state) {
          // FIX: guard int.parse with tryParse to avoid crash on bad deep-links.
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return const _NotFoundScreen();
          return TransactionDetailScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/budget/add',
        name: RouteNames.addBudget,
        builder: (context, state) => const AddBudgetScreen(),
      ),
      GoRoute(
        path: '/budget/:id',
        name: RouteNames.budgetDetail,
        builder: (context, state) => BudgetDetailScreen(
          budgetId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/goals',
        name: RouteNames.goals,
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: '/goal/add',
        name: RouteNames.addGoal,
        builder: (context, state) => const AddGoalScreen(),
      ),
      GoRoute(
        path: '/goal/:id',
        name: RouteNames.goalDetail,
        builder: (context, state) {
          // FIX: guard int.parse with tryParse.
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return const _NotFoundScreen();
          return GoalDetailScreen(goalId: id);
        },
      ),
      GoRoute(
        path: '/subscriptions',
        name: RouteNames.subscriptions,
        builder: (context, state) => const SubscriptionsScreen(),
      ),
      GoRoute(
        path: '/subscription/add',
        name: RouteNames.addSubscription,
        builder: (context, state) => const AddSubscriptionScreen(),
      ),
      GoRoute(
        path: '/split',
        name: RouteNames.split,
        builder: (context, state) => const SplitScreen(),
      ),
      GoRoute(
        path: '/split/add',
        name: RouteNames.addSplit,
        builder: (context, state) => const AddSplitScreen(),
      ),
      GoRoute(
        path: '/accounts',
        name: RouteNames.accounts,
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        path: '/account/add',
        name: RouteNames.addAccount,
        builder: (context, state) => const AddAccountScreen(),
      ),
      GoRoute(
        path: '/account/:id',
        name: RouteNames.accountDetail,
        builder: (context, state) {
          // FIX: guard int.parse with tryParse.
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return const _NotFoundScreen();
          return AccountDetailScreen(accountId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/themes',
        name: RouteNames.themePicker,
        builder: (context, state) => const ThemePickerScreen(),
      ),
      GoRoute(
        path: '/scanner',
        name: RouteNames.scanner,
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/personality',
        name: RouteNames.personality,
        builder: (context, state) => const PersonalityScreen(),
      ),
      GoRoute(
        path: '/weekly-wrap',
        name: RouteNames.weeklyWrap,
        builder: (context, state) => const WeeklyWrapScreen(),
      ),
      GoRoute(
        path: '/pending-transactions',
        name: RouteNames.pendingTransactions,
        builder: (context, state) => const PendingTransactionsScreen(),
      ),
    ],
  );
});

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(opacity: animation, child: child);
}

/// FIX: Safe fallback screen shown when a path parameter fails to parse.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: const Center(
        child: Text('The requested item could not be found.'),
      ),
    );
  }
}
