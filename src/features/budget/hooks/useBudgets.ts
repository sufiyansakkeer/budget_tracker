import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { queryKeys } from '../../../app/config/queryKeys';
import type { BudgetInput } from '../../../domain/types';
import {
  createBudget,
  deleteBudget,
  getBudget,
  getCurrentBudget,
  listBudgetSummaries,
  listBudgets,
  setBudgetArchived,
  updateBudget,
} from '../api/budgetRepository';

export function useBudgets(includeArchived = false) {
  return useQuery({
    queryKey: queryKeys.budgets.list(includeArchived),
    queryFn: () => listBudgets(includeArchived),
  });
}

export function useBudget(id: string | null | undefined) {
  return useQuery({
    queryKey: queryKeys.budgets.detail(id ?? ''),
    queryFn: () => getBudget(id as string),
    enabled: Boolean(id),
  });
}

export function useCurrentBudget() {
  return useQuery({
    queryKey: queryKeys.budgets.current,
    queryFn: () => getCurrentBudget(),
  });
}

/**
 * Invalidates everything a budget change can affect.
 *
 * Dashboard figures and expense lists are both derived from budgets, so a
 * budget write has to reach past its own branch of the cache.
 */
function useInvalidateBudgets() {
  const queryClient = useQueryClient();
  return () => {
    queryClient.invalidateQueries({ queryKey: queryKeys.budgets.all });
    queryClient.invalidateQueries({ queryKey: queryKeys.dashboard.all });
    queryClient.invalidateQueries({ queryKey: queryKeys.expenses.all });
  };
}

export function useCreateBudget() {
  const invalidate = useInvalidateBudgets();
  return useMutation({
    mutationFn: (input: BudgetInput) => createBudget(input),
    onSuccess: invalidate,
  });
}

export function useUpdateBudget() {
  const invalidate = useInvalidateBudgets();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: Partial<BudgetInput> }) =>
      updateBudget(id, input),
    onSuccess: invalidate,
  });
}

export function useArchiveBudget() {
  const invalidate = useInvalidateBudgets();
  return useMutation({
    mutationFn: ({ id, isArchived }: { id: string; isArchived: boolean }) =>
      setBudgetArchived(id, isArchived),
    onSuccess: invalidate,
  });
}

export function useDeleteBudget() {
  const invalidate = useInvalidateBudgets();
  return useMutation({
    mutationFn: (id: string) => deleteBudget(id),
    onSuccess: invalidate,
  });
}

/** Budgets with their spend metrics, for the budget list screen. */
export function useBudgetSummaries(includeArchived = false) {
  return useQuery({
    queryKey: [...queryKeys.budgets.list(includeArchived), 'summaries'],
    queryFn: () => listBudgetSummaries(includeArchived),
  });
}
