import type { PropsWithChildren } from 'react';
import { QueryClientProvider } from '@tanstack/react-query';
import { Provider as ReduxProvider } from 'react-redux';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { ErrorBoundary } from '../../components/ErrorBoundary';
// Imported for its side effect: initialises i18next before the first render.
import '../../localization/i18n';
import { store } from '../../store/store';
import { ThemeProvider } from '../../theme/ThemeProvider';
import { queryClient } from '../config/queryClient';

/**
 * Provider stack, outermost first.
 *
 * Order matters: the theme reads settings from Redux, and the error boundary
 * sits inside the theme so its fallback UI is themed.
 */
export function AppProviders({ children }: PropsWithChildren) {
  return (
    <ReduxProvider store={store}>
      <QueryClientProvider client={queryClient}>
        <SafeAreaProvider>
          <ThemeProvider>
            <ErrorBoundary>{children}</ErrorBoundary>
          </ThemeProvider>
        </SafeAreaProvider>
      </QueryClientProvider>
    </ReduxProvider>
  );
}
