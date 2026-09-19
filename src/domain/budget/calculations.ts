/**
 * Every budget formula in the app, in one pure module.
 *
 * Ported verbatim from the Flutter `BudgetCalculationService` and its
 * `CALCULATION_RULES.md`. Screens and hooks must consume these functions
 * rather than re-deriving the math locally — that duplication is exactly what
 * the Flutter build set out to avoid.
 */

import { inclusiveDayCount, isWithinPeriod, startOfDay } from '../dates';

export type BudgetStatus = 'underBudget' | 'nearLimit' | 'overBudget';

export interface BudgetThresholds {
  /** Utilization ratio below which spending is comfortable. */
  nearLimit: number;
  /** Utilization ratio at or above which the budget is blown. */
  overBudget: number;
}

export const defaultThresholds: BudgetThresholds = {
  nearLimit: 0.8,
  overBudget: 1.0,
};

export interface BudgetPeriod {
  amount: number;
  startDate: Date;
  endDate: Date;
}

export interface BudgetSummary {
  /** Total budgeted for the period. */
  amount: number;
  totalSpent: number;
  /** Budget − spent. Negative when over budget. */
  remaining: number;
  /** Inclusive length of the whole period, in days. */
  totalDays: number;
  /** Days from start through the reference date, inclusive. Minimum 1. */
  daysPassed: number;
  /** Days from the reference date through the end, inclusive. Minimum 1. */
  daysRemaining: number;
  /** What can be spent per day for the rest of the period. */
  dailyAllowance: number;
  /** Spent today. */
  todaySpent: number;
  /** How far today's spending exceeded the allowance; 0 when within it. */
  todayOverspending: number;
  /** Spent ÷ budget, as a ratio. Can exceed 1. */
  utilization: number;
  /** Mean daily spend so far. */
  averageDaily: number;
  /** Period-end spend if the current average holds. */
  projectedSpending: number;
  /** Projected underspend. 0 when projected to overspend. */
  projectedSavings: number;
  /** Projected overspend. 0 when projected to stay within budget. */
  projectedOverspending: number;
  status: BudgetStatus;
}

/**
 * Days left including the reference day.
 *
 * Clamped to a minimum of 1: this is a divisor for the daily allowance, and
 * on the final day of a budget the honest answer (1) and the safe answer
 * coincide. Past the end date it stays 1 rather than going to 0.
 */
export function daysRemaining(endDate: Date, reference: Date): number {
  return Math.max(1, inclusiveDayCount(reference, endDate));
}

/** Days elapsed including the reference day. Clamped to a minimum of 1. */
export function daysPassed(startDate: Date, reference: Date): number {
  return Math.max(1, inclusiveDayCount(startDate, reference));
}

/** Budget − spent. Negative when over budget, which callers are expected to show. */
export function remainingBudget(amount: number, totalSpent: number): number {
  return amount - totalSpent;
}

/**
 * What is safe to spend per remaining day.
 *
 * The midnight rule: unspent allowance is never removed from the budget, so
 * recomputing this each day naturally rolls yesterday's leftovers forward.
 * Floors at 0 — an overspent budget allows nothing, not a negative amount.
 */
export function dailyAllowance(remaining: number, remainingDays: number): number {
  if (remainingDays <= 0) return 0;
  return Math.max(0, remaining / remainingDays);
}

/** How far today's spending overshot the allowance. Never negative. */
export function todayOverspending(todaySpent: number, allowance: number): number {
  return Math.max(0, todaySpent - allowance);
}

/** Spent ÷ budget. Returns 0 for a non-positive budget rather than Infinity. */
export function utilization(totalSpent: number, amount: number): number {
  if (amount <= 0) return 0;
  return totalSpent / amount;
}

/** Mean spend per elapsed day. */
export function averageDaily(totalSpent: number, elapsedDays: number): number {
  if (elapsedDays <= 0) return 0;
  return totalSpent / elapsedDays;
}

/** Period-end spend if the current daily average continues. */
export function projectedSpending(average: number, totalDays: number): number {
  return average * totalDays;
}

export function budgetStatus(
  utilizationRatio: number,
  thresholds: BudgetThresholds = defaultThresholds,
): BudgetStatus {
  if (utilizationRatio > thresholds.overBudget) return 'overBudget';
  if (utilizationRatio >= thresholds.nearLimit) return 'nearLimit';
  return 'underBudget';
}

/**
 * Computes every metric for a budget period in one pass.
 *
 * `reference` defaults to now and is normally today; it is injectable so the
 * math can be tested and so reports can ask "where did this stand on the 12th?".
 */
export function summarizeBudget(
  period: BudgetPeriod,
  totalSpent: number,
  todaySpent: number,
  reference: Date = new Date(),
  thresholds: BudgetThresholds = defaultThresholds,
): BudgetSummary {
  const ref = startOfDay(reference);
  const remaining = remainingBudget(period.amount, totalSpent);
  const totalDays = inclusiveDayCount(period.startDate, period.endDate);
  const passed = daysPassed(period.startDate, ref);
  const left = daysRemaining(period.endDate, ref);
  const allowance = dailyAllowance(remaining, left);
  const ratio = utilization(totalSpent, period.amount);
  const average = averageDaily(totalSpent, passed);
  const projected = projectedSpending(average, totalDays);

  return {
    amount: period.amount,
    totalSpent,
    remaining,
    totalDays,
    daysPassed: Math.min(passed, totalDays),
    daysRemaining: left,
    dailyAllowance: allowance,
    todaySpent,
    todayOverspending: todayOverspending(todaySpent, allowance),
    utilization: ratio,
    averageDaily: average,
    projectedSpending: projected,
    projectedSavings: Math.max(0, period.amount - projected),
    projectedOverspending: Math.max(0, projected - period.amount),
    status: budgetStatus(ratio, thresholds),
  };
}

/** Whether a budget period covers the given day. */
export function isPeriodActive(period: BudgetPeriod, reference: Date = new Date()): boolean {
  return isWithinPeriod(reference, period.startDate, period.endDate);
}
