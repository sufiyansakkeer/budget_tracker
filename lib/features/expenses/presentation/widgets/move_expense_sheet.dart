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

    final candidates = all
        .where((b) => b.id != expense.budgetId && !b.isArchived)
        .toList();
    if (candidates.isEmpty) {
      _snack(context, 'There is no other budget to move to.');
      return null;
    }

    final selected = await AppBottomSheet.show<BudgetEntity>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHeader(
            title: 'Move to budget',
            subtitle: 'The expense date must fall inside the budget period.',
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final budget in candidates)
                  ListTile(
                    key: Key('moveTarget_${budget.id}'),
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(budget.name),
                    subtitle: Text(
                      formatDateRange(budget.startDate, budget.endDate),
                    ),
                    onTap: () => Navigator.of(context).pop(budget),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
    if (selected == null || !context.mounted) return null;

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

  static Future<List<BudgetEntity>> _loadBudgets() async {
    try {
      return await getIt<ManageBudgetUseCase>().getAll();
    } catch (_) {
      return const [];
    }
  }

  static void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
