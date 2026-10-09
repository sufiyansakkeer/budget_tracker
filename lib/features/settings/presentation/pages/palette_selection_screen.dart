import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/color_palette_entity.dart';
import '../bloc/theme/theme_bloc.dart';
import '../bloc/theme/theme_event.dart';
import '../../../../core/feedback/app_haptics.dart';

/// Full-screen palette selection. Each palette is previewed as two small
/// screens, light and dark, painted from the very themes the app builds for
/// it, so a preview is what the app will look like.
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
/// hero card with its figure, track and a selected chip, two list rows
/// with tinted icon tiles, the add button and the navigation bar.
class _MiniScreen extends StatelessWidget {
  final ColorPalette palette;
  final Brightness brightness;

  const _MiniScreen({required this.palette, required this.brightness});

  static final Map<(ColorPalette, Brightness), _PreviewColors> _colors = {};

  @override
  Widget build(BuildContext context) {
    final colors = _colors.putIfAbsent((
      palette,
      brightness,
    ), () => _PreviewColors.of(palette, brightness));
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
          child: CustomPaint(painter: _MiniScreenPainter(colors)),
        ),
      ),
    );
  }
}

/// The colours a preview draws with, read from the theme the app builds for
/// that palette and brightness (component themes included), so a thumbnail
/// cannot drift from what the app shows.
@immutable
class _PreviewColors {
  final Color page;
  final Color card;
  final Color ink;
  final Color muted;
  final Color track;
  final Color primary;
  final Color onPrimary;
  final Color chip;
  final Color onChip;
  final Color secondary;
  final Color tertiary;
  final Color bar;
  final Color indicator;
  final Color selectedIcon;
  final Color idleIcon;

  const _PreviewColors({
    required this.page,
    required this.card,
    required this.ink,
    required this.muted,
    required this.track,
    required this.primary,
    required this.onPrimary,
    required this.chip,
    required this.onChip,
    required this.secondary,
    required this.tertiary,
    required this.bar,
    required this.indicator,
    required this.selectedIcon,
    required this.idleIcon,
  });

  factory _PreviewColors.of(ColorPalette palette, Brightness brightness) {
    final theme = brightness == Brightness.light
        ? AppTheme.buildLightTheme(palette)
        : AppTheme.buildDarkTheme(palette);
    final c = theme.colorScheme;
    final nav = theme.navigationBarTheme;
    Color navIcon(Set<WidgetState> states) =>
        nav.iconTheme!.resolve(states)!.color!;
    return _PreviewColors(
      page: theme.scaffoldBackgroundColor,
      card: theme.cardTheme.color!,
      ink: c.onSurface,
      muted: c.onSurfaceVariant,
      track: theme.progressIndicatorTheme.linearTrackColor!,
      primary: c.primary,
      onPrimary: c.onPrimary,
      chip: c.primaryContainer,
      onChip: c.onPrimaryContainer,
      secondary: c.secondary,
      tertiary: c.tertiary,
      bar: nav.backgroundColor!,
      indicator: nav.indicatorColor!,
      selectedIcon: navIcon(const {WidgetState.selected}),
      idleIcon: navIcon(const {}),
    );
  }
}

class _MiniScreenPainter extends CustomPainter {
  final _PreviewColors c;

  _MiniScreenPainter(this.c);

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
    void fill(RRect r, Color color) =>
        canvas.drawRRect(r, paint..color = color);

    // Page.
    canvas.drawRect(Offset.zero & size, paint..color = c.page);

    // Hero card: a label, a selected chip, the figure, the track and fill.
    fill(box(1.5, 2.5, 17, 11, 1.6), c.card);
    fill(box(3, 4, 6, 1, 0.5), c.muted);
    fill(box(12, 3.6, 5, 1.8, 0.9), c.chip);
    fill(box(13, 4.2, 3, 0.6, 0.3), c.onChip);
    fill(box(3, 6, 10, 2.2, 0.6), c.ink);
    fill(box(3, 10, 14, 1.2, 0.6), c.track);
    fill(box(3, 10, 8.5, 1.2, 0.6), c.primary);

    // Two list rows on the page, each with an icon tile drawn the way the
    // app draws one: the accent as a faint tint, the glyph in the accent.
    for (final (i, accent) in [c.secondary, c.tertiary].indexed) {
      final y = 15.5 + i * 4.0;
      fill(
        box(1.5, y, 2.8, 2.8, 0.8),
        Color.alphaBlend(accent.withValues(alpha: 0.14), c.page),
      );
      canvas.drawCircle(
        Offset(2.9 * u, (y + 1.4) * u),
        0.7 * u,
        paint..color = accent,
      );
      fill(box(5.5, y + 0.4, 7, 0.9, 0.45), c.ink);
      fill(box(5.5, y + 1.8, 4.5, 0.7, 0.35), c.muted);
      fill(box(14.5, y + 0.9, 4, 0.9, 0.45), c.ink);
    }

    // Navigation bar with the selected destination's indicator.
    final navTop = h - 3.2 * u;
    canvas.drawRect(
      Rect.fromLTWH(0, navTop, w, h - navTop),
      paint..color = c.bar,
    );
    fill(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(2.5 * u, navTop + 1.6 * u),
          width: 3.6 * u,
          height: 1.9 * u,
        ),
        Radius.circular(0.95 * u),
      ),
      c.indicator,
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset((2.5 + i * 5) * u, navTop + 1.6 * u),
        0.6 * u,
        paint..color = i == 0 ? c.selectedIcon : c.idleIcon,
      );
    }

    // The add button: primary fill with an onPrimary plus.
    final fabLeft = w - 6 * u;
    final fabTop = navTop - 5.5 * u;
    fill(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(fabLeft, fabTop, 4.5 * u, 4.5 * u),
        Radius.circular(1.4 * u),
      ),
      c.primary,
    );
    final plus = Offset(fabLeft + 2.25 * u, fabTop + 2.25 * u);
    paint.color = c.onPrimary;
    canvas
      ..drawRect(
        Rect.fromCenter(center: plus, width: 1.8 * u, height: 0.36 * u),
        paint,
      )
      ..drawRect(
        Rect.fromCenter(center: plus, width: 0.36 * u, height: 1.8 * u),
        paint,
      );
  }

  @override
  bool shouldRepaint(_MiniScreenPainter old) => old.c != c;
}
