import 'package:equatable/equatable.dart';

/// Expense category model. Supports system and custom categories.
class ExpenseCategory extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final bool isSystem;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    this.isSystem = true,
  });

  @override
  List<Object?> get props => [id, name, icon, colorHex, isSystem];
}

/// Default system categories seeded into the database.
const List<ExpenseCategory> defaultCategories = [
  ExpenseCategory(
    id: 'food',
    name: 'Food',
    icon: 'restaurant',
    colorHex: '#FF6B6B',
  ),
  ExpenseCategory(
    id: 'grocery',
    name: 'Grocery',
    icon: 'local_grocery_store',
    colorHex: '#10AC84',
  ),
  ExpenseCategory(
    id: 'fuel',
    name: 'Fuel',
    icon: 'local_gas_station',
    colorHex: '#FF9F43',
  ),
  ExpenseCategory(
    id: 'shopping',
    name: 'Shopping',
    icon: 'shopping_cart',
    colorHex: '#FECA57',
  ),
  ExpenseCategory(id: 'rent', name: 'Rent', icon: 'home', colorHex: '#48DBFB'),
  ExpenseCategory(
    id: 'emi',
    name: 'EMI',
    icon: 'payments',
    colorHex: '#1DD1A1',
  ),
  ExpenseCategory(
    id: 'bills',
    name: 'Bills',
    icon: 'receipt_long',
    colorHex: '#EE5253',
  ),
  ExpenseCategory(
    id: 'travel',
    name: 'Travel',
    icon: 'flight',
    colorHex: '#54A0FF',
  ),
  ExpenseCategory(
    id: 'entertainment',
    name: 'Entertainment',
    icon: 'movie',
    colorHex: '#5F27CD',
  ),
  ExpenseCategory(
    id: 'health',
    name: 'Health',
    icon: 'favorite',
    colorHex: '#FF9FF3',
  ),
  ExpenseCategory(
    id: 'education',
    name: 'Education',
    icon: 'school',
    colorHex: '#00D2D3',
  ),
  ExpenseCategory(
    id: 'salary_adjustment',
    name: 'Salary Adjustment',
    icon: 'account_balance_wallet',
    colorHex: '#8395A7',
  ),
  ExpenseCategory(
    id: 'others',
    name: 'Others',
    icon: 'help_outline',
    colorHex: '#8395A7',
  ),
];
