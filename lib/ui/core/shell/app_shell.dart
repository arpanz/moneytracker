import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/spacing.dart';

/// Data class describing a single bottom navigation tab.
class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}

/// The tabs displayed in the bottom navigation bar.
const List<_NavTab> _tabs = [
  _NavTab(
    label: 'Home',
    icon: FontAwesomeIcons.house,
    activeIcon: FontAwesomeIcons.house,
    path: '/home',
  ),
  _NavTab(
    label: 'Transactions',
    icon: FontAwesomeIcons.arrowRightArrowLeft,
    activeIcon: FontAwesomeIcons.arrowRightArrowLeft,
    path: '/transactions',
  ),
  _NavTab(
    label: 'Stats',
    icon: FontAwesomeIcons.chartPie,
    activeIcon: FontAwesomeIcons.chartPie,
    path: '/stats',
  ),
  _NavTab(
    label: 'Budget',
    icon: FontAwesomeIcons.wallet,
    activeIcon: FontAwesomeIcons.wallet,
    path: '/budget',
  ),
  _NavTab(
    label: 'More',
    icon: FontAwesomeIcons.ellipsis,
    activeIcon: FontAwesomeIcons.ellipsis,
    path: '/more',
  ),
];

/// Main application shell that wraps [ShellRoute] children with a
/// floating-style bottom navigation bar.
///
/// The current tab is derived from the active [GoRouter] location so
/// deep-link navigation and back-button behavior remain consistent.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  /// Resolves the selected tab index from the current GoRouter location.
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  void _onTabTapped(BuildContext context, int index) {
    final current = _currentIndex(context);
    if (index == current) return; // already on this tab
    context.go(_tabs[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: selectedIndex,
        onTap: (index) => _onTabTapped(context, index),
        colorScheme: colorScheme,
      ),
    );
  }
}

/// A floating-style bottom navigation bar with rounded corners,
/// subtle elevation, and an animated selection indicator.
class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ColorScheme colorScheme;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        Spacing.md,
        0,
        Spacing.md,
        Spacing.lg,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.xs,
              vertical: Spacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (index) {
                return _NavBarItem(
                  tab: _tabs[index],
                  isSelected: index == currentIndex,
                  colorScheme: colorScheme,
                  onTap: () => onTap(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single item in the floating navigation bar with animated
/// icon color, label opacity, and a pill-shaped selection indicator.
class _NavBarItem extends StatelessWidget {
  final _NavTab tab;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.tab,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = colorScheme.primary;
    final Color inactiveColor = colorScheme.onSurface.withValues(alpha: 0.40);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // -- Icon --
              AnimatedSwitcher(
                duration: AppDurations.fast,
                child: FaIcon(
                  isSelected ? tab.activeIcon : tab.icon,
                  key: ValueKey<bool>(isSelected),
                  size: 18,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 4),
              // -- Label --
              AnimatedDefaultTextStyle(
                duration: AppDurations.fast,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
