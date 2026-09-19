import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { queryKeys } from '../../../app/config/queryKeys';
import type {
  ExpenseFilter,
  ExpenseInput,
  ExpenseSortOrder,
} from '../../../domain/types';
import { listCategories } from '../api/categoryRepository';
import {
  createExpense,
  deleteExpense,
  getExpense,
  listExpenses,
  updateExpense,
} from '../api/expenseRepository';

export function useExpenses(
  filter: ExpenseFilter = {},
  order: ExpenseSortOrder = 'date_desc',
) {
  return useQuery({
    queryKey: queryKeys.expenses.list(filter, order),
    queryFn: () => listExpenses(filter, order),
  });
}

export function useExpense(id: string | null | undefined) {
  return useQuery({
    queryKey: queryKeys.expenses.detail(id ?? ''),
    queryFn: () => getExpense(id as string),
    enabled: Boolean(id),
  });
}

export function useCategories() {
  return useQuery({
    queryKey: queryKeys.categories.all,
    queryFn: listCategories,
    // Categories only change when the user edits them, which invalidates here.
    staleTime: Infinity,
  });
}

/** An expense write moves the dashboard's numbers, so both branches refresh. */
function useInvalidateExpenses() {
  const queryClient = useQueryClient();
  return () => {
    queryClient.invalidateQueries({ queryKey: queryKeys.expenses.all });
    queryClient.invalidateQueries({ queryKey: queryKeys.dashboard.all });
  };
}

export function useCreateExpense() {
  const invalidate = useInvalidateExpenses();
  return useMutation({
    mutationFn: (input: ExpenseInput) => createExpense(input),
    onSuccess: invalidate,
  });
}

export function useUpdateExpense() {
  const invalidate = useInvalidateExpenses();
  return useMutation({
    mutationFn: ({
      id,
      input,
    }: {
      id: string;
      input: Partial<Omit<ExpenseInput, 'budgetId'>>;
    }) => updateExpense(id, input),
    onSuccess: invalidate,
  });
}

export function useDeleteExpense() {
  const invalidate = useInvalidateExpenses();
  return useMutation({
    mutationFn: (id: string) => deleteExpense(id),
    onSuccess: invalidate,
  });
}
