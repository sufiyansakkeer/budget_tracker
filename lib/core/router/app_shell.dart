import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_spacing.dart';
import '../navigation/animated_bottom_navigation.dart';
import '../navigation/app_nav_destinations.dart';

/// The main application shell: hosts the [AnimatedBottomNavigation] and
/// preserves each tab's navigation stack via [StatefulShellRoute].
///
/// Tabs (see [appNavDestinations]):
///   0. Home  (Dashboard)
///   1. Expenses
///   2. Reports
///   3. Settings
///
/// The shell is only responsible for navigation. Animation state lives in
/// the bar; re-selecting the current tab pops that branch back to its root.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Re-selecting the current tab pops it back to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// How far the shell's snackbars float above the navigation bar: clear
  /// of a tab's add button (56 dp, 16 dp from the bar) with a small gap.
  static const double _snackBarLift =
      kFloatingActionButtonMargin + 56 + AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    // Every snackbar on a tab, and every one shown by a screen that has
    // just closed over the tabs, is drawn by this scaffold, not the tab's,
    // so it knows nothing of the tab's add button. Lifting them here keeps
    // the button visible and tappable.
    final theme = Theme.of(context);
    final inset =
        theme.snackBarTheme.insetPadding?.resolve(TextDirection.ltr) ??
        const EdgeInsets.all(AppSpacing.md);
    return Theme(
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(
          insetPadding: inset.copyWith(bottom: inset.bottom + _snackBarLift),
        ),
      ),
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: AnimatedBottomNavigation(
          destinations: appNavDestinations,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
      ),
    );
  }
}
