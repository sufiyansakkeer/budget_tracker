import { Q } from '@nozbe/watermelondb';
import { collections, database } from '../../../database';
import type ExpenseModel from '../../../database/models/Expense';
import { endOfDay, startOfDay } from '../../../domain/dates';
import type {
  Expense,
  ExpenseFilter,
  ExpenseInput,
  ExpenseSortOrder,
} from '../../../domain/types';

export function toExpense(model: ExpenseModel): Expense {
  return {
    id: model.id,
    budgetId: model.budgetId,
    categoryId: model.categoryId,
    amount: model.amount,
    note: model.note,
    date: model.date,
    receiptPath: model.receiptPath,
    tags: model.tags,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  };
}

const sortClause = (order: ExpenseSortOrder) => {
  switch (order) {
    case 'date_asc':
      return Q.sortBy('date', Q.asc);
    case 'amount_desc':
      return Q.sortBy('amount', Q.desc);
    case 'amount_asc':
      return Q.sortBy('amount', Q.asc);
    case 'date_desc':
    default:
      return Q.sortBy('date', Q.desc);
  }
};

/**
 * Builds the WatermelonDB clauses for a filter.
 *
 * Note that `search` is deliberately absent: SQLite's LIKE is case-sensitive
 * for non-ASCII and WatermelonDB has no portable case-insensitive contains, so
 * note matching is done in JS by `listExpenses` after the indexed columns have
 * already narrowed the result set.
 */
function filterClauses(filter: ExpenseFilter) {
  const clauses = [];

  if (filter.budgetId) {
    clauses.push(Q.where('budget_id', filter.budgetId));
  }
  if (filter.categoryIds?.length) {
    clauses.push(Q.where('category_id', Q.oneOf(filter.categoryIds)));
  }
  if (filter.from) {
    clauses.push(Q.where('date', Q.gte(startOfDay(filter.from).getTime())));
  }
  if (filter.to) {
    clauses.push(Q.where('date', Q.lte(endOfDay(filter.to).getTime())));
  }
  if (filter.minAmount !== undefined) {
    clauses.push(Q.where('amount', Q.gte(filter.minAmount)));
  }
  if (filter.maxAmount !== undefined) {
    clauses.push(Q.where('amount', Q.lte(filter.maxAmount)));
  }

  return clauses;
}

export async function listExpenses(
  filter: ExpenseFilter = {},
  order: ExpenseSortOrder = 'date_desc',
): Promise<Expense[]> {
  const models = await collections.expenses
    .query(...filterClauses(filter), sortClause(order))
    .fetch();

  const expenses = models.map(toExpense);
  const term = filter.search?.trim().toLowerCase();
  if (!term) {
    return expenses;
  }

  return expenses.filter(
    expense =>
      expense.note?.toLowerCase().includes(term) ||
      expense.tags.some(tag => tag.toLowerCase().includes(term)),
  );
}

export async function getExpense(id: string): Promise<Expense | null> {
  try {
    return toExpense(await collections.expenses.find(id));
  } catch {
    return null;
  }
}

/** Total spent for a filter. Summed in JS — the row counts here are small. */
export async function sumExpenses(filter: ExpenseFilter): Promise<number> {
  const models = await collections.expenses
    .query(...filterClauses(filter))
    .fetch();
  return models.reduce((total, model) => total + model.amount, 0);
}

/** Spent today against a budget — the figure the dashboard leads with. */
export async function sumToday(
  budgetId: string,
  reference: Date = new Date(),
): Promise<number> {
  return sumExpenses({ budgetId, from: reference, to: reference });
}

export async function createExpense(input: ExpenseInput): Promise<Expense> {
  const created = await database.write(() =>
    collections.expenses.create(record => {
      record.budgetId = input.budgetId;
      record.categoryId = input.categoryId;
      record.amount = input.amount;
      record.note = input.note ?? null;
      record.date = input.date;
      record.receiptPath = input.receiptPath ?? null;
      record.tags = input.tags ?? [];
    }),
  );
  return toExpense(created);
}

export async function updateExpense(
  id: string,
  input: Partial<Omit<ExpenseInput, 'budgetId'>>,
): Promise<Expense> {
  const model = await collections.expenses.find(id);
  const updated = await database.write(() =>
    model.update(record => {
      if (input.categoryId !== undefined) record.categoryId = input.categoryId;
      if (input.amount !== undefined) record.amount = input.amount;
      if (input.note !== undefined) record.note = input.note;
      if (input.date !== undefined) record.date = input.date;
      if (input.receiptPath !== undefined)
        record.receiptPath = input.receiptPath;
      if (input.tags !== undefined) record.tags = input.tags;
    }),
  );
  return toExpense(updated);
}

export async function deleteExpense(id: string): Promise<void> {
  const model = await collections.expenses.find(id);
  await database.write(() => model.destroyPermanently());
}
