import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import '../theme/contrast.dart';

/// One colour choice in a picker (a budget's or a category's colour): a
/// circle on a full touch target that grows, takes an outline and shows a
/// check mark when [selected]. Read as "{name} colour", a selectable button.
class AppColorSwatch extends StatelessWidget {
  final Color color;

  /// The colour's name, as a screen reader says it ("Teal").
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const AppColorSwatch({
    super.key,
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  static const double _size = 30;
  static const double _selectedSize = 36;

  /// The check mark's colour on [fill]: white wherever it reaches the 3:1
  /// a meaningful mark needs, black otherwise. Picking by estimated
  /// brightness left white marks near 2.7:1 on mid-tone fills (UX-107).
  static Color checkColorOn(Color fill) =>
      Contrast.ratio(Colors.white, fill) >= Contrast.large
      ? Colors.white
      : Contrast.ensureContrast(Colors.black, fill, minRatio: Contrast.large);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = AppMotion.respectReducedMotion(context, AppMotion.fast);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name colour',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.touchTarget,
          height: AppSizes.touchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.standardCurve,
              width: selected ? _selectedSize : _size,
              height: selected ? _selectedSize : _size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: AnimatedSwitcher(
                duration: duration,
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        key: const ValueKey('check'),
                        size: AppSizes.iconSm + 2,
                        color: checkColorOn(color),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
