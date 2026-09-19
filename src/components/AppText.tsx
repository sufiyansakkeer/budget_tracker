import { Text, type StyleProp, type TextProps, type TextStyle } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import type { ColorToken } from '../theme/colors';
import type { TypographyToken } from '../theme/typography';

interface AppTextProps extends TextProps {
  variant?: TypographyToken;
  color?: ColorToken;
  align?: TextStyle['textAlign'];
  style?: StyleProp<TextStyle>;
}

/**
 * Text bound to the type scale and color tokens.
 *
 * Screens should reach for this rather than `Text`, so every string in the app
 * picks up theme changes without touching a stylesheet.
 */
export function AppText({
  variant = 'body',
  color = 'textPrimary',
  align,
  style,
  ...rest
}: AppTextProps) {
  const theme = useTheme();

  return (
    <Text
      {...rest}
      style={[
        theme.typography[variant],
        { color: theme.colors[color], textAlign: align },
        style,
      ]}
    />
  );
}
