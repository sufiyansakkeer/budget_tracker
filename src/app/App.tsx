import { useEffect, useState } from 'react';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { AppText } from '../components/AppText';
import { seedCategories } from '../database/seed';
import { RootNavigator } from '../navigation/RootNavigator';
import { useAppDispatch, useAppSelector } from '../store/hooks';
import { setInitialized } from '../store/slices/appSlice';
import { useTheme } from '../theme/ThemeProvider';
import { AppProviders } from './providers/appProvider';

function App() {
  return (
    <AppProviders>
      <AppContent />
    </AppProviders>
  );
}

/**
 * Holds the app on a loading view until the database is ready.
 *
 * Category seeding has to finish before any screen renders — the expense form
 * and the history list both assume the system categories exist.
 */
function AppContent() {
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const isInitialized = useAppSelector(state => state.app.isInitialized);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;

    seedCategories()
      .then(() => {
        if (!cancelled) dispatch(setInitialized(true));
      })
      .catch((cause: Error) => {
        if (!cancelled) setError(cause);
      });

    return () => {
      cancelled = true;
    };
  }, [dispatch]);

  if (error) {
    return (
      <View style={[styles.centered, { backgroundColor: theme.colors.background }]}>
        <AppText variant="title" align="center">
          Could not open the database
        </AppText>
        <AppText
          variant="bodySmall"
          color="textSecondary"
          align="center"
          style={styles.message}
        >
          {error.message}
        </AppText>
      </View>
    );
  }

  if (!isInitialized) {
    return (
      <View style={[styles.centered, { backgroundColor: theme.colors.background }]}>
        <ActivityIndicator color={theme.colors.primary} />
      </View>
    );
  }

  return <RootNavigator />;
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  message: { marginTop: 8 },
});

export default App;
