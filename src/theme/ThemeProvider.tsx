import {
  createContext,
  useContext,
  useMemo,
  type PropsWithChildren,
} from 'react';
import { useColorScheme } from 'react-native';
import { useAppSelector } from '../store/hooks';
import { selectThemeMode } from '../store/slices/settingsSlice';
import { themeFor, type ColorScheme, type Theme } from './theme';

const ThemeContext = createContext<Theme | null>(null);

/**
 * Resolves the user's stored theme mode against the OS scheme and publishes
 * the result on context. Read it with `useTheme()`.
 */
export function ThemeProvider({ children }: PropsWithChildren) {
  const mode = useAppSelector(selectThemeMode);
  const systemScheme = useColorScheme();

  const theme = useMemo(() => {
    const scheme: ColorScheme =
      mode === 'system' ? (systemScheme ?? 'light') : mode;
    return themeFor(scheme);
  }, [mode, systemScheme]);

  return (
    <ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>
  );
}

export function useTheme(): Theme {
  const theme = useContext(ThemeContext);
  if (theme === null) {
    throw new Error('useTheme must be used inside <ThemeProvider>');
  }
  return theme;
}

/**
 * Builds a StyleSheet from the active theme and memoizes it per theme object.
 *
 * `factory` must be defined outside the component (or otherwise be stable) —
 * it is intentionally left out of the dependency list so that an inline arrow
 * does not rebuild the stylesheet on every render.
 */
export function useThemedStyles<T>(factory: (theme: Theme) => T): T {
  const theme = useTheme();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  return useMemo(() => factory(theme), [theme]);
}
