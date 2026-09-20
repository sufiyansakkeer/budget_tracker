import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/settings/domain/entities/color_palette_entity.dart';
import '../constants/app_spacing.dart';
import 'app_colors_extension.dart';
import 'color_palettes.dart';

/// Central Material 3 theme for Monivo.
///
/// Both light and dark themes share the same typography scale and component
/// shapes so the whole app feels consistent, while the dark theme uses an
/// intentional surface hierarchy (not a simple inversion of light).
///
/// Component themes follow one shape language:
/// * Cards & sheets → [AppSpacing.radiusLg]
/// * Buttons, inputs, tiles, menus → [AppSpacing.radiusMd]
/// * Chips & small tags → pill / [AppSpacing.radiusSm]
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Typography scale
  // ---------------------------------------------------------------------------
  //
  // Hierarchy used across the app:
  //   displaySmall   → hero money value (Today's Safe Spending)
  //   headlineMedium → primary money value on detail screens
  //   headlineSmall  → secondary hero values
  //   titleLarge     → screen titles
  //   titleMedium    → section titles, card titles
  //   titleSmall     → list item titles, emphasised labels
  //   bodyLarge/Medium → body copy
  //   bodySmall      → supporting descriptions
  //   labelLarge     → buttons
  //   labelMedium    → chips, metadata
  //   labelSmall     → tiny status text
  static const TextTheme _textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.75,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.5,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.25,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.15,
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
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.2,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.3,
    ),
  );

  /// Convenience getters that use the Default palette.
  static ThemeData get lightTheme =>
      buildLightTheme(ColorPalette.defaultPalette);
  static ThemeData get darkTheme => buildDarkTheme(ColorPalette.defaultPalette);

  /// System bar styling for a theme of the given [brightness].
  ///
  /// The app draws edge-to-edge, so the status and navigation bars show the
  /// app's own background. Android does not infer the icon colour from that
  /// background — it has to be told. Without this the status bar keeps light
  /// (white) icons, so on the light theme the clock, the battery and any
  /// notification icons turn white-on-white and disappear.
  ///
  /// Note the two status-bar fields mean opposite things: Android's
  /// [SystemUiOverlayStyle.statusBarIconBrightness] is the brightness of the
  /// *icons*, while iOS's [SystemUiOverlayStyle.statusBarBrightness] is the
  /// brightness of the *background* behind them.
  static SystemUiOverlayStyle systemOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }

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

    // Semantic tokens are computed exactly once per theme build.
    final tokens = AppColorTokens.fromPalette(palette, brightness);
    final bg = tokens.background;
    final surfaceContainer = tokens.surfaceContainer;
    final surfaceContainerHigh = tokens.surfaceContainerHigh;
    final outline = tokens.outline;
    final dividerColor = tokens.divider;
    final textSecondary = tokens.textSecondary;
    final cardColor = tokens.card;

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
      onSurfaceVariant: textSecondary,
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

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: _textTheme,
      extensions: [tokens],
      visualDensity: VisualDensity.standard,
    );

    final mdShape = RoundedRectangleBorder(
      borderRadius: AppSpacing.borderRadiusMd,
    );
    final lgShape = RoundedRectangleBorder(
      borderRadius: AppSpacing.borderRadiusLg,
    );

    final appBarTheme = AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      // The bar is transparent, so Material cannot derive readable status-bar
      // icons from its background — pin them to the theme instead.
      systemOverlayStyle: systemOverlayStyle(brightness),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
    );

    final cardTheme = CardThemeData(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
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
      floatingLabelStyle: TextStyle(color: colorScheme.primary),
      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
      helperStyle: _textTheme.bodySmall?.copyWith(color: textSecondary),
      errorStyle: _textTheme.bodySmall?.copyWith(color: colorScheme.error),
      prefixIconColor: textSecondary,
      suffixIconColor: textSecondary,
    );

    final primaryButtonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.12);
        }
        return colorScheme.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        return colorScheme.onPrimary;
      }),
      overlayColor: WidgetStatePropertyAll(
        colorScheme.onPrimary.withValues(alpha: 0.1),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      minimumSize: const WidgetStatePropertyAll(Size(64, AppSizes.touchTarget)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.smd,
        ),
      ),
      shape: WidgetStatePropertyAll(mdShape),
      textStyle: WidgetStatePropertyAll(_textTheme.labelLarge),
    );

    final filledButtonTheme = FilledButtonThemeData(style: primaryButtonStyle);

    // ElevatedButton is themed identically to FilledButton so legacy call sites
    // (and widget tests that cast to ElevatedButton) share one primary style.
    final elevatedButtonTheme = ElevatedButtonThemeData(
      style: primaryButtonStyle,
    );

    final textButtonTheme = TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        minimumSize: const Size(AppSizes.touchTarget, 40),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
        textStyle: _textTheme.labelLarge,
      ),
    );

    final outlinedButtonTheme = OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        minimumSize: const Size(64, AppSizes.touchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.smd,
        ),
        side: BorderSide(color: outline),
        shape: mdShape,
        textStyle: _textTheme.labelLarge,
      ),
    );

    final iconButtonTheme = IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
        shape: const CircleBorder(),
      ),
    );

    final segmentedButtonTheme = SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimaryContainer;
          }
          return textSecondary;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: dividerColor)),
        textStyle: WidgetStatePropertyAll(_textTheme.labelLarge),
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.smd),
        ),
      ),
    );

    final navigationBarTheme = NavigationBarThemeData(
      backgroundColor: baseScheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      height: AppSizes.navBarHeight,
      indicatorColor: colorScheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return _textTheme.labelSmall?.copyWith(
          color: selected ? colorScheme.onSurface : textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: AppSizes.iconLg,
          color: selected ? colorScheme.primary : textSecondary,
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
      showCheckmark: false,
      shape: const StadiumBorder(),
      side: BorderSide(color: dividerColor),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      iconTheme: IconThemeData(size: AppSizes.iconSm, color: textSecondary),
    );

    final bottomSheetTheme = BottomSheetThemeData(
      backgroundColor: baseScheme.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: baseScheme.surface,
      showDragHandle: true,
      dragHandleColor: outline,
      dragHandleSize: const Size(
        AppSizes.dragHandleWidth,
        AppSizes.dragHandleHeight,
      ),
      clipBehavior: Clip.antiAlias,
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
      shape: lgShape,
      titleTextStyle: _textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
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

    final popupMenuTheme = PopupMenuThemeData(
      color: isDark ? surfaceContainerHigh : baseScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
      shape: mdShape,
      textStyle: _textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
    );

    final snackBarTheme = SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? surfaceContainerHigh
          : colorScheme.inverseSurface,
      contentTextStyle: _textTheme.bodyMedium?.copyWith(
        color: isDark ? colorScheme.onSurface : colorScheme.onInverseSurface,
      ),
      actionTextColor: isDark
          ? colorScheme.primary
          : colorScheme.inversePrimary,
      shape: mdShape,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );

    final progressIndicatorTheme = ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: surfaceContainerHigh,
      circularTrackColor: surfaceContainerHigh,
    );

    final listTileTheme = ListTileThemeData(
      shape: mdShape,
      iconColor: textSecondary,
      textColor: colorScheme.onSurface,
      titleTextStyle: _textTheme.bodyLarge,
      subtitleTextStyle: _textTheme.bodySmall?.copyWith(color: textSecondary),
      minVerticalPadding: AppSpacing.sm,
    );

    final dividerTheme = DividerThemeData(
      color: dividerColor,
      thickness: 1,
      space: 1,
    );

    final floatingActionButtonTheme = FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      extendedTextStyle: _textTheme.labelLarge,
      extendedPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.mlg),
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
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return outline;
      }),
    );

    final checkboxTheme = CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusXs),
      side: BorderSide(color: outline, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(colorScheme.onPrimary),
    );

    final radioTheme = RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return outline;
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
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      textStyle: _textTheme.bodySmall?.copyWith(
        color: isDark ? colorScheme.onSurface : colorScheme.onInverseSurface,
      ),
    );

    final datePickerTheme = DatePickerThemeData(
      backgroundColor: baseScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: lgShape,
      headerBackgroundColor: colorScheme.primaryContainer,
      headerForegroundColor: colorScheme.onPrimaryContainer,
      dayShape: const WidgetStatePropertyAll(CircleBorder()),
      todayBorder: BorderSide(color: colorScheme.primary),
    );

    final timePickerTheme = TimePickerThemeData(
      backgroundColor: baseScheme.surface,
      elevation: 0,
      shape: lgShape,
      dialBackgroundColor: surfaceContainer,
      hourMinuteShape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      dayPeriodShape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusSm,
      ),
    );

    final dropdownMenuTheme = DropdownMenuThemeData(
      inputDecorationTheme: inputDecorationTheme,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          isDark ? surfaceContainerHigh : baseScheme.surface,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(mdShape),
      ),
    );

    const pageTransitionsTheme = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    );

    return base.copyWith(
      appBarTheme: appBarTheme,
      cardTheme: cardTheme,
      inputDecorationTheme: inputDecorationTheme,
      filledButtonTheme: filledButtonTheme,
      elevatedButtonTheme: elevatedButtonTheme,
      textButtonTheme: textButtonTheme,
      outlinedButtonTheme: outlinedButtonTheme,
      iconButtonTheme: iconButtonTheme,
      segmentedButtonTheme: segmentedButtonTheme,
      navigationBarTheme: navigationBarTheme,
      chipTheme: chipTheme,
      bottomSheetTheme: bottomSheetTheme,
      dialogTheme: dialogTheme,
      popupMenuTheme: popupMenuTheme,
      snackBarTheme: snackBarTheme,
      progressIndicatorTheme: progressIndicatorTheme,
      listTileTheme: listTileTheme,
      dividerTheme: dividerTheme,
      floatingActionButtonTheme: floatingActionButtonTheme,
      switchTheme: switchTheme,
      checkboxTheme: checkboxTheme,
      radioTheme: radioTheme,
      tabBarTheme: tabBarTheme,
      sliderTheme: sliderTheme,
      tooltipTheme: tooltipTheme,
      datePickerTheme: datePickerTheme,
      timePickerTheme: timePickerTheme,
      dropdownMenuTheme: dropdownMenuTheme,
      pageTransitionsTheme: pageTransitionsTheme,
    );
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0, 1)).toColor();
  }
}
