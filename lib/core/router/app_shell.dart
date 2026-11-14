import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/animated_bottom_navigation.dart';
import '../navigation/app_nav_destinations.dart';
import '../navigation/nav_add_button.dart';

/// The main application shell: hosts the [AnimatedBottomNavigation] and
/// preserves each tab's navigation stack via [StatefulShellRoute].
///
/// Tabs (see [appNavDestinations]): Today, Budget, [+], Activity, More.
/// Branches are [AppShellBranch]: Insights is a branch without a tab and
/// shows Activity selected.
///
/// The shell is only responsible for navigation. Animation state lives in
/// the bar; re-selecting the current tab pops that branch back to its root.
/// What the add button opens comes from the router ([onAdd], [onAddHold]).
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  /// Tap on +: add anything.
  final ValueChanged<BuildContext> onAdd;

  /// Press and hold on +: straight to an expense.
  final ValueChanged<BuildContext> onAddHold;

  const AppShell({
    super.key,
    required this.navigationShell,
    required this.onAdd,
    required this.onAddHold,
  });

  void _onDestinationSelected(int index) {
    final branch = AppShellBranch.ofTab[index];
    navigationShell.goBranch(
      branch,
      // Re-selecting the current tab pops it back to its root.
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The + is this scaffold's docked button, raised over the bar's middle
    // slot; floating snackbars rise above it on their own.
    return Scaffold(
      body: navigationShell,
      floatingActionButton: Builder(
        builder: (context) => NavAddButton(
          onPressed: () => onAdd(context),
          onLongPress: () => onAddHold(context),
        ),
      ),
      floatingActionButtonLocation: NavAddButton.location,
      bottomNavigationBar: AnimatedBottomNavigation(
        destinations: appNavDestinations,
        selectedIndex: AppShellBranch.tabOf(navigationShell.currentIndex),
        onDestinationSelected: _onDestinationSelected,
        // The + is docked over this slot.
        center: const SizedBox.shrink(),
      ),
    );
  }
}
