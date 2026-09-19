import { categoryColors } from '../theme/colors';

/**
 * Expense category. `icon` is a MaterialIcons glyph name, so the ids and icon
 * names stay identical to the Flutter build and to any exported data.
 */
export interface Category {
  id: string;
  name: string;
  icon: string;
  colorHex: string;
  isSystem: boolean;
}

/** Seeded into the database on first launch. */
export const defaultCategories: readonly Category[] = [
  { id: 'food', name: 'Food', icon: 'restaurant', colorHex: categoryColors.food, isSystem: true },
  { id: 'grocery', name: 'Grocery', icon: 'local-grocery-store', colorHex: categoryColors.grocery, isSystem: true },
  { id: 'fuel', name: 'Fuel', icon: 'local-gas-station', colorHex: categoryColors.fuel, isSystem: true },
  { id: 'shopping', name: 'Shopping', icon: 'shopping-cart', colorHex: categoryColors.shopping, isSystem: true },
  { id: 'rent', name: 'Rent', icon: 'home', colorHex: categoryColors.rent, isSystem: true },
  { id: 'emi', name: 'EMI', icon: 'payments', colorHex: categoryColors.emi, isSystem: true },
  { id: 'bills', name: 'Bills', icon: 'receipt-long', colorHex: categoryColors.bills, isSystem: true },
  { id: 'travel', name: 'Travel', icon: 'flight', colorHex: categoryColors.travel, isSystem: true },
  { id: 'entertainment', name: 'Entertainment', icon: 'movie', colorHex: categoryColors.entertainment, isSystem: true },
  { id: 'health', name: 'Health', icon: 'favorite', colorHex: categoryColors.health, isSystem: true },
  { id: 'education', name: 'Education', icon: 'school', colorHex: categoryColors.education, isSystem: true },
  { id: 'salary_adjustment', name: 'Salary Adjustment', icon: 'account-balance-wallet', colorHex: categoryColors.salary_adjustment, isSystem: true },
  { id: 'others', name: 'Others', icon: 'help-outline', colorHex: categoryColors.others, isSystem: true },
] as const;

const FALLBACK_CATEGORY: Category = {
  id: 'others',
  name: 'Others',
  icon: 'help-outline',
  colorHex: categoryColors.others,
  isSystem: true,
};

/**
 * Looks a category up by id from a list, falling back to "Others".
 *
 * Expenses reference categories by id, and a row can outlive a deleted custom
 * category — so lookup must never return undefined into the render path.
 */
export function categoryById(
  categories: readonly Category[],
  id: string | undefined | null,
): Category {
  return (
    categories.find(c => c.id === id) ??
    defaultCategories.find(c => c.id === id) ??
    FALLBACK_CATEGORY
  );
}
