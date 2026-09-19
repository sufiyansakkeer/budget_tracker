import { useQuery } from '@tanstack/react-query';
import { queryKeys } from '../../../app/config/queryKeys';
import { summarizeBudget, type BudgetSummary } from '../../../domain/budget/calculations';
import type { Budget, Expense } from '../../../domain/types';
import { getBudget, getCurrentBudget } from '../../budget/api/budgetRepository';
import {
  listExpenses,
  sumExpenses,
  sumToday,
} from '../../expenses/api/expenseRepository';

export interface DashboardData {
  budget: Budget | null;
  summary: BudgetSummary | null;
  recentExpenses: Expense[];
}

const RECENT_EXPENSE_COUNT = 5;

/**
 * Loads everything the dashboard renders in one query.
 *
 * Keeping budget, totals and recent expenses in a single query means the
 * screen never shows a half-updated state where the remaining figure has
 * refreshed but the list below it has not.
 */
export function useDashboardSummary(activeBudgetId: string | null) {
  return useQuery({
    queryKey: queryKeys.dashboard.summary(activeBudgetId),
    queryFn: async (): Promise<DashboardData> => {
      const budget = activeBudgetId
        ? ((await getBudget(activeBudgetId)) ?? (await getCurrentBudget()))
        : await getCurrentBudget();

      if (!budget) {
        return { budget: null, summary: null, recentExpenses: [] };
      }

      const filter = {
        budgetId: budget.id,
        from: budget.startDate,
        to: budget.endDate,
      };

      const [totalSpent, todaySpent, allExpenses] = await Promise.all([
        sumExpenses(filter),
        sumToday(budget.id),
        listExpenses(filter, 'date_desc'),
      ]);

      return {
        budget,
        summary: summarizeBudget(
          {
            amount: budget.amount,
            startDate: budget.startDate,
            endDate: budget.endDate,
          },
          totalSpent,
          todaySpent,
        ),
        recentExpenses: allExpenses.slice(0, RECENT_EXPENSE_COUNT),
      };
    },
  });
}
