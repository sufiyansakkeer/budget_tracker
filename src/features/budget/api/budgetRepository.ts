import { Q } from '@nozbe/watermelondb';
import { collections, database } from '../../../database';
import type BudgetModel from '../../../database/models/Budget';
import {
  summarizeBudget,
  type BudgetSummary,
} from '../../../domain/budget/calculations';
import type { Budget, BudgetInput } from '../../../domain/types';
import { sumExpenses } from '../../expenses/api/expenseRepository';

/** Maps a live WatermelonDB record to a plain object safe to cache. */
export function toBudget(model: BudgetModel): Budget {
  return {
    id: model.id,
    name: model.name,
    amount: model.amount,
    currency: model.currency,
    startDate: model.startDate,
    endDate: model.endDate,
    isArchived: model.isArchived,
    color: model.color,
    icon: model.icon,
    notes: model.notes,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  };
}

export async function listBudgets(
  includeArchived = false,
): Promise<Budget[]> {
  const clauses = includeArchived ? [] : [Q.where('is_archived', false)];
  const models = await collections.budgets
    .query(...clauses, Q.sortBy('start_date', Q.desc))
    .fetch();
  return models.map(toBudget);
}

export async function getBudget(id: string): Promise<Budget | null> {
  try {
    const model = await collections.budgets.find(id);
    return toBudget(model);
  } catch {
    // WatermelonDB throws rather than returning null for a missing id.
    return null;
  }
}

/**
 * The budget covering today, preferring the one that started most recently.
 *
 * Budgets may overlap (a trip budget inside a monthly one), so "current" is
 * resolved by start date rather than assuming a single active budget.
 */
export async function getCurrentBudget(
  reference: Date = new Date(),
): Promise<Budget | null> {
  const time = reference.getTime();
  const models = await collections.budgets
    .query(
      Q.where('is_archived', false),
      Q.where('start_date', Q.lte(time)),
      Q.where('end_date', Q.gte(time)),
      Q.sortBy('start_date', Q.desc),
      Q.take(1),
    )
    .fetch();
  return models.length > 0 ? toBudget(models[0]) : null;
}

export async function createBudget(input: BudgetInput): Promise<Budget> {
  const created = await database.write(() =>
    collections.budgets.create(record => {
      record.name = input.name;
      record.amount = input.amount;
      record.currency = input.currency;
      record.startDate = input.startDate;
      record.endDate = input.endDate;
      record.isArchived = false;
      record.color = input.color ?? null;
      record.icon = input.icon ?? null;
      record.notes = input.notes ?? null;
    }),
  );
  return toBudget(created);
}

export async function updateBudget(
  id: string,
  input: Partial<BudgetInput>,
): Promise<Budget> {
  const model = await collections.budgets.find(id);
  const updated = await database.write(() =>
    model.update(record => {
      if (input.name !== undefined) record.name = input.name;
      if (input.amount !== undefined) record.amount = input.amount;
      if (input.currency !== undefined) record.currency = input.currency;
      if (input.startDate !== undefined) record.startDate = input.startDate;
      if (input.endDate !== undefined) record.endDate = input.endDate;
      if (input.color !== undefined) record.color = input.color;
      if (input.icon !== undefined) record.icon = input.icon;
      if (input.notes !== undefined) record.notes = input.notes;
    }),
  );
  return toBudget(updated);
}

export async function setBudgetArchived(
  id: string,
  isArchived: boolean,
): Promise<void> {
  const model = await collections.budgets.find(id);
  await database.write(() =>
    model.update(record => {
      record.isArchived = isArchived;
    }),
  );
}

/**
 * Deletes a budget along with every expense recorded against it.
 *
 * Both happen in one write block, so a failure part-way cannot leave expenses
 * orphaned against a budget id that no longer exists.
 */
export async function deleteBudget(id: string): Promise<void> {
  const model = await collections.budgets.find(id);
  const expenses = await collections.expenses
    .query(Q.where('budget_id', id))
    .fetch();

  await database.write(async () => {
    await database.batch(
      ...expenses.map(expense => expense.prepareDestroyPermanently()),
      model.prepareDestroyPermanently(),
    );
  });
}

/** A budget paired with the metrics derived from its expenses. */
export interface BudgetWithSummary {
  budget: Budget;
  summary: BudgetSummary;
}

/**
 * Loads every budget with its computed metrics.
 *
 * The per-budget sums run concurrently: a user may have a handful of budgets,
 * and awaiting them in sequence would make the list screen visibly staggered.
 */
export async function listBudgetSummaries(
  includeArchived = false,
  reference: Date = new Date(),
): Promise<BudgetWithSummary[]> {
  const budgets = await listBudgets(includeArchived);

  return Promise.all(
    budgets.map(async budget => {
      const filter = {
        budgetId: budget.id,
        from: budget.startDate,
        to: budget.endDate,
      };
      const [totalSpent, todaySpent] = await Promise.all([
        sumExpenses(filter),
        sumExpenses({ budgetId: budget.id, from: reference, to: reference }),
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
          reference,
        ),
      };
    }),
  );
}
