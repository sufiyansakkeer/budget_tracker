/**
 * react-native-vector-icons v10 ships Flow types, not TypeScript ones, and the
 * community `@types` package is deprecated. Declaring the one entry point the
 * app uses keeps the dependency list clean.
 */
declare module 'react-native-vector-icons/MaterialIcons' {
  import type { ComponentType } from 'react';
  import type { StyleProp, TextProps, TextStyle } from 'react-native';

  export interface MaterialIconProps extends TextProps {
    /** Glyph name, e.g. `restaurant` or `chevron-right`. */
    name: string;
    size?: number;
    color?: string;
    style?: StyleProp<TextStyle>;
  }

  const Icon: ComponentType<MaterialIconProps>;
  export default Icon;
}
