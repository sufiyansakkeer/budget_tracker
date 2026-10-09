import 'package:flutter/material.dart';

import 'nav_destination.dart';

/// The four Monivo tabs, in bar order. The order must match the
/// `StatefulShellRoute` branch order in `app_router.dart`.
///
/// All four use the rounded Material set so stroke weight and corner style
/// match: outlined when idle, filled when selected.
const List<AppNavDestination> appNavDestinations = [
  AppNavDestination(
    id: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  AppNavDestination(
    id: 'expenses',
    label: 'Expenses',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  AppNavDestination(
    id: 'reports',
    label: 'Reports',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
  ),
  AppNavDestination(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  ),
];
