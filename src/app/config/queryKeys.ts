import type { ExpenseFilter, ExpenseSortOrder } from '../../domain/types';

/**
 * Every React Query key in one place.
 *
 * Keys are hierarchical so a mutation can invalidate a whole branch —
 * `invalidateQueries({ queryKey: queryKeys.expenses.all })` catches every
 * filtered list without needing to know which filters are mounted.
 */
export const queryKeys = {
  budgets: {
    all: ['budgets'] as const,
    list: (includeArchived: boolean) =>
      ['budgets', 'list', includeArchived] as const,
    detail: (id: string) => ['budgets', 'detail', id] as const,
    current: ['budgets', 'current'] as const,
  },
  expenses: {
    all: ['expenses'] as const,
    list: (filter: ExpenseFilter, order: ExpenseSortOrder) =>
      ['expenses', 'list', filter, order] as const,
    detail: (id: string) => ['expenses', 'detail', id] as const,
  },
  categories: {
    all: ['categories'] as const,
  },
  dashboard: {
    all: ['dashboard'] as const,
    summary: (budgetId: string | null) =>
      ['dashboard', 'summary', budgetId] as const,
  },
} as const;
