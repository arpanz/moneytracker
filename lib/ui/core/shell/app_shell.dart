import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../config/router/route_names.dart';
import '../../../config/theme/spacing.dart';

class _NavTab {
  final String label;
  final FaIconData icon;
  final FaIconData activeIcon;
  final String path;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}

// 4 real tabs + a centre placeholder slot for the FAB
const List<_NavTab> _tabs = [
  _NavTab(
    label: 'Home',
    icon: FontAwesomeIcons.house,
    activeIcon: FontAwesomeIcons.house,
    path: '/home',
  ),
  _NavTab(
    label: 'Stats',
    icon: FontAwesomeIcons.chartPie,
    activeIcon: FontAwesomeIcons.chartPie,
    path: '/stats',
  ),
  // index 2 is reserved for the centre FAB — no real tab
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

const double kFloatingNavBarHeight = 80.0;

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  bool _fabOpen = false;

  late final AnimationController _fabController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  late final Animation<double> _fabScale = CurvedAnimation(
    parent: _fabController,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );

  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    _fabOpen ? _fabController.forward() : _fabController.reverse();
  }

  void _closeFab() {
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      _fabController.reverse();
    }
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  void _onTabTapped(BuildContext context, int tabIndex) {
    _closeFab();
    final current = _currentIndex(context);
    if (tabIndex == current) return;
    context.go(_tabs[tabIndex].path);
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedIndex = _currentIndex(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: false,
      body: GestureDetector(
        onTap: _closeFab,
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // ── Floating pill nav bar ──
          _FloatingNavBar(
            currentIndex: selectedIndex,
            onTap: (i) => _onTabTapped(context, i),
            colorScheme: colorScheme,
            bottomInset: bottomInset,
            onFabTap: _toggleFab,
            fabOpen: _fabOpen,
            fabController: _fabController,
          ),

          // ── Circular action popup ──
          AnimatedBuilder(
            animation: _fabScale,
            builder: (_, __) => _fabScale.value == 0
                ? const SizedBox.shrink()
                : Positioned(
                    bottom: kFloatingNavBarHeight +
                        bottomInset +
                        Spacing.lg +
                        Spacing.sm,
                    child: _FabPopup(
                      scale: _fabScale.value,
                      colorScheme: colorScheme,
                      onAddExpense: () {
                        _closeFab();
                        context.pushNamed(RouteNames.addTransaction,
                            extra: 1);
                      },
                      onAddIncome: () {
                        _closeFab();
                        context.pushNamed(RouteNames.addTransaction,
                            extra: 0);
                      },
                      onScanReceipt: () {
                        _closeFab();
                        context.pushNamed(RouteNames.scanner);
                      },
                      onTransfer: () {
                        _closeFab();
                        context.pushNamed(RouteNames.addTransaction,
                            extra: 2);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ══ Circular FAB Popup ═══════════════════════════════════════════════════

class _FabPopup extends StatelessWidget {
  final double scale;
  final ColorScheme colorScheme;
  final VoidCallback onAddExpense;
  final VoidCallback onAddIncome;
  final VoidCallback onScanReceipt;
  final VoidCallback onTransfer;

  const _FabPopup({
    required this.scale,
    required this.colorScheme,
    required this.onAddExpense,
    required this.onAddIncome,
    required this.onScanReceipt,
    required this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    // 4 actions arranged in a semicircle arc above the + button
    const radius = 88.0;
    const actions = [
      _FabAction(
        label: 'Expense',
        icon: Icons.remove_rounded,
        colorLight: Color(0xFFEF4444),
        colorDark: Color(0xFFF87171),
        angleDeg: 135,
      ),
      _FabAction(
        label: 'Income',
        icon: Icons.add_rounded,
        colorLight: Color(0xFF16A34A),
        colorDark: Color(0xFF4ADE80),
        angleDeg: 90,
      ),
      _FabAction(
        label: 'Transfer',
        icon: Icons.swap_horiz_rounded,
        colorLight: Color(0xFF2563EB),
        colorDark: Color(0xFF60A5FA),
        angleDeg: 45,
      ),
      _FabAction(
        label: 'Scan',
        icon: Icons.document_scanner_outlined,
        colorLight: Color(0xFF7C3AED),
        colorDark: Color(0xFFBBA4FF),
        angleDeg: 0,
        // Scan sits at 0° — will be adjusted below
      ),
    ];

    final isDark = colorScheme.brightness == Brightness.dark;

    // Place the 4 items symmetrically: 150°, 110°, 70°, 30°
    const angles = [150.0, 110.0, 70.0, 30.0];
    final callbacks = [onAddExpense, onAddIncome, onTransfer, onScanReceipt];

    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: radius * 2 + 80,
        height: radius + 40,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (int i = 0; i < actions.length; i++)
              Positioned(
                bottom: 0,
                left: (radius + 40) +
                    radius *
                        math.cos(angles[i] * math.pi / 180) -
                    28,
                child: _FabActionButton(
                  action: actions[i],
                  isDark: isDark,
                  onTap: callbacks[i],
                  colorScheme: colorScheme,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FabAction {
  final String label;
  final IconData icon;
  final Color colorLight;
  final Color colorDark;
  final double angleDeg;

  const _FabAction({
    required this.label,
    required this.icon,
    required this.colorLight,
    required this.colorDark,
    required this.angleDeg,
  });
}

class _FabActionButton extends StatelessWidget {
  final _FabAction action;
  final bool isDark;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _FabActionButton({
    required this.action,
    required this.isDark,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? action.colorDark : action.colorLight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.4),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(action.icon, color: Colors.white, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          action.label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ══ Floating Nav Bar ═══════════════════════════════════════════════════════════

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ColorScheme colorScheme;
  final double bottomInset;
  final VoidCallback onFabTap;
  final bool fabOpen;
  final AnimationController fabController;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.colorScheme,
    required this.bottomInset,
    required this.onFabTap,
    required this.fabOpen,
    required this.fabController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        Spacing.md,
        0,
        Spacing.md,
        Spacing.lg + bottomInset,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xs,
            vertical: Spacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Tab 0: Home
              _NavBarItem(
                tab: _tabs[0],
                isSelected: currentIndex == 0,
                colorScheme: colorScheme,
                onTap: () => onTap(0),
              ),
              // Tab 1: Stats
              _NavBarItem(
                tab: _tabs[1],
                isSelected: currentIndex == 1,
                colorScheme: colorScheme,
                onTap: () => onTap(1),
              ),
              // Centre + FAB button
              _CentreFab(
                colorScheme: colorScheme,
                isOpen: fabOpen,
                controller: fabController,
                onTap: onFabTap,
              ),
              // Tab 2: Budget
              _NavBarItem(
                tab: _tabs[2],
                isSelected: currentIndex == 2,
                colorScheme: colorScheme,
                onTap: () => onTap(2),
              ),
              // Tab 3: More
              _NavBarItem(
                tab: _tabs[3],
                isSelected: currentIndex == 3,
                colorScheme: colorScheme,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CentreFab extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isOpen;
  final AnimationController controller;
  final VoidCallback onTap;

  const _CentreFab({
    required this.colorScheme,
    required this.isOpen,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: GestureDetector(
        onTap: onTap,
        child: Material(
          color: colorScheme.primary,
          shape: const CircleBorder(),
          elevation: isOpen ? 6 : 3,
          shadowColor: colorScheme.primary.withValues(alpha: 0.40),
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, __) => Transform.rotate(
              angle: controller.value * math.pi / 4,
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

// ══ Nav Bar Item ═════════════════════════════════════════════════════════════════

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
    final Color inactiveColor =
        colorScheme.onSurface.withValues(alpha: 0.40);

    return SizedBox(
      width: 64,
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
            borderRadius:
                const BorderRadius.all(Radius.circular(Radii.lg)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: FaIcon(
                      isSelected ? tab.activeIcon : tab.icon,
                      key: ValueKey<bool>(isSelected),
                      size: 18,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
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
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
