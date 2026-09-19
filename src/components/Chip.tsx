import { Pressable, StyleSheet } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import type { ColorToken } from '../theme/colors';
import { AppText } from './AppText';
import { Icon } from './Icon';

interface ChipProps {
  label: string;
  selected?: boolean;
  onPress?: () => void;
  icon?: string;
  /** Tints the chip when selected. Defaults to the primary color. */
  tint?: ColorToken;
  /** A literal color, used for category chips that carry their own hex. */
  tintColor?: string;
}

export function Chip({
  label,
  selected = false,
  onPress,
  icon,
  tint = 'primary',
  tintColor,
}: ChipProps) {
  const theme = useTheme();
  const accent = tintColor ?? theme.colors[tint];

  return (
    <Pressable
      onPress={onPress}
      disabled={!onPress}
      accessibilityRole={onPress ? 'button' : undefined}
      accessibilityState={{ selected }}
      style={({ pressed }) => [
        styles.chip,
        {
          backgroundColor: selected ? accent : theme.colors.surfaceContainer,
          borderColor: selected ? accent : theme.colors.divider,
          borderRadius: theme.radius.full,
          paddingHorizontal: theme.spacing.smd,
          paddingVertical: theme.spacing.sm,
        },
        pressed && styles.pressed,
      ]}
    >
      {icon ? (
        <Icon
          name={icon}
          size={16}
          color={selected ? theme.colors.onPrimary : theme.colors.textSecondary}
          style={styles.icon}
        />
      ) : null}
      <AppText
        variant="label"
        style={{
          color: selected ? theme.colors.onPrimary : theme.colors.textSecondary,
        }}
      >
        {label}
      </AppText>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: StyleSheet.hairlineWidth,
  },
  icon: { marginRight: 6 },
  pressed: { opacity: 0.8 },
});
