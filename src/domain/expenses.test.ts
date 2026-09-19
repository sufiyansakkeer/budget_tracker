import { groupByDay, totalsByCategory } from './expenses';
import type { Expense } from './types';

const makeExpense = (
  id: string,
  amount: number,
  date: Date,
  categoryId = 'food',
): Expense => ({
  id,
  budgetId: 'budget-1',
  categoryId,
  amount,
  note: null,
  date,
  receiptPath: null,
  tags: [],
  createdAt: date,
  updatedAt: date,
});

describe('groupByDay', () => {
  it('groups expenses that share a calendar day regardless of time', () => {
    const groups = groupByDay([
      makeExpense('a', 100, new Date(2025, 7, 15, 9)),
      makeExpense('b', 250, new Date(2025, 7, 15, 21)),
      makeExpense('c', 75, new Date(2025, 7, 14, 12)),
    ]);

    expect(groups).toHaveLength(2);
    expect(groups[0].expenses.map(e => e.id)).toEqual(['a', 'b']);
    expect(groups[0].total).toBe(350);
    expect(groups[1].total).toBe(75);
  });

  it('preserves the incoming order rather than re-sorting', () => {
    // An amount-sorted list must stay amount-sorted inside each day.
    const groups = groupByDay([
      makeExpense('big', 900, new Date(2025, 7, 15, 9)),
      makeExpense('small', 10, new Date(2025, 7, 15, 21)),
    ]);

    expect(groups[0].expenses.map(e => e.id)).toEqual(['big', 'small']);
  });

  it('returns nothing for an empty list', () => {
    expect(groupByDay([])).toEqual([]);
  });
});

describe('totalsByCategory', () => {
  it('sums and counts per category, largest first', () => {
    const totals = totalsByCategory([
      makeExpense('a', 100, new Date(), 'food'),
      makeExpense('b', 50, new Date(), 'fuel'),
      makeExpense('c', 300, new Date(), 'rent'),
      makeExpense('d', 20, new Date(), 'food'),
    ]);

    expect(totals).toEqual([
      { categoryId: 'rent', total: 300, count: 1 },
      { categoryId: 'food', total: 120, count: 2 },
      { categoryId: 'fuel', total: 50, count: 1 },
    ]);
  });
});
