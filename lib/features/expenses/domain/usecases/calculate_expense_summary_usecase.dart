import '../entities/expense_entity.dart';
import '../entities/expense_history_summary.dart';

/// Computes summary statistics for a list of expenses.
class CalculateExpenseSummaryUseCase {
  const CalculateExpenseSummaryUseCase();

  ExpenseHistorySummary call(List<ExpenseEntity> expenses) {
    if (expenses.isEmpty) {
      return ExpenseHistorySummary.empty;
    }

    var total = 0.0;
    var highest = double.negativeInfinity;
    var lowest = double.infinity;

    for (final expense in expenses) {
      total += expense.amount;
      if (expense.amount > highest) highest = expense.amount;
      if (expense.amount < lowest) lowest = expense.amount;
    }

    return ExpenseHistorySummary(
      totalExpenses: expenses.length,
      totalAmount: total,
      averageExpense: total / expenses.length,
      highestExpense: highest,
      lowestExpense: lowest,
    );
  }
}
