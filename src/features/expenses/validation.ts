import type { TFunction } from 'i18next';
import { z } from 'zod';
import { parseMoney } from '../../domain/currency';
import { endOfDay } from '../../domain/dates';

/** Guards against a mistyped amount becoming a budget-destroying number. */
const MAX_AMOUNT = 1_000_000_000;
const MAX_NOTE_LENGTH = 280;

/**
 * The form keeps `amount` as the raw text the user typed, so the field can
 * hold "12." mid-entry without the resolver rewriting it. The schema converts
 * it once, at submit time.
 */
export type ExpenseFormValues = {
  amount: string;
  categoryId: string;
  budgetId: string;
  note: string;
  date: Date;
  tags: string[];
};

/**
 * Built as a factory so validation messages come from the active locale —
 * a module-level schema would capture English at import time.
 */
export function expenseSchema(t: TFunction) {
  return z.object({
    amount: z
      .string()
      .refine(value => parseMoney(value) !== null, {
        message: t('expenses.validation.amountRequired'),
      })
      .refine(value => (parseMoney(value) ?? 0) > 0, {
        message: t('expenses.validation.amountPositive'),
      })
      .refine(value => (parseMoney(value) ?? 0) <= MAX_AMOUNT, {
        message: t('expenses.validation.amountTooLarge'),
      }),
    categoryId: z.string().min(1, {
      message: t('expenses.validation.categoryRequired'),
    }),
    budgetId: z.string().min(1, {
      message: t('expenses.validation.budgetRequired'),
    }),
    note: z.string().max(MAX_NOTE_LENGTH, {
      message: t('expenses.validation.noteTooLong'),
    }),
    // Compared against end-of-day so logging an expense later today is fine.
    date: z.date().refine(value => value <= endOfDay(new Date()), {
      message: t('expenses.validation.dateInFuture'),
    }),
    tags: z.array(z.string()),
  });
}
