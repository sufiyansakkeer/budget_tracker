import 'package:flutter/material.dart';

import 'rive_icon_spec.dart';

/// One tab of the bottom navigation.
///
/// Carries everything the bar needs to render and describe a destination:
/// label, Material icons (used as the loading/fallback renderer and in
/// tests) and the Rive icon that plays when the tab is selected.
class AppNavDestination {
  /// Stable identifier, used for widget keys (`nav_<id>`).
  final String id;

  /// Visible label and tooltip.
  final String label;

  /// Outlined Material icon shown when unselected in Material mode.
  final IconData icon;

  /// Filled Material icon shown when selected in Material mode.
  final IconData selectedIcon;

  /// Animated icon.
  final RiveIconSpec rive;

  const AppNavDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.rive,
  });

  /// Key of this destination's tap target in the bar.
  Key get key => Key('nav_$id');
}
