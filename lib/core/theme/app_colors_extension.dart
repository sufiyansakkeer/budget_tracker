import 'package:flutter/material.dart';

import '../../features/settings/domain/entities/color_palette_entity.dart';
import 'color_palettes.dart';

import 'contrast.dart';

/// Semantic color tokens that adapt to the selected [ColorPalette] and
/// current [Brightness].
///
/// These tokens are the single source every theme is built from. A palette
/// supplies *identity* (hues chosen to look like "Ocean" or "Sunset"); the
/// tokens turn that identity into colours that are guaranteed to be legible
/// on the surfaces they are drawn on, in both light and dark:
///
/// * Text-bearing accents (primary, error, success, warning, info, income,
///   expense) reach WCAG AA for body text (4.5:1) against [surface].
/// * Decorative accents (secondary, tertiary) reach the non-text minimum
///   (3:1) so chips, swatches and chart marks stay visible.
/// * [textSecondary] is legible on the darkest/lightest container it can be
///   placed on, not just on the base surface.
/// * [outline] reaches 3:1 and [divider] 1.6:1 so borders, hairlines, drag
///   handles and unselected switch tracks never vanish into the background.
///
/// Only lightness is moved when a colour needs adjusting (see
/// [Contrast.ensureContrast]); hue and saturation are preserved so the palette
/// still reads as itself.
///
/// Access via `context.appColors` after importing this file.
@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  // Brand — Primary
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;

  // Brand — Secondary
  final Color secondary;
  final Color secondaryLight;
  final Color secondaryDark;

  // Brand — Tertiary
  final Color tertiary;
  final Color tertiaryLight;
  final Color tertiaryDark;

  // Semantic
  final Color income;
  final Color expense;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Surfaces
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color card;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Dividers / outlines
  final Color divider;
  final Color outline;

  // Status containers
  final Color successContainer;
  final Color warningContainer;
  final Color errorContainer;

  const AppColorTokens({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.secondaryLight,
    required this.secondaryDark,
    required this.tertiary,
    required this.tertiaryLight,
    required this.tertiaryDark,
    required this.income,
    required this.expense,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.outline,
    required this.successContainer,
    required this.warningContainer,
    required this.errorContainer,
  });

  /// Minimum ratio of a status/brand tint container against the surface, so
  /// tinted chips and banners are visible as shapes in both themes.
  static const double _tintAlphaLight = 0.14;
  static const double _tintAlphaDark = 0.22;

  /// Builds tokens from a [ColorPalette] and [Brightness].
  factory AppColorTokens.fromPalette(
    ColorPalette palette,
    Brightness brightness,
  ) {
    final colors = getPaletteColors(palette);
    final scheme = brightness == Brightness.light
        ? colors.lightScheme
        : colors.darkScheme;
    final isDark = brightness == Brightness.dark;
    final surface = scheme.surface;

    // -------------------------------------------------------------------------
    // Surface hierarchy.
    //
    // Light: white-ish cards sit on a slightly darker page so a card is a
    // visible shape even without elevation, and each container level steps
    // further away from the card.
    //
    // Dark: the palette surface is the page (darkened a touch), and every
    // container level steps *lighter* — Material's "closer to the light
    // source" model — so cards, inputs and menus read as raised, not as holes.
    // -------------------------------------------------------------------------
    //
    // Each level is a fixed lightness step *and* a minimum ratio against the
    // surface. The step keeps the hierarchy gentle on mid-luminance surfaces;
    // the floor keeps it visible on the very dark palettes, where the same
    // step in lightness barely changes luminance.
    Color step(Color candidate, double minRatio) =>
        Contrast.ensureContrast(candidate, surface, minRatio: minRatio);

    final bg = isDark
        ? _darken(surface, 0.04)
        : step(_darken(surface, 0.035), 1.07);
    final cardColor = isDark ? step(_lighten(surface, 0.045), 1.15) : surface;
    final container = isDark
        ? step(_lighten(surface, 0.08), 1.3)
        : step(_darken(surface, 0.06), 1.12);
    final containerHigh = isDark
        ? step(_lighten(surface, 0.13), 1.55)
        : step(_darken(surface, 0.10), 1.22);
    final containerHighest = isDark
        ? step(_lighten(surface, 0.18), 1.85)
        : step(_darken(surface, 0.14), 1.35);

    // -------------------------------------------------------------------------
    // Accents, made legible on the surfaces they are drawn on.
    //
    // Text-bearing accents are checked against the *deepest* container an
    // amount, status or link can sit on (input fills, chips, menus, tracks);
    // passing there guarantees every lighter surface above it — cards, sheets
    // and the page itself.
    // -------------------------------------------------------------------------
    Color legible(Color c) => Contrast.ensureContrast(c, containerHigh);
    Color visible(Color c) =>
        Contrast.ensureContrast(c, surface, minRatio: Contrast.large);

    final primary = legible(scheme.primary);
    final secondary = visible(scheme.secondary);
    final tertiary = visible(scheme.tertiary);
    final error = legible(scheme.error);
    final success = legible(colors.success(brightness));
    final warning = legible(colors.warning(brightness));
    final info = legible(colors.info(brightness));
    final income = legible(colors.income(brightness));
    final expense = legible(colors.expense(brightness));

    // Supporting text is a muted onSurface. Muting it far enough to look
    // secondary takes it under WCAG AA on the deeper containers (input
    // fills, chips, menus), so mute first, then pull back only as far as
    // legibility on the *deepest* container needs. That also guarantees it
    // on every lighter surface above it.
    final textSecondary = Contrast.ensureContrast(
      _interpolate(scheme.onSurface, surface, isDark ? 0.35 : 0.45),
      containerHigh,
    );
    // Tertiary text is for small incidental labels; it still has to be
    // readable as text, just visibly quieter than [textSecondary].
    // It is checked on the lightest (light) / darkest-but-raised (dark)
    // surface a small label sits on, so it holds on both page and card.
    final textTertiary = Contrast.ensureContrast(
      _interpolate(scheme.onSurface, surface, isDark ? 0.55 : 0.65),
      isDark ? cardColor : bg,
    );

    // Material 3 draws outlines at ~3:1 and hairlines at ~1.6:1 against the
    // surface. Derive both from onSurface so they stay tinted like the
    // palette, then hold them to those minimums.
    final outline = Contrast.ensureContrast(
      _interpolate(scheme.onSurface, surface, isDark ? 0.55 : 0.62),
      surface,
      minRatio: Contrast.large,
    );
    final divider = Contrast.ensureContrast(
      _interpolate(scheme.onSurface, surface, isDark ? 0.78 : 0.84),
      surface,
      minRatio: 1.6,
    );

    final tintAlpha = isDark ? _tintAlphaDark : _tintAlphaLight;
    Color tint(Color c) =>
        Color.alphaBlend(c.withValues(alpha: tintAlpha), surface);

    return AppColorTokens(
      primary: primary,
      primaryLight: _lighten(primary, 0.12),
      primaryDark: _darken(primary, 0.12),
      secondary: secondary,
      secondaryLight: _lighten(secondary, 0.12),
      secondaryDark: _darken(secondary, 0.12),
      tertiary: tertiary,
      tertiaryLight: _lighten(tertiary, 0.12),
      tertiaryDark: _darken(tertiary, 0.12),
      income: income,
      expense: expense,
      success: success,
      warning: warning,
      error: error,
      info: info,
      background: bg,
      surface: surface,
      surfaceContainer: container,
      surfaceContainerHigh: containerHigh,
      surfaceContainerHighest: containerHighest,
      card: cardColor,
      textPrimary: scheme.onSurface,
      textSecondary: textSecondary,
      textTertiary: textTertiary,
      divider: divider,
      outline: outline,
      successContainer: tint(success),
      warningContainer: tint(warning),
      errorContainer: tint(error),
    );
  }

  @override
  AppColorTokens copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? secondary,
    Color? secondaryLight,
    Color? secondaryDark,
    Color? tertiary,
    Color? tertiaryLight,
    Color? tertiaryDark,
    Color? income,
    Color? expense,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? background,
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? card,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
    Color? outline,
    Color? successContainer,
    Color? warningContainer,
    Color? errorContainer,
  }) {
    return AppColorTokens(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      secondary: secondary ?? this.secondary,
      secondaryLight: secondaryLight ?? this.secondaryLight,
      secondaryDark: secondaryDark ?? this.secondaryDark,
      tertiary: tertiary ?? this.tertiary,
      tertiaryLight: tertiaryLight ?? this.tertiaryLight,
      tertiaryDark: tertiaryDark ?? this.tertiaryDark,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
      outline: outline ?? this.outline,
      successContainer: successContainer ?? this.successContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      errorContainer: errorContainer ?? this.errorContainer,
    );
  }

  @override
  AppColorTokens lerp(AppColorTokens? other, double t) {
    if (other is! AppColorTokens) return this;
    return AppColorTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryLight: Color.lerp(secondaryLight, other.secondaryLight, t)!,
      secondaryDark: Color.lerp(secondaryDark, other.secondaryDark, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      tertiaryLight: Color.lerp(tertiaryLight, other.tertiaryLight, t)!,
      tertiaryDark: Color.lerp(tertiaryDark, other.tertiaryDark, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      surfaceContainerHigh: Color.lerp(
        surfaceContainerHigh,
        other.surfaceContainerHigh,
        t,
      )!,
      surfaceContainerHighest: Color.lerp(
        surfaceContainerHighest,
        other.surfaceContainerHighest,
        t,
      )!,
      card: Color.lerp(card, other.card, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
    );
  }

  // ---------------------------------------------------------------------------
  // Color manipulation helpers
  // ---------------------------------------------------------------------------

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightened = hsl.withLightness((hsl.lightness + amount).clamp(0, 1));
    return lightened.toColor();
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0, 1));
    return darkened.toColor();
  }

  static Color _interpolate(Color a, Color b, double t) {
    return Color.lerp(a, b, t)!;
  }
}

/// Convenience extension on [BuildContext] for accessing the semantic tokens.
extension AppColorTokensExtension on BuildContext {
  /// Semantic color tokens for the current theme.
  ///
  /// Falls back to the default palette when the enclosing [ThemeData] was not
  /// built by `AppTheme` (e.g. in isolated widget tests), so widgets never
  /// throw for a missing extension.
  AppColorTokens get appColors {
    final theme = Theme.of(this);
    return theme.extension<AppColorTokens>() ??
        AppColorTokens.fromPalette(
          ColorPalette.defaultPalette,
          theme.brightness,
        );
  }
}
