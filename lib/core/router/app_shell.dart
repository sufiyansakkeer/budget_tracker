import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AnimatedBottomNavigation(
        destinations: appNavDestinations,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}
