import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '../../../components/AppText';
import { CategoryAvatar } from '../../../components/CategoryAvatar';
import type { Category } from '../../../domain/categories';
import { useTheme } from '../../../theme/ThemeProvider';

interface CategoryPickerProps {
  categories: Category[];
  selectedId: string;
  onSelect: (categoryId: string) => void;
}

/**
 * Category grid.
 *
 * A wrapping grid rather than a horizontal scroller: with ~13 categories the
 * whole set fits on screen, and picking one is the most common action in the
 * form — it should not require scrolling to discover.
 */
export function CategoryPicker({
  categories,
  selectedId,
  onSelect,
}: CategoryPickerProps) {
  const theme = useTheme();

  return (
    <View style={styles.grid}>
      {categories.map(category => {
        const selected = category.id === selectedId;
        return (
          <Pressable
            key={category.id}
            onPress={() => onSelect(category.id)}
            accessibilityRole="radio"
            accessibilityState={{ selected }}
            accessibilityLabel={category.name}
            style={[
              styles.item,
              {
                padding: theme.spacing.sm,
                borderRadius: theme.radius.md,
                borderColor: selected ? category.colorHex : 'transparent',
                backgroundColor: selected
                  ? `${category.colorHex}14`
                  : 'transparent',
              },
            ]}
          >
            <CategoryAvatar category={category} size={44} />
            <AppText
              variant="caption"
              align="center"
              color={selected ? 'textPrimary' : 'textSecondary'}
              numberOfLines={2}
              style={{ marginTop: theme.spacing.xs }}
            >
              {category.name}
            </AppText>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  grid: { flexDirection: 'row', flexWrap: 'wrap' },
  item: {
    width: '25%',
    alignItems: 'center',
    borderWidth: 1,
  },
});
