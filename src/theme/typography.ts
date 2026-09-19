import { Platform, type TextStyle } from 'react-native';

/**
 * Type scale. Each entry is a partial `TextStyle` with no color — color comes
 * from the active theme at the call site, so one scale serves light and dark.
 */

const fontFamily = Platform.select({
  ios: 'System',
  android: 'sans-serif',
  default: 'System',
});

const fontFamilyMedium = Platform.select({
  ios: 'System',
  android: 'sans-serif-medium',
  default: 'System',
});

export const fontWeight = {
  regular: '400',
  medium: '500',
  semibold: '600',
  bold: '700',
} as const satisfies Record<string, TextStyle['fontWeight']>;

export const typography = {
  displayLarge: {
    fontFamily: fontFamilyMedium,
    fontSize: 34,
    lineHeight: 41,
    fontWeight: fontWeight.bold,
    letterSpacing: -0.5,
  },
  displaySmall: {
    fontFamily: fontFamilyMedium,
    fontSize: 28,
    lineHeight: 34,
    fontWeight: fontWeight.bold,
    letterSpacing: -0.3,
  },
  headline: {
    fontFamily: fontFamilyMedium,
    fontSize: 22,
    lineHeight: 28,
    fontWeight: fontWeight.semibold,
  },
  title: {
    fontFamily: fontFamilyMedium,
    fontSize: 18,
    lineHeight: 24,
    fontWeight: fontWeight.semibold,
  },
  subtitle: {
    fontFamily: fontFamilyMedium,
    fontSize: 16,
    lineHeight: 22,
    fontWeight: fontWeight.medium,
  },
  body: {
    fontFamily,
    fontSize: 15,
    lineHeight: 22,
    fontWeight: fontWeight.regular,
  },
  bodySmall: {
    fontFamily,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: fontWeight.regular,
  },
  label: {
    fontFamily: fontFamilyMedium,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: fontWeight.medium,
  },
  caption: {
    fontFamily,
    fontSize: 11,
    lineHeight: 15,
    fontWeight: fontWeight.regular,
    letterSpacing: 0.2,
  },
  /** Tabular figures keep money columns from jittering as digits change. */
  money: {
    fontFamily: fontFamilyMedium,
    fontSize: 20,
    lineHeight: 26,
    fontWeight: fontWeight.bold,
    fontVariant: ['tabular-nums'],
  },
} as const satisfies Record<string, TextStyle>;

export type Typography = typeof typography;
export type TypographyToken = keyof Typography;
