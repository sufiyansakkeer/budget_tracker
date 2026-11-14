import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../feedback/app_haptics.dart';

/// The add button over the middle of the bottom navigation: an action, not
/// a tab. Tap adds anything (an expense, a bill, a tab purchase or payment);
/// press and hold goes straight to an expense.
///
/// A 56dp brand square with rounded corners, raised over the bar's top edge
/// and set in a ring of the bar's colour, with a soft brand glow: the one
/// filled, lifted control on the screen ([NavAddButton.location]).
class NavAddButton extends StatefulWidget {
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  const NavAddButton({
    super.key = const Key('nav_add'),
    required this.onPressed,
    required this.onLongPress,
  });

  /// Where the shell's Scaffold docks it: centred, 14dp above the bar's
  /// top edge (most of it rests on the bar).
  static const FloatingActionButtonLocation location = _RaisedCenter();

  @override
  State<NavAddButton> createState() => _NavAddButtonState();
}

class _NavAddButtonState extends State<NavAddButton> {
  bool _pressed = false;

  static const double _size = 56;
  static const double _ring = 4;
  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final barColor =
        NavigationBarTheme.of(context).backgroundColor ??
        colorScheme.surfaceContainer;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
    );
    return Semantics(
      button: true,
      label: 'Add',
      onLongPressHint: 'Add an expense',
      child: Tooltip(
        message: 'Add',
        excludeFromSemantics: true,
        child: AnimatedScale(
          scale: _pressed ? AppMotion.pressedScale : 1,
          duration: AppMotion.respectReducedMotion(
            context,
            _pressed ? AppMotion.micro : AppMotion.standard,
          ),
          curve: AppMotion.standardCurve,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(_radius + _ring),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_ring),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.6),
                      offset: const Offset(0, 8),
                      blurRadius: 18,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: Material(
                  color: colorScheme.primary,
                  shape: shape,
                  child: InkWell(
                    customBorder: shape,
                    onTap: widget.onPressed,
                    onLongPress: () {
                      AppHaptics.confirm();
                      widget.onLongPress();
                    },
                    onHighlightChanged: (value) =>
                        setState(() => _pressed = value),
                    child: SizedBox.square(
                      dimension: _size,
                      child: Icon(
                        Icons.add_rounded,
                        size: 28,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [FloatingActionButtonLocation.centerDocked], 14dp lower: the button's
/// top clears the bar by 14dp and the rest sits on it.
class _RaisedCenter extends StandardFabLocation
    with FabCenterOffsetX, FabDockedOffsetY {
  const _RaisedCenter();

  static const double _lower = 14;

  @override
  double getOffsetY(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) {
    final docked = super.getOffsetY(scaffoldGeometry, adjustment);
    final barTop = scaffoldGeometry.contentBottom;
    final fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    // Docked centres the button on the bar's top edge; lower it by
    // [_lower]. When docked moved it up (a bottom sheet), keep that.
    final centred = barTop - fabHeight / 2;
    return docked < centred - 0.5 ? docked : centred + _lower;
  }

  @override
  String toString() => 'NavAddButton.location';
}
