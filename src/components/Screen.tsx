import type { PropsWithChildren } from 'react';
import { StatusBar, StyleSheet, View, type ViewStyle } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../theme/ThemeProvider';

interface ScreenProps extends PropsWithChildren {
  /** Pad the top inset. Turn off when a header draws into the status bar. */
  edgeTop?: boolean;
  /** Pad the bottom inset. Turn off inside a tab navigator, which pads itself. */
  edgeBottom?: boolean;
  padded?: boolean;
  style?: ViewStyle;
}

/**
 * Screen container: themed background, status-bar style, and safe-area insets.
 *
 * Insets are applied as padding on a plain `View` rather than using
 * `SafeAreaView`, so a screen can opt out per edge — a list that scrolls under
 * the home indicator wants the bottom inset on its content, not on the frame.
 */
export function Screen({
  children,
  edgeTop = true,
  edgeBottom = false,
  padded = false,
  style,
}: ScreenProps) {
  const theme = useTheme();
  const insets = useSafeAreaInsets();

  return (
    <View
      style={[
        styles.root,
        {
          backgroundColor: theme.colors.background,
          paddingTop: edgeTop ? insets.top : 0,
          paddingBottom: edgeBottom ? insets.bottom : 0,
          paddingHorizontal: padded ? theme.spacing.md : 0,
        },
        style,
      ]}
    >
      {/* RN 0.87 drives the Android status bar through edge-to-edge, so
          `backgroundColor` is gone — the bar sits over this View's background. */}
      <StatusBar
        barStyle={theme.scheme === 'dark' ? 'light-content' : 'dark-content'}
      />
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
});
