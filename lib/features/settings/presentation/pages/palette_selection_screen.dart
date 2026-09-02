import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/color_palettes.dart';
import '../../domain/entities/color_palette_entity.dart';
import '../bloc/theme/theme_bloc.dart';
import '../bloc/theme/theme_event.dart';

/// Full-screen palette selection with color swatch previews.
class PaletteSelectionScreen extends StatelessWidget {
  const PaletteSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPalette = context.watch<ThemeBloc>().state.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Color Palette')),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: paletteOptions.length,
        itemBuilder: (context, index) {
          final option = paletteOptions[index];
          final isSelected = option.palette == currentPalette;
          return _PaletteCard(
            option: option,
            isSelected: isSelected,
            onTap: () {
              context.read<ThemeBloc>().add(
                ColorPaletteChanged(option.palette),
              );
            },
          );
        },
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.lightScheme.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(
              color: isSelected
                  ? colors.lightScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Color swatches
              _ColorSwatches(palette: option.palette),
              const SizedBox(width: AppSpacing.md),
              // Label + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Light + Dark',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Selection indicator
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: colors.lightScheme.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  final ColorPalette palette;

  const _ColorSwatches({required this.palette});

  @override
  Widget build(BuildContext context) {
    final colors = getPaletteColors(palette);
    final lightScheme = colors.lightScheme;

    final accentColors = [
      _AccentColor('Primary', lightScheme.primary),
      _AccentColor('Secondary', lightScheme.secondary),
      _AccentColor('Tertiary', lightScheme.tertiary),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final accent in accentColors)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SwatchDot(color: accent.color),
                const SizedBox(width: 6),
                Text(
                  accent.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AccentColor {
  final String label;
  final Color color;
  _AccentColor(this.label, this.color);
}

class _SwatchDot extends StatelessWidget {
  final Color color;

  const _SwatchDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
    );
  }
}
