/**
 * Plain, serialisable shapes for the domain.
 *
 * WatermelonDB models are live objects bound to the database; they must not be
 * put into React Query's cache or Redux. Repositories map every model to one
 * of these before it leaves the data layer.
 */

export interface Budget {
  id: string;
  name: string;
  /** Total for the whole period, not per month. */
  amount: number;
  currency: string;
  startDate: Date;
  endDate: Date;
  isArchived: boolean;
  color: string | null;
  icon: string | null;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface Expense {
  id: string;
  budgetId: string;
  categoryId: string;
  amount: number;
  note: string | null;
  date: Date;
  receiptPath: string | null;
  tags: string[];
  createdAt: Date;
  updatedAt: Date;
}

export interface BudgetInput {
  name: string;
  amount: number;
  currency: string;
  startDate: Date;
  endDate: Date;
  color?: string | null;
  icon?: string | null;
  notes?: string | null;
}

export interface ExpenseInput {
  budgetId: string;
  categoryId: string;
  amount: number;
  note?: string | null;
  date: Date;
  receiptPath?: string | null;
  tags?: string[];
}

/** One day's worth of expenses, used for the sectioned history list. */
export interface ExpenseGroup {
  /** Start of day, used as the section key. */
  date: Date;
  expenses: Expense[];
  total: number;
}

export type ExpenseSortOrder =
  | 'date_desc'
  | 'date_asc'
  | 'amount_desc'
  | 'amount_asc';

export interface ExpenseFilter {
  budgetId?: string;
  categoryIds?: string[];
  from?: Date;
  to?: Date;
  minAmount?: number;
  maxAmount?: number;
  /** Case-insensitive match against the note. */
  search?: string;
}
