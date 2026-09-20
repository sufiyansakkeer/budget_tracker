/// The categories every installation starts with.
///
/// This is the single source of truth: the database seeds these rows on
/// first open (so foreign keys from expenses are always satisfiable) and the
/// expenses feature maps them to its `ExpenseCategory` entity.
class DefaultCategoryRow {
  final String id;
  final String name;
  final String icon;
  final String colorHex;

  const DefaultCategoryRow({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
  });
}

/// Id of the catch-all category unknown references are repaired to.
const String fallbackCategoryId = 'others';

const List<DefaultCategoryRow> defaultCategoryRows = [
  DefaultCategoryRow(
    id: 'food',
    name: 'Food',
    icon: 'restaurant',
    colorHex: '#FF6B6B',
  ),
  DefaultCategoryRow(
    id: 'grocery',
    name: 'Grocery',
    icon: 'local_grocery_store',
    colorHex: '#10AC84',
  ),
  DefaultCategoryRow(
    id: 'fuel',
    name: 'Fuel',
    icon: 'local_gas_station',
    colorHex: '#FF9F43',
  ),
  DefaultCategoryRow(
    id: 'shopping',
    name: 'Shopping',
    icon: 'shopping_cart',
    colorHex: '#FECA57',
  ),
  DefaultCategoryRow(
    id: 'rent',
    name: 'Rent',
    icon: 'home',
    colorHex: '#48DBFB',
  ),
  DefaultCategoryRow(
    id: 'emi',
    name: 'EMI',
    icon: 'payments',
    colorHex: '#1DD1A1',
  ),
  DefaultCategoryRow(
    id: 'bills',
    name: 'Bills',
    icon: 'receipt_long',
    colorHex: '#EE5253',
  ),
  DefaultCategoryRow(
    id: 'travel',
    name: 'Travel',
    icon: 'flight',
    colorHex: '#54A0FF',
  ),
  DefaultCategoryRow(
    id: 'entertainment',
    name: 'Entertainment',
    icon: 'movie',
    colorHex: '#5F27CD',
  ),
  DefaultCategoryRow(
    id: 'health',
    name: 'Health',
    icon: 'favorite',
    colorHex: '#FF9FF3',
  ),
  DefaultCategoryRow(
    id: 'education',
    name: 'Education',
    icon: 'school',
    colorHex: '#00D2D3',
  ),
  DefaultCategoryRow(
    id: 'salary_adjustment',
    name: 'Salary Adjustment',
    icon: 'account_balance_wallet',
    colorHex: '#8395A7',
  ),
  DefaultCategoryRow(
    id: fallbackCategoryId,
    name: 'Others',
    icon: 'help_outline',
    colorHex: '#8395A7',
  ),
];
