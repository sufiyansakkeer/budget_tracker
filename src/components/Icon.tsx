import MaterialIcon from 'react-native-vector-icons/MaterialIcons';
import type { StyleProp, TextStyle } from 'react-native';
import { useTheme } from '../theme/ThemeProvider';
import type { ColorToken } from '../theme/colors';

interface IconProps {
  name: string;
  size?: number;
  /** A theme token, or any literal color string. */
  color?: ColorToken | (string & {});
  style?: StyleProp<TextStyle>;
}

/**
 * MaterialIcons, with theme tokens accepted in place of raw colors.
 *
 * Centralising the icon family means switching sets later is one edit, and
 * callers never import from `react-native-vector-icons` directly.
 */
export function Icon({ name, size = 24, color = 'textPrimary', style }: IconProps) {
  const theme = useTheme();
  const resolved =
    color in theme.colors ? theme.colors[color as ColorToken] : (color as string);

  return <MaterialIcon name={name} size={size} color={resolved} style={style} />;
}
