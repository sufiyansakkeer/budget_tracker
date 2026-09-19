import { defaultCategories } from '../domain/categories';
import { collections, database } from './index';

/**
 * Seeds the system categories on first launch.
 *
 * Categories are written with explicit ids matching `defaultCategories`, so an
 * expense's `category_id` stays stable across reinstalls and matches data
 * exported from the Flutter build.
 */
export async function seedCategories(): Promise<void> {
  const existing = await collections.categories.query().fetchCount();
  if (existing > 0) {
    return;
  }

  await database.write(async () => {
    await database.batch(
      ...defaultCategories.map(category =>
        collections.categories.prepareCreate(record => {
          record._raw.id = category.id;
          record.name = category.name;
          record.icon = category.icon;
          record.colorHex = category.colorHex;
          record.isSystem = category.isSystem;
        }),
      ),
    );
  });
}
