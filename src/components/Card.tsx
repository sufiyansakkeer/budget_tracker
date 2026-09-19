import type { PropsWithChildren } from 'react';
import {
  Pressable,
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { useTheme } from '../theme/ThemeProvider';

interface CardProps extends PropsWithChildren {
  onPress?: () => void;
  onLongPress?: () => void;
  padded?: boolean;
  style?: StyleProp<ViewStyle>;
  accessibilityLabel?: string;
}

/** Surface container. Renders as a Pressable only when `onPress` is given. */
export function Card({
  children,
  onPress,
  onLongPress,
  padded = true,
  style,
  accessibilityLabel,
}: CardProps) {
  const theme = useTheme();

  const cardStyle: StyleProp<ViewStyle> = [
    styles.card,
    theme.shadows.card,
    {
      backgroundColor: theme.colors.card,
      borderRadius: theme.radius.md,
      borderColor: theme.colors.divider,
      padding: padded ? theme.spacing.md : 0,
    },
    style,
  ];

  if (!onPress && !onLongPress) {
    return <View style={cardStyle}>{children}</View>;
  }

  return (
    <Pressable
      onPress={onPress}
      onLongPress={onLongPress}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      style={({ pressed }) => [cardStyle, pressed && styles.pressed]}
    >
      {children}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { borderWidth: StyleSheet.hairlineWidth },
  pressed: { opacity: 0.85 },
});
