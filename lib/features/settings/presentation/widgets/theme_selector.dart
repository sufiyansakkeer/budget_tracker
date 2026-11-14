import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/theme_mode_entity.dart';
import '../../../../core/feedback/app_haptics.dart';

/// The theme mode as one segmented control (blueprint .sg): System, Light
/// and Dark on the inset tone, the chosen one raised to the card tone. What
/// each does is read out, not shown.
class ThemeSelector extends StatelessWidget {
  final AppThemeMode selectedMode;
  final ValueChanged<AppThemeMode> onChanged;

  const ThemeSelector({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = themeOptions.indexWhere((o) => o.mode == selectedMode);
    final last = themeOptions.length - 1;
    // The track is a Material so the segments' ink shows on it.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSmd),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: IntrinsicHeight(
          child: Stack(
            children: [
              if (selected >= 0)
                Positioned.fill(
                  child: AnimatedAlign(
                    alignment: AlignmentDirectional(
                      last == 0 ? 0 : -1 + 2 * selected / last,
                      0,
                    ),
                    duration: AppMotion.respectReducedMotion(
                      context,
                      AppMotion.standard,
                    ),
                    curve: AppMotion.emphasizedCurve,
                    child: FractionallySizedBox(
                      widthFactor: 1 / themeOptions.length,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: AppSpacing.borderRadiusSm,
                          boxShadow: dark ? null : AppCard.lift,
                          border: dark
                              ? Border.all(color: scheme.outlineVariant)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < themeOptions.length; i++)
                    Expanded(
                      child: _Segment(
                        option: themeOptions[i],
                        selected: i == selected,
                        onTap: () {
                          if (i != selected) AppHaptics.selection();
                          onChanged(themeOptions[i].mode);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = AppMotion.respectReducedMotion(context, AppMotion.fast);
    final strong = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '${option.label}, ${option.description}',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          // A 48 dp target; the label sits centred in it.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: duration,
                style: theme.textTheme.labelLarge!.copyWith(color: strong),
                textAlign: TextAlign.center,
                // One word: shrinks to fit at large text sizes rather than
                // losing letters.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(option.label, maxLines: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
