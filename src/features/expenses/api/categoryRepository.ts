import { Q } from '@nozbe/watermelondb';
import { collections } from '../../../database';
import type CategoryModel from '../../../database/models/Category';
import type { Category } from '../../../domain/categories';

export function toCategory(model: CategoryModel): Category {
  return {
    id: model.id,
    name: model.name,
    icon: model.icon,
    colorHex: model.colorHex,
    isSystem: model.isSystem,
  };
}

export async function listCategories(): Promise<Category[]> {
  const models = await collections.categories
    .query(Q.sortBy('name', Q.asc))
    .fetch();
  return models.map(toCategory);
}
