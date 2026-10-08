import 'package:flutter/material.dart';

/// One tab of the bottom navigation.
///
/// Carries everything the bar needs to render and describe a destination:
/// its label and an outlined/filled icon pair that cross-fades as the tab is
/// selected.
class AppNavDestination {
  /// Stable identifier, used for widget keys (`nav_<id>`).
  final String id;

  /// Visible label and tooltip.
  final String label;

  /// Outlined icon shown when the tab is not selected.
  final IconData icon;

  /// Filled icon shown when the tab is selected.
  final IconData selectedIcon;

  const AppNavDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  /// Key of this destination's tap target in the bar.
  Key get key => Key('nav_$id');
}
