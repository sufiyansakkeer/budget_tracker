import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

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

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      onSurface: isDark
          ? AppColors.textPrimaryDark
          : AppColors.textPrimaryLight,
    );

    final surface = scheme.surface;
    final surfaceContainer = isDark
        ? AppColors.surfaceContainerDark
        : AppColors.surfaceContainerLight;
    final surfaceContainerHigh = isDark
        ? AppColors.surfaceContainerHighDark
        : AppColors.surfaceContainerHighLight;
    final outline = isDark ? AppColors.outlineDark : AppColors.outlineLight;
    final dividerColor = isDark
        ? AppColors.dividerDark
        : AppColors.dividerLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      secondary: scheme.secondary,
      onSecondary: scheme.onSecondary,
      error: scheme.error,
      onError: scheme.onError,
      surface: surface,
      onSurface: scheme.onSurface,
      surfaceContainerHighest: surfaceContainerHigh,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainer: surfaceContainer,
      surfaceContainerLow: surfaceContainer,
      surfaceContainerLowest: surface,
      surfaceTint: surfaceContainer,
      outline: outline,
      outlineVariant: dividerColor,
      shadow: Colors.black,
      inverseSurface: isDark ? AppColors.surfaceLight : AppColors.surfaceDark,
      onInverseSurface: isDark
          ? AppColors.textPrimaryLight
          : AppColors.textPrimaryDark,
      inversePrimary: isDark ? AppColors.primaryLight : AppColors.primaryDark,
      primaryContainer: isDark
          ? AppColors.surfaceContainerHighDark
          : AppColors.primary.withValues(alpha: 0.12),
      onPrimaryContainer: isDark
          ? AppColors.primaryLight
          : AppColors.primaryDark,
      secondaryContainer: isDark
          ? AppColors.surfaceContainerHighDark
          : AppColors.secondary.withValues(alpha: 0.12),
      onSecondaryContainer: isDark
          ? AppColors.secondaryLight
          : AppColors.secondary,
      tertiary: scheme.tertiary,
      onTertiary: scheme.onTertiary,
      tertiaryContainer: scheme.tertiaryContainer,
      onTertiaryContainer: scheme.onTertiaryContainer,
      errorContainer: AppColors.error.withValues(alpha: isDark ? 0.2 : 0.12),
      onErrorContainer: AppColors.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      textTheme: _textTheme,
    );

    final appBarTheme = AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      iconTheme: IconThemeData(color: scheme.onSurface),
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
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      labelStyle: TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
      prefixIconColor: textSecondary,
      suffixIconColor: textSecondary,
    );

    final filledButtonTheme = FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
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
        foregroundColor: scheme.primary,
        minimumSize: const Size(48, 40),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
        textStyle: _textTheme.labelLarge,
      ),
    );

    final outlinedButtonTheme = OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        textStyle: _textTheme.labelLarge,
      ),
    );

    final navigationBarTheme = NavigationBarThemeData(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return _textTheme.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : textSecondary,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : textSecondary,
        );
      }),
    );

    final chipTheme = ChipThemeData(
      backgroundColor: surfaceContainer,
      selectedColor: scheme.primaryContainer,
      labelStyle: _textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      secondaryLabelStyle: _textTheme.labelMedium?.copyWith(
        color: scheme.onPrimaryContainer,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        side: BorderSide(color: dividerColor),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.xs,
      ),
    );

    final bottomSheetTheme = BottomSheetThemeData(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
    );

    final dialogTheme = DialogThemeData(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
      titleTextStyle: _textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      contentTextStyle: _textTheme.bodyMedium?.copyWith(color: textSecondary),
    );

    final snackBarTheme = SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? surfaceContainerHigh : surface,
      contentTextStyle: _textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
    );

    final progressIndicatorTheme = ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: surfaceContainerHigh,
    );

    final listTileTheme = ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      iconColor: textSecondary,
      textColor: scheme.onSurface,
      titleTextStyle: _textTheme.bodyLarge,
      subtitleTextStyle: _textTheme.bodySmall?.copyWith(color: textSecondary),
    );

    final dividerTheme = DividerThemeData(
      color: dividerColor,
      thickness: 1,
      space: 1,
    );

    final floatingActionButtonTheme = FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusXl),
    );

    final switchTheme = SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return null;
      }),
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
    );
  }
}
