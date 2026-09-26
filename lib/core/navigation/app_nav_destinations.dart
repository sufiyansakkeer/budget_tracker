import 'package:flutter/material.dart';

import 'nav_destination.dart';
import 'rive_icon_spec.dart';

/// Bundle path of the navigation icon file. See `assets/rive/README.md`.
const String navIconsAsset = 'assets/rive/nav_icons.riv';

/// The four Smart Monivo tabs, in bar order. The order must match the
/// `StatefulShellRoute` branch order in `app_router.dart`.
const List<AppNavDestination> appNavDestinations = [
  AppNavDestination(
    id: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    rive: RiveIconSpec(
      asset: navIconsAsset,
      artboard: 'HOME',
      stateMachine: 'HOME_interactivity',
      input: 'active',
    ),
  ),
  AppNavDestination(
    id: 'expenses',
    label: 'Expenses',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    rive: RiveIconSpec(
      asset: navIconsAsset,
      artboard: 'RULES',
      stateMachine: 'State Machine 1',
      input: 'isActive',
    ),
  ),
  AppNavDestination(
    id: 'reports',
    label: 'Reports',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    // Four tiles that morph into dots when activated. Filled glyph, so it is
    // drawn a little smaller to match the optical weight of the outlines.
    rive: RiveIconSpec(
      asset: navIconsAsset,
      artboard: 'DASHBOARD',
      stateMachine: 'State Machine 1',
      input: 'isActive',
      scale: 0.8,
    ),
  ),
  AppNavDestination(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    rive: RiveIconSpec(
      asset: navIconsAsset,
      artboard: 'SETTINGS',
      stateMachine: 'SETTINGS_Interactivity',
      input: 'active',
    ),
  ),
];
