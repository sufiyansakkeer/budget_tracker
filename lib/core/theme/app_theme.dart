import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../../features/settings/domain/entities/color_palette_entity.dart';
import 'color_palettes.dart';
import 'app_colors_extension.dart';

/// Central Material 3 theme for the Smart Monivo.
///
/// Both light and dark themes share the same typography scale and component
/// shapes so the whole app feels consistent, while the dark theme uses an
/// intentional surface hierarchy (not a simple inversion of light).
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Typography scale
  // ---------------------------------------------------------------------------
  static const TextTheme _textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.bold,
      height: 1.2,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      height: 1.25,
      letterSpacing: -0.25,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
  );

  /// Convenience getters that use the Default palette.
  static ThemeData get lightTheme =>
      buildLightTheme(ColorPalette.defaultPalette);
  static ThemeData get darkTheme => buildDarkTheme(ColorPalette.defaultPalette);

  /// Builds a light [ThemeData] for the given [palette].
  static ThemeData buildLightTheme(ColorPalette palette) =>
      _buildTheme(Brightness.light, palette);

  /// Builds a dark [ThemeData] for the given [palette].
  static ThemeData buildDarkTheme(ColorPalette palette) =>
      _buildTheme(Brightness.dark, palette);

  static ThemeData _buildTheme(Brightness brightness, ColorPalette palette) {
    final isDark = brightness == Brightness.dark;
    final colors = getPaletteColors(palette);
    final baseScheme = isDark ? colors.darkScheme : colors.lightScheme;

    // Semantic token colors
    final bg = isDark
        ? AppColorTokens.fromPalette(palette, brightness).background
        : AppColorTokens.fromPalette(palette, brightness).background;
    final surfaceContainer = AppColorTokens.fromPalette(
      palette,
      brightness,
    ).surfaceContainer;
    final surfaceContainerHigh = AppColorTokens.fromPalette(
      palette,
      brightness,
    ).surfaceContainerHigh;
    final outline = AppColorTokens.fromPalette(palette, brightness).outline;
    final dividerColor = AppColorTokens.fromPalette(
      palette,
      brightness,
    ).divider;
    final textSecondary = AppColorTokens.fromPalette(
      palette,
      brightness,
    ).textSecondary;
    final cardColor = AppColorTokens.fromPalette(palette, brightness).card;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: baseScheme.primary,
      onPrimary: baseScheme.onPrimary,
      secondary: baseScheme.secondary,
      onSecondary: baseScheme.onSecondary,
      error: baseScheme.error,
      onError: baseScheme.onError,
      surface: baseScheme.surface,
      onSurface: baseScheme.onSurface,
      surfaceContainerHighest: surfaceContainerHigh,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainer: surfaceContainer,
      surfaceContainerLow: surfaceContainer,
      surfaceContainerLowest: baseScheme.surface,
      surfaceTint: surfaceContainer,
      outline: outline,
      outlineVariant: dividerColor,
      shadow: Colors.black,
      inverseSurface: isDark
          ? colors.lightScheme.surface
          : colors.darkScheme.surface,
      onInverseSurface: isDark
          ? colors.lightScheme.onSurface
          : colors.darkScheme.onSurface,
      inversePrimary: isDark
          ? colors.lightScheme.primary
          : colors.darkScheme.primary,
      primaryContainer: isDark
          ? surfaceContainerHigh
          : baseScheme.primary.withValues(alpha: 0.12),
      onPrimaryContainer: isDark
          ? baseScheme.primary
          : _darken(baseScheme.primary, 0.2),
      secondaryContainer: isDark
          ? surfaceContainerHigh
          : baseScheme.secondary.withValues(alpha: 0.12),
      onSecondaryContainer: isDark
          ? baseScheme.secondary
          : baseScheme.secondary,
      tertiary: baseScheme.tertiary,
      onTertiary: baseScheme.onTertiary,
      tertiaryContainer: baseScheme.tertiaryContainer,
      onTertiaryContainer: baseScheme.onTertiaryContainer,
      errorContainer: baseScheme.error.withValues(alpha: isDark ? 0.2 : 0.12),
      onErrorContainer: baseScheme.error,
    );

    // Compute the theme extension
    final appColorTokens = AppColorTokens.fromPalette(palette, brightness);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: _textTheme,
      extensions: [appColorTokens],
    );

    final appBarTheme = AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );

    final cardTheme = CardThemeData(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLg,
        side: BorderSide(color: dividerColor.withValues(alpha: 0.6)),
      ),
    );

    final inputDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      labelStyle: TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
      prefixIconColor: textSecondary,
      suffixIconColor: textSecondary,
    );

    final filledButtonTheme = FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.smd,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        textStyle: _textTheme.labelLarge,
      ),
    );

    final textButtonTheme = TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        minimumSize: const Size(48, 40),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
        textStyle: _textTheme.labelLarge,
      ),
    );

    final outlinedButtonTheme = OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        textStyle: _textTheme.labelLarge,
      ),
    );

    final navigationBarTheme = NavigationBarThemeData(
      backgroundColor: baseScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: colorScheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return _textTheme.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected)
              ? colorScheme.onSurface
              : textSecondary,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : textSecondary,
        );
      }),
    );

    final chipTheme = ChipThemeData(
      backgroundColor: surfaceContainer,
      selectedColor: colorScheme.primaryContainer,
      disabledColor: surfaceContainer,
      labelStyle: _textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      secondaryLabelStyle: _textTheme.labelMedium?.copyWith(
        color: colorScheme.onPrimaryContainer,
      ),
      checkmarkColor: colorScheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        side: BorderSide(color: dividerColor, width: 1),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.xs,
      ),
      iconTheme: IconThemeData(size: 18, color: textSecondary),
    );

    final bottomSheetTheme = BottomSheetThemeData(
      backgroundColor: baseScheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: dividerColor,
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxWidth: MediaQueryData.fromView(
          WidgetsBinding.instance.platformDispatcher.views.first,
        ).size.width,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
    );

    final dialogTheme = DialogThemeData(
      backgroundColor: baseScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
      titleTextStyle: _textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: _textTheme.bodyMedium?.copyWith(
        color: textSecondary,
        height: 1.5,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
    );

    final snackBarTheme = SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? surfaceContainerHigh : baseScheme.surface,
      contentTextStyle: _textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );

    final progressIndicatorTheme = ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: surfaceContainerHigh,
    );

    final listTileTheme = ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      iconColor: textSecondary,
      textColor: colorScheme.onSurface,
      titleTextStyle: _textTheme.bodyLarge,
      subtitleTextStyle: _textTheme.bodySmall?.copyWith(color: textSecondary),
    );

    final dividerTheme = DividerThemeData(
      color: dividerColor,
      thickness: 1,
      space: 1,
    );

    final floatingActionButtonTheme = FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 2,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
    );

    final switchTheme = SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.onPrimary;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return null;
      }),
    );

    final tabBarTheme = TabBarThemeData(
      labelColor: colorScheme.onSurface,
      unselectedLabelColor: textSecondary,
      labelStyle: _textTheme.labelLarge,
      unselectedLabelStyle: _textTheme.labelLarge,
      indicatorColor: colorScheme.primary,
      dividerColor: dividerColor,
    );

    final sliderTheme = SliderThemeData(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: surfaceContainerHigh,
      thumbColor: colorScheme.primary,
      overlayColor: colorScheme.primary.withValues(alpha: 0.12),
    );

    final tooltipTheme = TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? surfaceContainerHigh : colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      textStyle: _textTheme.bodySmall?.copyWith(
        color: isDark
            ? colors.darkScheme.onSurface
            : colors.lightScheme.onSurface,
      ),
    );

    return base.copyWith(
      appBarTheme: appBarTheme,
      cardTheme: cardTheme,
      inputDecorationTheme: inputDecorationTheme,
      filledButtonTheme: filledButtonTheme,
      textButtonTheme: textButtonTheme,
      outlinedButtonTheme: outlinedButtonTheme,
      navigationBarTheme: navigationBarTheme,
      chipTheme: chipTheme,
      bottomSheetTheme: bottomSheetTheme,
      dialogTheme: dialogTheme,
      snackBarTheme: snackBarTheme,
      progressIndicatorTheme: progressIndicatorTheme,
      listTileTheme: listTileTheme,
      dividerTheme: dividerTheme,
      floatingActionButtonTheme: floatingActionButtonTheme,
      switchTheme: switchTheme,
      tabBarTheme: tabBarTheme,
      sliderTheme: sliderTheme,
      tooltipTheme: tooltipTheme,
    );
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0, 1)).toColor();
  }
}
