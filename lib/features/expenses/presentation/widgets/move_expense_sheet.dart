import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../../budget/presentation/widgets/budget_picker_sheet.dart';
import '../../domain/entities/expense_entity.dart';
import 'paid_bill.dart';

/// Lets the user pick another budget for [expense]: one in its currency
/// whose period includes its date.
///
/// Only budgets in the expense's currency can be picked. Expenses carry no
/// currency of their own, so a move keeps the number and takes the target
/// budget's currency: ₹300 moved to a dollar budget would count as $300.
/// Changing an expense's budget and amount together is done in the editor,
/// which asks first. Budgets that can't take the expense (another currency,
/// or a period that misses its date) are listed, disabled, with the reason.
///
/// [billTitle] is the bill the expense paid: the sheet says the move
/// unlinks it.
///
/// Returns the chosen budget, or null when cancelled or there is nowhere to
/// move (the reason is shown in a SnackBar). Shared by the details screen
/// and the long-press actions on the history list.
abstract final class MoveExpenseSheet {
  static Future<BudgetEntity?> show(
    BuildContext context, {
    required ExpenseEntity expense,
    List<BudgetEntity>? budgets,
    String? billTitle,
  }) async {
    final all = budgets ?? await loadBudgets();
    if (!context.mounted) return null;
    if (all == null) {
      _snack(context, "Couldn't load your budgets. Try again.");
      return null;
    }

    final candidates = _candidates(all, expense);
    if (candidates.isEmpty) {
      _snack(context, 'There is no other budget to move to.');
      return null;
    }

    final currency = _currencyOf(all, expense.budgetId);
    final dated = AppDates.dayWithYear(expense.date);
    String? whyNot(BudgetEntity b) {
      if (currency != null && b.currency != currency) {
        return "Uses ${b.currency}. Amounts aren't converted, so this "
            "expense can't move here.";
      }
      if (!b.isActiveOn(expense.date)) {
        return '${BudgetPickerSheet.describe(b, showCurrency: true)}\n'
            'This expense is dated $dated, outside this period.';
      }
      return null;
    }

    return BudgetPickerSheet.show<BudgetEntity>(
      context,
      title: 'Move to budget',
      subtitle: [
        'The expense date must fall inside the budget period, and '
            'the budget must use the same currency.',
        if (billTitle != null) PaidBill.moveHint(billTitle),
      ].join('\n\n'),
      budgets: candidates,
      rowKey: (b) => Key('moveTarget_${b.id}'),
      disabledReason: whyNot,
      describe: (b) => BudgetPickerSheet.describe(b, showCurrency: true),
      onPick: (b) => b,
    );
  }

  /// Whether [budgets] has anywhere [expense] could be moved, so Move is
  /// worth offering at all.
  static bool hasTarget(List<BudgetEntity> budgets, ExpenseEntity expense) =>
      _candidates(budgets, expense).isNotEmpty;

  static List<BudgetEntity> _candidates(
    List<BudgetEntity> budgets,
    ExpenseEntity expense,
  ) => budgets.where((b) => b.id != expense.budgetId && !b.isArchived).toList();

  /// The currency of the expense's budget, or null when it isn't listed.
  static String? _currencyOf(List<BudgetEntity> budgets, String budgetId) {
    for (final b in budgets) {
      if (b.id == budgetId) return b.currency;
    }
    return null;
  }

  /// Null when the budgets couldn't be read, so that is never mistaken
  /// for having no other budget.
  static Future<List<BudgetEntity>?> loadBudgets() async {
    try {
      return await getIt<ManageBudgetUseCase>().getAll();
    } catch (e) {
      debugPrint('[error] Loading budgets to move an expense: $e');
      return null;
    }
  }

  static void _snack(BuildContext context, String text) {
    AppSnack.show(context, text);
  }
}
