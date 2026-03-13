import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/di/providers.dart';
import '../../../config/constants/app_constants.dart';

class FloatingNavDestination {
  final String id;
  final String label;
  final String path;
  final FaIconData icon;
  final FaIconData activeIcon;
  final bool removable;

  const FloatingNavDestination({
    required this.id,
    required this.label,
    required this.path,
    required this.icon,
    required this.activeIcon,
    this.removable = true,
  });
}

const int kMaxFloatingNavItems = 4;
const int kMinFloatingNavItems = 2;

const List<FloatingNavDestination> kFloatingNavDestinations = [
  FloatingNavDestination(
    id: 'home',
    label: 'Home',
    path: '/home',
    icon: FontAwesomeIcons.house,
    activeIcon: FontAwesomeIcons.house,
    removable: false,
  ),
  FloatingNavDestination(
    id: 'stats',
    label: 'Stats',
    path: '/stats',
    icon: FontAwesomeIcons.chartPie,
    activeIcon: FontAwesomeIcons.chartPie,
  ),
  FloatingNavDestination(
    id: 'budget',
    label: 'Budget',
    path: '/budget',
    icon: FontAwesomeIcons.wallet,
    activeIcon: FontAwesomeIcons.wallet,
  ),
  FloatingNavDestination(
    id: 'transactions',
    label: 'Activity',
    path: '/transactions',
    icon: FontAwesomeIcons.receipt,
    activeIcon: FontAwesomeIcons.receipt,
  ),
  FloatingNavDestination(
    id: 'goals',
    label: 'Goals',
    path: '/goals',
    icon: FontAwesomeIcons.bullseye,
    activeIcon: FontAwesomeIcons.bullseye,
  ),
  FloatingNavDestination(
    id: 'accounts',
    label: 'Accounts',
    path: '/accounts',
    icon: FontAwesomeIcons.landmark,
    activeIcon: FontAwesomeIcons.landmark,
  ),
  FloatingNavDestination(
    id: 'loans',
    label: 'Loans',
    path: '/loans',
    icon: FontAwesomeIcons.handHoldingDollar,
    activeIcon: FontAwesomeIcons.handHoldingDollar,
  ),
  FloatingNavDestination(
    id: 'subscriptions',
    label: 'Subs',
    path: '/subscriptions',
    icon: FontAwesomeIcons.arrowsRotate,
    activeIcon: FontAwesomeIcons.arrowsRotate,
  ),
  FloatingNavDestination(
    id: 'split',
    label: 'Split',
    path: '/split',
    icon: FontAwesomeIcons.users,
    activeIcon: FontAwesomeIcons.users,
  ),
  FloatingNavDestination(
    id: 'more',
    label: 'More',
    path: '/more',
    icon: FontAwesomeIcons.ellipsis,
    activeIcon: FontAwesomeIcons.ellipsis,
    removable: false,
  ),
];

const List<String> _defaultFloatingNavItemIds = [
  'home',
  'stats',
  'budget',
  'more',
];

final Map<String, FloatingNavDestination> _destinationById = {
  for (final destination in kFloatingNavDestinations)
    destination.id: destination,
};

List<String> loadFloatingNavItemIds(SharedPreferences prefs) {
  final stored = prefs.getStringList(AppConstants.prefFloatingNavItems);
  return normalizeFloatingNavItemIds(stored ?? _defaultFloatingNavItemIds);
}

List<FloatingNavDestination> resolveFloatingNavItems(List<String> ids) {
  return normalizeFloatingNavItemIds(
    ids,
  ).map((id) => _destinationById[id]!).toList(growable: false);
}

List<String> normalizeFloatingNavItemIds(List<String> ids) {
  final normalized = <String>[];

  for (final id in ids) {
    if (_destinationById.containsKey(id) && !normalized.contains(id)) {
      normalized.add(id);
    }
  }

  for (final requiredId in const ['home', 'more']) {
    if (!normalized.contains(requiredId)) {
      normalized.add(requiredId);
    }
  }

  while (normalized.length > kMaxFloatingNavItems) {
    final removableIndex = normalized.lastIndexWhere((id) {
      return _destinationById[id]?.removable ?? false;
    });
    if (removableIndex == -1) {
      break;
    }
    normalized.removeAt(removableIndex);
  }

  for (final fallbackId in _defaultFloatingNavItemIds) {
    if (normalized.length >= kMinFloatingNavItems) {
      break;
    }
    if (!normalized.contains(fallbackId)) {
      normalized.add(fallbackId);
    }
  }

  return normalized;
}

Future<void> persistFloatingNavItemIds(WidgetRef ref, List<String> ids) async {
  final normalized = normalizeFloatingNavItemIds(ids);
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.setStringList(AppConstants.prefFloatingNavItems, normalized);
  ref.read(floatingNavItemIdsProvider.notifier).state = normalized;
}

final floatingNavItemIdsProvider = StateProvider<List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return loadFloatingNavItemIds(prefs);
});

IconData navSettingsIconFor(String id) {
  return switch (id) {
    'home' => Icons.home_rounded,
    'stats' => Icons.pie_chart_rounded,
    'budget' => Icons.account_balance_wallet_rounded,
    'transactions' => Icons.receipt_long_rounded,
    'goals' => Icons.flag_rounded,
    'accounts' => Icons.account_balance_rounded,
    'loans' => Icons.currency_exchange_rounded,
    'subscriptions' => Icons.subscriptions_rounded,
    'split' => Icons.call_split_rounded,
    'more' => Icons.tune_rounded,
    _ => Icons.circle_rounded,
  };
}
