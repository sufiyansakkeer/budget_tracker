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

/// Colour drawn for an expense whose category no longer exists: the Others
/// category's colour, so a missing category looks like the catch-all.
const String fallbackCategoryColorHex = '#8A8A8A';

/// Colours are compared as the app draws them (darkened or lightened to 4.5:1
/// on each palette's surface), where no two may be closer than CIEDE2000 15:
/// see `default_category_colours_test.dart`. v10 changed six of them; see
/// [v9DefaultCategoryColours].
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
    colorHex: '#F1C40F',
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
    colorHex: '#8BC34A',
  ),
  DefaultCategoryRow(
    id: 'bills',
    name: 'Bills',
    icon: 'receipt_long',
    colorHex: '#883311',
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
    colorHex: '#6F1E51',
  ),
  DefaultCategoryRow(
    id: 'salary_adjustment',
    name: 'Salary Adjustment',
    icon: 'account_balance_wallet',
    colorHex: '#C9A0A0',
  ),
  DefaultCategoryRow(
    id: fallbackCategoryId,
    name: 'Others',
    icon: 'help_outline',
    colorHex: fallbackCategoryColorHex,
  ),
];

/// The built-in colours schema v9 and earlier shipped, by category id, for
/// the defaults whose colour changed in v10 (UX-088: Food/Bills,
/// Grocery/EMI and Salary Adjustment/Others were drawn in near-identical
/// colours). The v10 migration recolours a built-in category only while its
/// stored colour still equals the value here, so a colour the user chose is
/// never touched.
const Map<String, String> v9DefaultCategoryColours = {
  'shopping': '#FECA57',
  'emi': '#1DD1A1',
  'bills': '#EE5253',
  'education': '#00D2D3',
  'salary_adjustment': '#8395A7',
  fallbackCategoryId: '#8395A7',
};
