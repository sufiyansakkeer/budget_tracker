import 'package:flutter/material.dart';

import 'nav_destination.dart';

/// The four Monivo tabs, in bar order. The add button sits between Budget
/// and Activity; it is an action, not a tab.
///
/// All four use the rounded Material set so stroke weight and corner style
/// match: outlined when idle, filled when selected.
const List<AppNavDestination> appNavDestinations = [
  AppNavDestination(
    id: 'today',
    label: 'Today',
    icon: Icons.wb_sunny_outlined,
    selectedIcon: Icons.wb_sunny_outlined,
  ),
  AppNavDestination(
    id: 'budget',
    label: 'Budget',
    icon: Icons.pie_chart_outline_rounded,
    selectedIcon: Icons.pie_chart_outline_rounded,
  ),
  AppNavDestination(
    id: 'activity',
    label: 'Activity',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_outlined,
  ),
  AppNavDestination(
    id: 'more',
    label: 'More',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_outlined,
  ),
];

/// The `StatefulShellRoute` branches in `app_router.dart`, in order.
/// Insights has no tab of its own: it belongs to Activity, so the bar shows
/// Activity selected while it is open.
abstract final class AppShellBranch {
  static const int today = 0;
  static const int budget = 1;
  static const int activity = 2;
  static const int insights = 3;
  static const int more = 4;

  /// The branch each tab in [appNavDestinations] opens.
  static const List<int> ofTab = [today, budget, activity, more];

  /// The tab shown selected while [branch] is open.
  static int tabOf(int branch) =>
      branch == insights ? ofTab.indexOf(activity) : ofTab.indexOf(branch);
}
