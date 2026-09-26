import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/color_palettes.dart';
import '../../domain/entities/color_palette_entity.dart';
import '../bloc/theme/theme_bloc.dart';
import '../bloc/theme/theme_event.dart';
import '../../../../core/widgets/pressable.dart';

/// Full-screen palette selection. Previews use the scheme that matches the
/// current brightness, so dark mode shows the dark variant of each palette.
class PaletteSelectionScreen extends StatelessWidget {
  const PaletteSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPalette = context.watch<ThemeBloc>().state.palette;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Color palette')),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Text(
            'Changes apply immediately, in light and dark mode.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final option in paletteOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PaletteCard(
                option: option,
                isSelected: option.palette == currentPalette,
                onTap: () => context.read<ThemeBloc>().add(
                  ColorPaletteChanged(option.palette),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final PaletteOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaletteCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = getPaletteColors(option.palette);
    final scheme = theme.brightness == Brightness.dark
        ? colors.darkScheme
        : colors.lightScheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${option.label} palette, ${option.description}',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusLg,
          child: AnimatedContainer(
            duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
            curve: AppMotion.standardCurve,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.08)
                  : theme.cardTheme.color,
              borderRadius: AppSpacing.borderRadiusLg,
              border: Border.all(
                color: isSelected
                    ? scheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                _Swatches(scheme: scheme),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.label, style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        option.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AnimatedSwitcher(
                  duration: AppMotion.respectReducedMotion(
                    context,
                    AppMotion.fast,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_circle,
                          key: const ValueKey('on'),
                          color: scheme.primary,
                        )
                      : Icon(
                          Icons.radio_button_off_rounded,
                          key: const ValueKey('off'),
                          color: theme.colorScheme.onSurfaceVariant,
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

/// Three overlapping circles: primary, secondary, tertiary.
class _Swatches extends StatelessWidget {
  final ColorScheme scheme;
  const _Swatches({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).cardTheme.color ?? scheme.surface;
    const size = AppSizes.iconXl;
    const overlap = 12.0;
    final swatches = [scheme.primary, scheme.secondary, scheme.tertiary];
    return SizedBox(
      width: size + overlap * (swatches.length - 1) + 4,
      height: size + 4,
      child: Stack(
        children: [
          for (var i = 0; i < swatches.length; i++)
            Positioned(
              left: i * overlap,
              top: 2,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: swatches[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
