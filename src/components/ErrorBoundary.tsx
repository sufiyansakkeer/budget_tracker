import { Component, type ErrorInfo, type PropsWithChildren } from 'react';
import { StyleSheet, View } from 'react-native';
import { AppText } from './AppText';
import { Button } from './Button';

interface State {
  error: Error | null;
}

/**
 * Catches render errors so a single bad screen cannot white-screen the app.
 *
 * Must stay a class component: React has no hook equivalent of
 * `componentDidCatch`. It sits inside the theme provider, so the fallback is
 * themed like the rest of the app.
 */
export class ErrorBoundary extends Component<PropsWithChildren, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('[ErrorBoundary]', error, info.componentStack);
  }

  render() {
    const { error } = this.state;

    if (!error) {
      return this.props.children;
    }

    return (
      <View style={styles.root}>
        <AppText variant="title" align="center">
          Something went wrong
        </AppText>
        <AppText
          variant="bodySmall"
          color="textSecondary"
          align="center"
          style={styles.message}
        >
          {error.message}
        </AppText>
        <Button
          label="Try again"
          onPress={() => this.setState({ error: null })}
          fullWidth={false}
          style={styles.action}
        />
      </View>
    );
  }
}

const styles = StyleSheet.create({
  root: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  message: { marginTop: 8 },
  action: { marginTop: 24 },
});
