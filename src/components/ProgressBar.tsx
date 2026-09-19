import { StyleSheet, View } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import type { ColorToken } from '../theme/colors';

interface ProgressBarProps {
  /** 0–1. Values above 1 are clamped; the color is the overflow signal. */
  progress: number;
  color?: ColorToken;
  trackColor?: ColorToken;
  height?: number;
  label?: string;
}

export function ProgressBar({
  progress,
  color = 'primary',
  trackColor = 'surfaceContainerHigh',
  height = 8,
  label,
}: ProgressBarProps) {
  const theme = useTheme();
  const clamped = Math.max(0, Math.min(1, Number.isFinite(progress) ? progress : 0));

  return (
    <View
      accessibilityRole="progressbar"
      accessibilityLabel={label}
      accessibilityValue={{ min: 0, max: 100, now: Math.round(clamped * 100) }}
      style={[
        styles.track,
        {
          backgroundColor: theme.colors[trackColor],
          height,
          borderRadius: height / 2,
        },
      ]}
    >
      <View
        style={{
          width: `${clamped * 100}%`,
          height,
          borderRadius: height / 2,
          backgroundColor: theme.colors[color],
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  track: { width: '100%', overflow: 'hidden' },
});
