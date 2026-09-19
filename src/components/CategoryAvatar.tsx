import { View } from 'react-native';
import type { Category } from '../domain/categories';
import { Icon } from './Icon';

interface CategoryAvatarProps {
  category: Category;
  size?: number;
}

/**
 * Category glyph on a tinted circle.
 *
 * The tint is the category's own hex at low opacity, which keeps the badge
 * readable in both themes without needing a per-category dark variant.
 */
export function CategoryAvatar({ category, size = 40 }: CategoryAvatarProps) {
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: `${category.colorHex}22`,
      }}
    >
      <Icon name={category.icon} size={size * 0.5} color={category.colorHex} />
    </View>
  );
}
