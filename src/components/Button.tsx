import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import { AppText } from './AppText';
import { Icon } from './Icon';

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';

interface ButtonProps {
  label: string;
  onPress: () => void;
  variant?: ButtonVariant;
  icon?: string;
  disabled?: boolean;
  loading?: boolean;
  fullWidth?: boolean;
  style?: StyleProp<ViewStyle>;
}

export function Button({
  label,
  onPress,
  variant = 'primary',
  icon,
  disabled = false,
  loading = false,
  fullWidth = true,
  style,
}: ButtonProps) {
  const theme = useTheme();
  const isDisabled = disabled || loading;

  const background = {
    primary: theme.colors.primary,
    secondary: theme.colors.surfaceContainer,
    ghost: 'transparent',
    danger: theme.colors.error,
  }[variant];

  const foreground = {
    primary: theme.colors.onPrimary,
    secondary: theme.colors.textPrimary,
    ghost: theme.colors.primary,
    danger: theme.colors.onPrimary,
  }[variant];

  return (
    <Pressable
      onPress={onPress}
      disabled={isDisabled}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: isDisabled, busy: loading }}
      style={({ pressed }) => [
        styles.button,
        {
          backgroundColor: background,
          borderRadius: theme.radius.md,
          paddingVertical: theme.spacing.smd,
          paddingHorizontal: theme.spacing.lg,
          borderColor: variant === 'ghost' ? theme.colors.outline : 'transparent',
          alignSelf: fullWidth ? 'stretch' : 'flex-start',
        },
        pressed && styles.pressed,
        isDisabled && styles.disabled,
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={foreground} />
      ) : (
        <View style={styles.content}>
          {icon ? (
            <Icon name={icon} size={18} color={foreground} style={styles.icon} />
          ) : null}
          <AppText variant="subtitle" style={{ color: foreground }}>
            {label}
          </AppText>
        </View>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    minHeight: 48,
  },
  content: { flexDirection: 'row', alignItems: 'center' },
  icon: { marginRight: 8 },
  pressed: { opacity: 0.85 },
  disabled: { opacity: 0.45 },
});
