import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../domain/entities/expense_entity.dart';

/// Lets the user pick another budget for [expense] and checks that the
/// expense date falls inside that budget's period.
///
/// Only budgets in the expense's currency can be picked. Expenses carry no
/// currency of their own, so a move keeps the number and takes the target
/// budget's currency: ₹300 moved to a dollar budget would count as $300.
/// Budgets in another currency are listed, disabled, with the reason;
/// changing an expense's budget and amount together is done in the editor,
/// which asks first.
///
/// Returns the chosen budget, or null when cancelled or not allowed (the
/// reason is shown in a SnackBar). Shared by the details screen and the
/// long-press actions on the history list.
abstract final class MoveExpenseSheet {
  static Future<BudgetEntity?> show(
    BuildContext context, {
    required ExpenseEntity expense,
    List<BudgetEntity>? budgets,
  }) async {
    final all = budgets ?? await _loadBudgets();
    if (!context.mounted) return null;
    if (all == null) {
      _snack(context, "Couldn't load your budgets. Try again.");
      return null;
    }

    final candidates = all
        .where((b) => b.id != expense.budgetId && !b.isArchived)
        .toList();
    if (candidates.isEmpty) {
      _snack(context, 'There is no other budget to move to.');
      return null;
    }

    final currency = _currencyOf(all, expense.budgetId);
    bool sameCurrency(BudgetEntity b) =>
        currency == null || b.currency == currency;

    final selected = await AppBottomSheet.show<BudgetEntity>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHeader(
            title: 'Move to budget',
            subtitle:
                'The expense date must fall inside the budget period, and '
                'the budget must use the same currency.',
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final budget in candidates)
                  ListTile(
                    key: Key('moveTarget_${budget.id}'),
                    enabled: sameCurrency(budget),
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(budget.name),
                    subtitle: Text(
                      sameCurrency(budget)
                          ? '${formatDateRange(budget.startDate, budget.endDate)}'
                                ' · ${budget.currency}'
                          : 'Uses ${budget.currency}. Amounts aren\'t '
                                'converted, so this expense can\'t move here.',
                    ),
                    onTap: sameCurrency(budget)
                        ? () => Navigator.of(context).pop(budget)
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
    if (selected == null || !context.mounted) return null;

    if (!sameCurrency(selected)) {
      _snack(
        context,
        "${selected.name} uses ${selected.currency}, so this expense can't "
        'move there. Amounts are never converted.',
      );
      return null;
    }

    if (!selected.isActiveOn(expense.date)) {
      _snack(
        context,
        'This expense is dated '
        '${DateFormat('d MMM yyyy').format(expense.date)}, outside '
        "${selected.name}'s period "
        '(${formatDateRange(selected.startDate, selected.endDate)}).',
      );
      return null;
    }
    return selected;
  }

  /// The currency of the expense's budget, or null when it isn't listed.
  static String? _currencyOf(List<BudgetEntity> budgets, String budgetId) {
    for (final b in budgets) {
      if (b.id == budgetId) return b.currency;
    }
    return null;
  }

  /// Null when the budgets couldn't be read, so that is never mistaken
  /// for having no other budget.
  static Future<List<BudgetEntity>?> _loadBudgets() async {
    try {
      return await getIt<ManageBudgetUseCase>().getAll();
    } catch (e) {
      debugPrint('[error] Loading budgets to move an expense: $e');
      return null;
    }
  }

  static void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
