import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/settings/domain/entities/color_palette_entity.dart';
import '../constants/app_spacing.dart';
import 'app_colors_extension.dart';
import 'color_palettes.dart';
import 'contrast.dart';

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

    // Semantic tokens are computed exactly once per theme build. They are
    // the single source of truth: every ColorScheme role below is mapped from
    // a token, and the tokens already guarantee legibility (see
    // [AppColorTokens.fromPalette]).
    final tokens = AppColorTokens.fromPalette(palette, brightness);
    final bg = tokens.background;
    final surface = tokens.surface;
    final surfaceContainer = tokens.surfaceContainer;
    final surfaceContainerHigh = tokens.surfaceContainerHigh;
    final surfaceContainerHighest = tokens.surfaceContainerHighest;
    final outline = tokens.outline;
    final dividerColor = tokens.divider;
    final textSecondary = tokens.textSecondary;
    final cardColor = tokens.card;

    // "On" colours are held to AA against the colour they sit on. Container
    // "on" colours are the accent itself made legible on its container, so a
    // tinted chip, nav indicator or icon tile keeps the brand hue in both
    // themes instead of collapsing to near-black / near-white.
    Color on(Color foreground, Color background) =>
        Contrast.ensureContrast(foreground, background);

    final inverseSurface = isDark
        ? colors.lightScheme.surface
        : colors.darkScheme.surface;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.primary,
      onPrimary: on(baseScheme.onPrimary, tokens.primary),
      primaryContainer: baseScheme.primaryContainer,
      onPrimaryContainer: on(tokens.primary, baseScheme.primaryContainer),
      secondary: tokens.secondary,
      onSecondary: on(baseScheme.onSecondary, tokens.secondary),
      secondaryContainer: baseScheme.secondaryContainer,
      onSecondaryContainer: on(tokens.secondary, baseScheme.secondaryContainer),
      tertiary: tokens.tertiary,
      onTertiary: on(baseScheme.onTertiary, tokens.tertiary),
      tertiaryContainer: baseScheme.tertiaryContainer,
      onTertiaryContainer: on(tokens.tertiary, baseScheme.tertiaryContainer),
      error: tokens.error,
      onError: on(baseScheme.onError, tokens.error),
      errorContainer: baseScheme.errorContainer,
      onErrorContainer: on(tokens.error, baseScheme.errorContainer),
      surface: surface,
      onSurface: baseScheme.onSurface,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: isDark ? bg : surface,
      surfaceContainerLow: cardColor,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      // Every component theme below disables surface tint explicitly; making
      // the scheme value transparent keeps any un-themed Material honest too.
      surfaceTint: Colors.transparent,
      outline: outline,
      outlineVariant: dividerColor,
      shadow: Colors.black,
      inverseSurface: inverseSurface,
      onInverseSurface: isDark
          ? colors.lightScheme.onSurface
          : colors.darkScheme.onSurface,
      inversePrimary: on(
        isDark ? colors.lightScheme.primary : colors.darkScheme.primary,
        inverseSurface,
      ),
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
        side: BorderSide(color: dividerColor),
      ),
    );

    final inputDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      // The fill alone is only ~1.1:1 against a card, so a hairline keeps the
      // field a visible shape on every surface in both themes.
      border: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: BorderSide(color: dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: BorderSide(color: dividerColor),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: BorderSide(color: dividerColor.withValues(alpha: 0.5)),
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
      hintStyle: TextStyle(color: textSecondary),
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
          // Material's 38% reads as barely-there on a tinted fill; 50% keeps
          // the label understandable while still clearly not actionable.
          return colorScheme.onSurface.withValues(alpha: 0.5);
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

    // Navigation bar: Material 3 places it on surfaceContainer so it reads
    // as its own surface over the page. The indicator is the primary
    // container held to a visible ratio against that bar, and the selected
    // icon is primary made legible on the indicator — so both themes keep a
    // brand-coloured selected tab that is guaranteed readable.
    final navBackground = surfaceContainer;
    // Near black, equal ratios look fainter, so the dark floor is higher.
    final navIndicator = Contrast.ensureContrast(
      colorScheme.primaryContainer,
      navBackground,
      minRatio: isDark ? 1.8 : 1.4,
    );
    final navSelectedIcon = Contrast.ensureContrast(
      colorScheme.primary,
      navIndicator,
    );

    final navigationBarTheme = NavigationBarThemeData(
      backgroundColor: navBackground,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      height: AppSizes.navBarHeight,
      indicatorColor: navIndicator,
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
          color: selected ? navSelectedIcon : textSecondary,
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

    // Raised surfaces (sheets, dialogs, pickers). In light they are the
    // plain surface; in dark they use the card tone so they sit *above* the
    // page and the inputs inside them still step lighter again.
    final raisedSurface = isDark ? cardColor : surface;

    final bottomSheetTheme = BottomSheetThemeData(
      backgroundColor: raisedSurface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: raisedSurface,
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
      backgroundColor: raisedSurface,
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
      color: isDark ? surfaceContainerHigh : surface,
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

    // Tracks use the highest container so they stay visible on a card (the
    // "high" step is only ~1.2:1 against it in light).
    final progressIndicatorTheme = ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: surfaceContainerHighest,
      circularTrackColor: surfaceContainerHighest,
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
      inactiveTrackColor: surfaceContainerHighest,
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
      backgroundColor: raisedSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: lgShape,
      headerBackgroundColor: colorScheme.primaryContainer,
      headerForegroundColor: colorScheme.onPrimaryContainer,
      dayShape: const WidgetStatePropertyAll(CircleBorder()),
      todayBorder: BorderSide(color: colorScheme.primary),
    );

    final timePickerTheme = TimePickerThemeData(
      backgroundColor: raisedSurface,
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
          isDark ? surfaceContainerHigh : surface,
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
}
