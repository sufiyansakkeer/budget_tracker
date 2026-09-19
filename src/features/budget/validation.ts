import type { TFunction } from 'i18next';
import { z } from 'zod';
import { parseMoney } from '../../domain/currency';
import { calendarDaysBetween } from '../../domain/dates';

const MAX_AMOUNT = 1_000_000_000;
const MAX_NAME_LENGTH = 100;
/** Five years. Longer ranges make the daily-allowance maths meaningless. */
const MAX_PERIOD_DAYS = 365 * 5;

export type BudgetFormValues = {
  name: string;
  amount: string;
  currency: string;
  startDate: Date;
  endDate: Date;
  notes: string;
};

export function budgetSchema(t: TFunction) {
  return z
    .object({
      name: z
        .string()
        .trim()
        .min(1, { message: t('budgets.validation.nameRequired') })
        .max(MAX_NAME_LENGTH, { message: t('budgets.validation.nameTooLong') }),
      amount: z
        .string()
        .refine(value => parseMoney(value) !== null, {
          message: t('budgets.validation.amountRequired'),
        })
        .refine(value => (parseMoney(value) ?? 0) > 0, {
          message: t('budgets.validation.amountPositive'),
        })
        .refine(value => (parseMoney(value) ?? 0) <= MAX_AMOUNT, {
          message: t('expenses.validation.amountTooLarge'),
        }),
      currency: z.string().min(1),
      startDate: z.date(),
      endDate: z.date(),
      notes: z.string(),
    })
    // Cross-field rules go on the object, and the error is attached to the
    // field the user can act on — the end date.
    .refine(values => values.endDate >= values.startDate, {
      message: t('budgets.validation.endBeforeStart'),
      path: ['endDate'],
    })
    .refine(
      values =>
        calendarDaysBetween(values.startDate, values.endDate) <= MAX_PERIOD_DAYS,
      {
        message: t('budgets.validation.periodTooLong'),
        path: ['endDate'],
      },
    );
}
