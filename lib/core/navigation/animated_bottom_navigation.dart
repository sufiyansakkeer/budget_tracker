import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import 'nav_destination.dart';
import 'nav_icon.dart';

/// Smart Monivo's bottom navigation bar.
///
/// Material 3 proportions (68 dp + safe area, stadium indicator, always-on
/// labels) with animated icons. Everything about the *steady* selected state
/// is driven by [selectedIndex]: indicator width and colour, icon tint and
/// scale, label weight. The Rive icon only adds a one-shot pulse when a tab
/// becomes selected, so state is always correct after navigation, after
/// returning from another screen and after a cold start.
///
/// Interaction: press-scale feedback, ink ripple, a selection haptic when the
/// tab changes, and re-tapping the current tab replays the pulse and still
/// reports the index (the shell pops that tab to its root).
///
/// Honours reduced motion: indicator/tint changes become instant and the
/// Rive input is never pulsed.
///
/// The bar knows nothing about routing; it only reports taps through
/// [onDestinationSelected].
class AnimatedBottomNavigation extends StatefulWidget {
  final List<AppNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AnimatedBottomNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  }) : assert(destinations.length >= 2),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  @override
  State<AnimatedBottomNavigation> createState() =>
      _AnimatedBottomNavigationState();
}

class _AnimatedBottomNavigationState extends State<AnimatedBottomNavigation> {
  /// Incremented for a destination when it is tapped while already selected,
  /// so its icon replays the pulse.
  late final List<int> _pulseTokens = List.filled(
    widget.destinations.length,
    0,
  );

  void _onTap(int index) {
    if (index == widget.selectedIndex) {
      setState(() => _pulseTokens[index]++);
    } else {
      HapticFeedback.selectionClick();
    }
    widget.onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final navTheme = NavigationBarTheme.of(context);
    final selectedIcon =
        navTheme.iconTheme?.resolve({WidgetState.selected})?.color ??
        colorScheme.onSecondaryContainer;
    final unselectedIcon =
        navTheme.iconTheme?.resolve(const {})?.color ??
        colorScheme.onSurfaceVariant;
    final selectedLabel =
        navTheme.labelTextStyle?.resolve({WidgetState.selected}) ??
        theme.textTheme.labelSmall!.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        );
    final unselectedLabel =
        navTheme.labelTextStyle?.resolve(const {}) ??
        theme.textTheme.labelSmall!.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        );
    final indicatorColor =
        navTheme.indicatorColor ?? colorScheme.secondaryContainer;
    final iconSize =
        navTheme.iconTheme?.resolve(const {})?.size ?? AppSizes.iconLg;
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.standard,
    );

    return Material(
      color: navTheme.backgroundColor ?? colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          // Material's own NavigationBar clamps text scaling to 1.3; this
          // bar is a fixed height too, so it needs the same guard or the
          // labels clip at large system font sizes.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: SizedBox(
              height: navTheme.height ?? AppSizes.navBarHeight,
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: Row(
                  children: [
                    for (var i = 0; i < widget.destinations.length; i++)
                      Expanded(
                        child: _NavItem(
                          key: widget.destinations[i].key,
                          destination: widget.destinations[i],
                          selected: i == widget.selectedIndex,
                          pulseToken: _pulseTokens[i],
                          duration: duration,
                          iconSize: iconSize,
                          selectedIconColor: selectedIcon,
                          unselectedIconColor: unselectedIcon,
                          selectedLabelStyle: selectedLabel,
                          unselectedLabelStyle: unselectedLabel,
                          indicatorColor: indicatorColor,
                          onTap: () => _onTap(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final AppNavDestination destination;
  final bool selected;
  final int pulseToken;
  final Duration duration;
  final double iconSize;
  final Color selectedIconColor;
  final Color unselectedIconColor;
  final TextStyle selectedLabelStyle;
  final TextStyle unselectedLabelStyle;
  final Color indicatorColor;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.pulseToken,
    required this.duration,
    required this.iconSize,
    required this.selectedIconColor,
    required this.unselectedIconColor,
    required this.selectedLabelStyle,
    required this.unselectedLabelStyle,
    required this.indicatorColor,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  /// Material 3 active-indicator size.
  static const double _indicatorWidth = 64;
  static const double _indicatorHeight = 32;

  @override
  Widget build(BuildContext context) {
    final d = widget.destination;
    final selected = widget.selected;

    return Semantics(
      button: true,
      selected: selected,
      label: d.label,
      child: Tooltip(
        message: d.label,
        child: InkResponse(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          highlightShape: BoxShape.rectangle,
          containedInkWell: true,
          splashFactory: InkSparkle.splashFactory,
          child: AnimatedScale(
            scale: _pressed ? AppMotion.pressedScale : 1,
            duration: AppMotion.respectReducedMotion(
              context,
              _pressed ? AppMotion.micro : AppMotion.standard,
            ),
            curve: AppMotion.standardCurve,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.touchTarget,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Indicator grows from a dot behind the icon into the
                      // full stadium as the tab becomes selected.
                      AnimatedContainer(
                        duration: widget.duration,
                        curve: AppMotion.emphasizedDecelerate,
                        width: selected ? _indicatorWidth : _indicatorHeight,
                        height: _indicatorHeight,
                        decoration: ShapeDecoration(
                          shape: const StadiumBorder(),
                          color: widget.indicatorColor.withValues(
                            alpha: selected ? 1 : 0,
                          ),
                        ),
                      ),
                      ExcludeSemantics(
                        child: NavIcon(
                          destination: d,
                          selected: selected,
                          pulseToken: widget.pulseToken,
                          selectedColor: widget.selectedIconColor,
                          unselectedColor: widget.unselectedIconColor,
                          size: widget.iconSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AnimatedDefaultTextStyle(
                    duration: widget.duration,
                    curve: AppMotion.standardCurve,
                    style: selected
                        ? widget.selectedLabelStyle
                        : widget.unselectedLabelStyle,
                    child: ExcludeSemantics(
                      child: Text(
                        d.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
