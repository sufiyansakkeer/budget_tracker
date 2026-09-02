import 'package:flutter/material.dart';

import '../../features/settings/domain/entities/color_palette_entity.dart';
import 'color_palettes.dart';

/// Semantic color tokens that adapt to the selected [ColorPalette] and
/// current [Brightness].
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

    // Derive surface hierarchy from the scheme.
    final bg = isDark
        ? _darken(scheme.surface, 0.15)
        : _lighten(scheme.surface, 0.04);
    final container = isDark
        ? _lighten(scheme.surface, 0.06)
        : _darken(scheme.surface, 0.04);
    final containerHigh = isDark
        ? _lighten(scheme.surface, 0.12)
        : _darken(scheme.surface, 0.08);
    final cardColor = isDark
        ? _lighten(scheme.surface, 0.03)
        : _lighten(scheme.surface, 0.0);

    return AppColorTokens(
      primary: scheme.primary,
      primaryLight: _lighten(scheme.primary, 0.12),
      primaryDark: _darken(scheme.primary, 0.12),
      secondary: scheme.secondary,
      secondaryLight: _lighten(scheme.secondary, 0.12),
      secondaryDark: _darken(scheme.secondary, 0.12),
      tertiary: scheme.tertiary,
      tertiaryLight: _lighten(scheme.tertiary, 0.12),
      tertiaryDark: _darken(scheme.tertiary, 0.12),
      income: colors.income(brightness),
      expense: colors.expense(brightness),
      success: colors.success(brightness),
      warning: colors.warning(brightness),
      error: scheme.error,
      info: colors.info(brightness),
      background: bg,
      surface: scheme.surface,
      surfaceContainer: container,
      surfaceContainerHigh: containerHigh,
      card: cardColor,
      textPrimary: scheme.onSurface,
      textSecondary: _interpolate(
        scheme.onSurface,
        scheme.surface,
        isDark ? 0.35 : 0.45,
      ),
      textTertiary: _interpolate(
        scheme.onSurface,
        scheme.surface,
        isDark ? 0.55 : 0.65,
      ),
      divider: _interpolate(
        scheme.onSurface,
        scheme.surface,
        isDark ? 0.82 : 0.88,
      ),
      outline: _interpolate(
        scheme.onSurface,
        scheme.surface,
        isDark ? 0.75 : 0.82,
      ),
      successContainer: isDark
          ? _darken(colors.success(brightness), 0.65)
          : _lighten(colors.success(brightness), 0.75),
      warningContainer: isDark
          ? _darken(colors.warning(brightness), 0.65)
          : _lighten(colors.warning(brightness), 0.80),
      errorContainer: isDark
          ? _darken(scheme.error, 0.60)
          : _lighten(scheme.error, 0.80),
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
  AppColorTokens get appColors => Theme.of(this).extension<AppColorTokens>()!;
}
