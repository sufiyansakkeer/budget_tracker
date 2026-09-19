/**
 * Semantic color tokens, ported from the Flutter app's `AppColors`.
 *
 * Cobalt + Sky + Mint palette. Raw brand values live in `palette`; screens
 * should never reach for those directly — they consume the resolved
 * `lightColors` / `darkColors` maps through `useTheme()`.
 */

export const palette = {
  primary: '#3155D4',
  primaryLight: '#4C6FE3',
  primaryDark: '#2543AD',

  secondary: '#159A9C',
  secondaryLight: '#31B6B5',
  secondaryDark: '#0E7779',

  accent: '#F0A35E',

  success: '#239B70',
  successLight: '#43B98B',
  successDark: '#197454',

  warning: '#D89432',
  warningLight: '#E9AA50',
  warningDark: '#AE6D1F',

  error: '#D65C62',
  errorLight: '#E4777C',
  errorDark: '#B8454B',

  info: '#4A8CC7',

  white: '#FFFFFF',
  black: '#000000',
};

/** Per-category accent colors, keyed by the category ids seeded into the DB. */
export const categoryColors = {
  food: '#E87568',
  grocery: '#51A276',
  fuel: '#E3A050',
  shopping: '#D0A747',
  rent: '#55A8B2',
  emi: '#45A77F',
  bills: '#D76060',
  travel: '#5D82CF',
  entertainment: '#846EB0',
  health: '#D27B9D',
  education: '#48A6A5',
  salary_adjustment: '#818B9B',
  others: '#818B9B',
} as const;

export const lightColors = {
  primary: palette.primary,
  primaryLight: palette.primaryLight,
  primaryDark: palette.primaryDark,
  primaryContainer: '#E8ECFC',
  onPrimary: '#FFFFFF',

  secondary: palette.secondary,
  secondaryContainer: '#E1F4F3',
  onSecondary: '#FFFFFF',

  accent: palette.accent,

  background: '#F6F8FC',
  surface: '#FFFFFF',
  surfaceContainer: '#EEF2F8',
  surfaceContainerHigh: '#E2E8F2',
  card: '#FFFFFF',

  textPrimary: '#182033',
  textSecondary: '#68738A',
  textTertiary: '#969EAF',
  textOnPrimary: '#FFFFFF',

  divider: '#E1E6EF',
  outline: '#CFD6E2',

  success: palette.success,
  successContainer: '#E3F5ED',
  warning: palette.warning,
  warningContainer: '#FFF1DD',
  error: palette.error,
  errorContainer: '#FBE8E9',
  info: palette.info,

  /** Finance-specific semantics used by money-bearing UI. */
  income: '#239B70',
  expense: '#D65C62',
  remaining: '#3155D4',
  savings: '#159A9C',
  neutralFinance: '#68738A',

  /** Translucent scrim behind modals and bottom sheets. */
  scrim: 'rgba(11, 16, 32, 0.45)',
};

/**
 * `lightColors` is intentionally not `as const`: its values must widen to
 * `string` so `darkColors` can supply different hexes for the same keys.
 */
export type AppColors = typeof lightColors;
export type ColorToken = keyof AppColors;

/** Dark values are keyed identically to `lightColors` so the two are swappable. */
export const darkColors: AppColors = {
  primary: palette.primaryLight,
  primaryLight: '#6E8BEB',
  primaryDark: palette.primary,
  primaryContainer: '#202D60',
  onPrimary: '#FFFFFF',

  secondary: palette.secondaryLight,
  secondaryContainer: '#123B3D',
  onSecondary: '#FFFFFF',

  accent: palette.accent,

  background: '#0B1020',
  surface: '#11172A',
  surfaceContainer: '#19223A',
  surfaceContainerHigh: '#222D49',
  card: '#151D32',

  textPrimary: '#F4F7FF',
  textSecondary: '#AAB4C8',
  textTertiary: '#77839B',
  textOnPrimary: '#FFFFFF',

  divider: '#29344D',
  outline: '#3A4763',

  success: palette.successLight,
  successContainer: '#123A2E',
  warning: palette.warningLight,
  warningContainer: '#3B2C17',
  error: palette.errorLight,
  errorContainer: '#3B1E21',
  info: palette.info,

  income: '#43B98B',
  expense: '#E4777C',
  remaining: '#4C6FE3',
  savings: '#31B6B5',
  neutralFinance: '#AAB4C8',

  scrim: 'rgba(0, 0, 0, 0.6)',
};


