import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../domain/entities/color_palette_entity.dart';
import '../bloc/theme/theme_bloc.dart';
import '../bloc/theme/theme_event.dart';
import '../../../../core/feedback/app_haptics.dart';

/// Full-screen palette selection. Each palette is previewed as two small
/// screens, light and dark, drawn with the same colour tokens the app
/// builds its themes from, so a preview is what the app will look like.
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
            'Each palette in light and dark. Changes apply right away.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = AppSpacing.smd;
              final perRow = constraints.maxWidth >= 600 ? 3 : 2;
              final width =
                  ((constraints.maxWidth - gap * (perRow - 1)) / perRow)
                      .floorToDouble();
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final option in paletteOptions)
                    SizedBox(
                      width: width,
                      child: _PaletteTile(
                        key: Key('palette_${option.palette.name}'),
                        option: option,
                        isSelected: option.palette == currentPalette,
                        onTap: () {
                          if (option.palette != currentPalette) {
                            AppHaptics.selection();
                          }
                          context.read<ThemeBloc>().add(
                            ColorPaletteChanged(option.palette),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  final PaletteOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaletteTile({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = AppMotion.respectReducedMotion(context, AppMotion.fast);
    final shape = RoundedRectangleBorder(
      borderRadius: AppSpacing.borderRadiusMd,
      side: isSelected
          ? BorderSide(color: scheme.primary, width: 2)
          : BorderSide.none,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      label: '${option.label} palette, ${option.description}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MiniScreen(
                        palette: option.palette,
                        brightness: Brightness.light,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Expanded(
                      child: _MiniScreen(
                        palette: option.palette,
                        brightness: Brightness.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xxs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.label,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              option.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: duration,
                      child: isSelected
                          ? Icon(
                              Icons.check_circle,
                              key: const ValueKey('on'),
                              color: scheme.primary,
                              size: AppSizes.iconMd,
                            )
                          : const SizedBox(
                              key: ValueKey('off'),
                              width: AppSizes.iconMd,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A thumbnail of the app in one palette and brightness: the page, the
/// hero card with its figure and track, two list rows, the add button and
/// the navigation bar.
class _MiniScreen extends StatelessWidget {
  final ColorPalette palette;
  final Brightness brightness;

  const _MiniScreen({required this.palette, required this.brightness});

  static final Map<(ColorPalette, Brightness), AppColorTokens> _tokens = {};

  @override
  Widget build(BuildContext context) {
    final tokens = _tokens.putIfAbsent((
      palette,
      brightness,
    ), () => AppColorTokens.fromPalette(palette, brightness));
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppSpacing.borderRadiusSm,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: ClipRRect(
          borderRadius: AppSpacing.borderRadiusSm,
          child: CustomPaint(painter: _MiniScreenPainter(tokens)),
        ),
      ),
    );
  }
}

class _MiniScreenPainter extends CustomPainter {
  final AppColorTokens t;

  _MiniScreenPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = w / 20; // One grid unit; the screen is 20 units wide.
    final paint = Paint();
    RRect box(double x, double y, double bw, double bh, double r) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * u, y * u, bw * u, bh * u),
          Radius.circular(r * u),
        );
    void fill(RRect r, Color c) => canvas.drawRRect(r, paint..color = c);

    // Page.
    canvas.drawRect(Offset.zero & size, paint..color = t.background);

    // Hero card: a label, the figure, the track with its fill.
    fill(box(1.5, 2.5, 17, 11, 1.6), t.card);
    fill(box(3, 4, 6, 1, 0.5), t.textSecondary);
    fill(box(3, 6, 10, 2.2, 0.6), t.textPrimary);
    fill(box(3, 10, 14, 1.2, 0.6), t.surfaceContainerHighest);
    fill(box(3, 10, 8.5, 1.2, 0.6), t.primary);

    // Two list rows: a tinted tile, a line, an amount.
    for (final (i, accent) in [t.secondary, t.tertiary].indexed) {
      final y = 15.5 + i * 4.0;
      fill(box(1.5, y, 2.8, 2.8, 0.8), accent);
      fill(box(5.5, y + 0.4, 7, 0.9, 0.45), t.textPrimary);
      fill(box(5.5, y + 1.8, 4.5, 0.7, 0.35), t.textSecondary);
      fill(box(14.5, y + 0.9, 4, 0.9, 0.45), t.textPrimary);
    }

    // Navigation bar with the selected destination, and the add button.
    final navTop = h - 3.2 * u;
    canvas.drawRect(
      Rect.fromLTWH(0, navTop, w, h - navTop),
      paint..color = t.surfaceContainer,
    );
    for (var i = 0; i < 4; i++) {
      final cx = (2.5 + i * 5) * u;
      canvas.drawCircle(
        Offset(cx, navTop + 1.6 * u),
        0.7 * u,
        paint..color = i == 0 ? t.primary : t.textSecondary,
      );
    }
    final fab = RRect.fromRectAndRadius(
      Rect.fromLTWH(w - 6 * u, navTop - 5.5 * u, 4.5 * u, 4.5 * u),
      Radius.circular(1.4 * u),
    );
    fill(fab, t.primary);
  }

  @override
  bool shouldRepaint(_MiniScreenPainter old) => old.t != t;
}
