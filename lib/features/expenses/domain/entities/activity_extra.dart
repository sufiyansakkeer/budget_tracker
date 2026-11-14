import 'package:equatable/equatable.dart';

/// Something in the Activity stream that isn't an expense: a payment to a
/// Pay later tab (money leaving, but not spending) or a budget starting or
/// ending.
sealed class ActivityExtra extends Equatable {
  /// When it happened; markers fall at the start of their day.
  DateTime get at;

  const ActivityExtra();
}

/// Money handed to a tab. Not spending: the purchases already counted.
final class TabPaymentExtra extends ActivityExtra {
  final String id;
  final String tabId;
  final String tabName;
  final double amount;
  final String currency;
  @override
  final DateTime at;

  const TabPaymentExtra({
    required this.id,
    required this.tabId,
    required this.tabName,
    required this.amount,
    required this.currency,
    required this.at,
  });

  @override
  List<Object?> get props => [id, tabId, tabName, amount, currency, at];
}

/// A budget's first day ([started]) or its last day once it has passed.
final class BudgetMarkerExtra extends ActivityExtra {
  final String budgetId;
  final String name;
  final double amount;
  final String currency;
  final bool started;

  /// Days in the period, both ends included.
  final int days;
  @override
  final DateTime at;

  const BudgetMarkerExtra({
    required this.budgetId,
    required this.name,
    required this.amount,
    required this.currency,
    required this.started,
    required this.days,
    required this.at,
  });

  @override
  List<Object?> get props => [
    budgetId,
    name,
    amount,
    currency,
    started,
    days,
    at,
  ];
}

/// What Activity adds to the expenses of the budgets on screen.
class ActivityExtras extends Equatable {
  /// The tab each tab purchase went on, by expense id.
  final Map<String, String> tabNameByExpense;
  final List<ActivityExtra> items;

  const ActivityExtras({
    this.tabNameByExpense = const {},
    this.items = const [],
  });

  static const empty = ActivityExtras();

  @override
  List<Object?> get props => [tabNameByExpense, items];
}
