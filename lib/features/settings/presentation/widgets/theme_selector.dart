import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/theme_mode_entity.dart';

/// The theme mode as one segmented control: System, Light and Dark side by
/// side, each with its icon, name and what it does. The selected segment
/// sits on a thumb that slides between them.
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
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
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
                          color: scheme.secondaryContainer,
                          borderRadius: AppSpacing.borderRadiusSm,
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
                        onTap: () => onChanged(themeOptions[i].mode),
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
    final strong = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    final muted = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
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
            vertical: AppSpacing.smd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: muted),
                duration: duration,
                builder: (context, color, _) =>
                    Icon(option.icon, size: AppSizes.iconMd, color: color),
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedDefaultTextStyle(
                duration: duration,
                style: theme.textTheme.titleSmall!.copyWith(color: strong),
                textAlign: TextAlign.center,
                // One word: shrinks to fit at large text sizes rather than
                // losing letters.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(option.label, maxLines: 1),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              AnimatedDefaultTextStyle(
                duration: duration,
                style: theme.textTheme.labelSmall!.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                child: Text(option.description),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
