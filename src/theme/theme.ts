import { darkColors, lightColors, type AppColors } from './colors';
import { radius } from './radius';
import { spacing } from './spacing';
import { typography } from './typography';

/** How the user wants the app themed. `system` follows the OS setting. */
export type ThemeMode = 'light' | 'dark' | 'system';

/** The resolved scheme actually rendered — `system` has already been collapsed. */
export type ColorScheme = 'light' | 'dark';

export interface Theme {
  scheme: ColorScheme;
  colors: AppColors;
  spacing: typeof spacing;
  radius: typeof radius;
  typography: typeof typography;
  /** Elevation presets; iOS uses shadows, Android uses the elevation prop. */
  shadows: {
    card: object;
    raised: object;
  };
}

const shadowsFor = (scheme: ColorScheme) => ({
  card: {
    shadowColor: '#0B1020',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: scheme === 'light' ? 0.06 : 0.3,
    shadowRadius: 8,
    elevation: 2,
  },
  raised: {
    shadowColor: '#0B1020',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: scheme === 'light' ? 0.12 : 0.4,
    shadowRadius: 16,
    elevation: 6,
  },
});

export const lightTheme: Theme = {
  scheme: 'light',
  colors: lightColors,
  spacing,
  radius,
  typography,
  shadows: shadowsFor('light'),
};

export const darkTheme: Theme = {
  scheme: 'dark',
  colors: darkColors,
  spacing,
  radius,
  typography,
  shadows: shadowsFor('dark'),
};

export const themeFor = (scheme: ColorScheme): Theme =>
  scheme === 'dark' ? darkTheme : lightTheme;
