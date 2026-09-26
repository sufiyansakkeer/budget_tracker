import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/theme_mode_entity.dart';
import '../../../../core/widgets/pressable.dart';

/// Tile group for selecting the application theme mode.
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
    return Column(
      children: [
        for (final option in themeOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ThemeOptionTile(
              option: option,
              selected: option.mode == selectedMode,
              onTap: () => onChanged(option.mode),
            ),
          ),
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label}, ${option.description}',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          child: AnimatedContainer(
            duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
            curve: AppMotion.standardCurve,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smd,
              vertical: AppSpacing.smd,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainer,
              borderRadius: AppSpacing.borderRadiusMd,
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  option.icon,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.label, style: theme.textTheme.titleSmall),
                      Text(
                        option.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: AppMotion.respectReducedMotion(
                    context,
                    AppMotion.fast,
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_circle,
                          key: const ValueKey('on'),
                          color: scheme.onPrimaryContainer,
                        )
                      : Icon(
                          Icons.radio_button_off_rounded,
                          key: const ValueKey('off'),
                          color: scheme.onSurfaceVariant,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
