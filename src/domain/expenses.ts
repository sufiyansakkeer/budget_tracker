/**
 * Pure list transforms over expenses.
 *
 * These live in the domain rather than the repository so they can be tested
 * and reused without pulling in the database and its native modules.
 */
import { startOfDay } from './dates';
import type { Expense, ExpenseGroup } from './types';

/**
 * Groups expenses into day sections for the history list.
 *
 * Assumes the input is already sorted by date descending — it preserves the
 * incoming order rather than re-sorting, so an amount-sorted list stays sorted
 * by amount within each day.
 */
export function groupByDay(expenses: Expense[]): ExpenseGroup[] {
  const groups = new Map<number, ExpenseGroup>();

  for (const expense of expenses) {
    const key = startOfDay(expense.date).getTime();
    const group = groups.get(key);
    if (group) {
      group.expenses.push(expense);
      group.total += expense.amount;
    } else {
      groups.set(key, {
        date: new Date(key),
        expenses: [expense],
        total: expense.amount,
      });
    }
  }

  return [...groups.values()];
}

/** Totals per category, largest first — the input for the reports breakdown. */
export function totalsByCategory(
  expenses: Expense[],
): { categoryId: string; total: number; count: number }[] {
  const totals = new Map<string, { total: number; count: number }>();

  for (const expense of expenses) {
    const current = totals.get(expense.categoryId) ?? { total: 0, count: 0 };
    current.total += expense.amount;
    current.count += 1;
    totals.set(expense.categoryId, current);
  }

  return [...totals.entries()]
    .map(([categoryId, value]) => ({ categoryId, ...value }))
    .sort((a, b) => b.total - a.total);
}
