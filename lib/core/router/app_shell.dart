import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';

/// The main application shell that hosts the Material 3 [NavigationBar] and
/// preserves each tab's navigation stack via [StatefulShellRoute].
///
/// Tabs:
///   0. Home  (Dashboard)
///   1. Expenses
///   2. Reports
///   3. Settings
///
/// Selecting a tab cross-fades the outlined icon into its filled twin,
/// lifts and scales it slightly, and lets the Material active indicator
/// expand underneath — all on one shared duration so nothing looks out of
/// step. Re-selecting the current tab (which pops it to its root) gives a
/// short pulse so the tap is acknowledged.
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _tabs = [
    _Tab('Home', Icons.home_outlined, Icons.home_rounded),
    _Tab('Expenses', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    _Tab('Reports', Icons.insights_outlined, Icons.insights_rounded),
    _Tab('Settings', Icons.settings_outlined, Icons.settings_rounded),
  ];

  /// Incremented each time the current tab is re-selected; keyed into the
  /// icons so the selected one plays a single pulse.
  int _pulse = 0;

  void _onDestinationSelected(int index) {
    final shell = widget.navigationShell;
    final reselected = index == shell.currentIndex;
    if (reselected) {
      setState(() => _pulse++);
    } else {
      HapticFeedback.selectionClick();
    }
    shell.goBranch(
      index,
      // Re-selecting the current tab pops it back to its root.
      initialLocation: reselected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final current = widget.navigationShell.currentIndex;
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        // The NavigationBar pads itself for the bottom system inset, so no
        // extra SafeArea is needed here.
        child: NavigationBar(
          selectedIndex: current,
          animationDuration: AppMotion.respectReducedMotion(
            context,
            AppMotion.standard,
          ),
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            for (var i = 0; i < _tabs.length; i++)
              NavigationDestination(
                icon: _NavIcon(
                  outlined: _tabs[i].outlined,
                  filled: _tabs[i].filled,
                  selected: i == current,
                  pulse: _pulse,
                ),
                label: _tabs[i].label,
                tooltip: _tabs[i].label,
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  final String label;
  final IconData outlined;
  final IconData filled;
  const _Tab(this.label, this.outlined, this.filled);
}

/// Bottom-navigation icon that animates between its unselected and selected
/// looks instead of being swapped.
///
/// Used for both `icon` and `selectedIcon` of a [NavigationDestination]; the
/// bar's own icon switch then updates the same element, and this widget
/// animates colour, shape, scale and lift from [selected].
class _NavIcon extends StatelessWidget {
  final IconData outlined;
  final IconData filled;
  final bool selected;
  final int pulse;

  const _NavIcon({
    required this.outlined,
    required this.filled,
    required this.selected,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navTheme = NavigationBarTheme.of(context);
    final selectedColor =
        navTheme.iconTheme?.resolve({WidgetState.selected})?.color ??
        theme.colorScheme.onSecondaryContainer;
    final unselectedColor =
        navTheme.iconTheme?.resolve(const {})?.color ??
        theme.colorScheme.onSurfaceVariant;
    final size = IconTheme.of(context).size ?? AppSizes.iconLg;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1 : 0),
      duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
      curve: AppMotion.emphasizedDecelerate,
      builder: (context, t, _) {
        final color = Color.lerp(unselectedColor, selectedColor, t)!;
        final scale = 1 + (AppMotion.navIconSelectedScale - 1) * t;
        return _Pulse(
          key: ValueKey(pulse),
          amplitude: 0.12 * t,
          child: Transform.translate(
            offset: Offset(0, -1.5 * t),
            child: Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 1 - t,
                    child: Icon(outlined, size: size, color: color),
                  ),
                  Opacity(
                    opacity: t,
                    child: Icon(filled, size: size, color: color),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One-shot scale pulse (1 → 1+amplitude → 1) played when this widget is
/// (re)created with a new key. An [amplitude] of 0 renders the child as-is,
/// so unselected icons stay still.
class _Pulse extends StatelessWidget {
  final double amplitude;
  final Widget child;

  const _Pulse({super.key, required this.amplitude, required this.child});

  @override
  Widget build(BuildContext context) {
    final pulseKey = key;
    final active =
        amplitude > 0 &&
        pulseKey is ValueKey<int> &&
        pulseKey.value > 0 &&
        !AppMotion.isReduced(context);
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.medium,
      curve: Curves.easeInOut,
      child: child,
      builder: (context, t, child) {
        if (t >= 1) return child!;
        final scale = 1 + amplitude * math.sin(math.pi * t);
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}
