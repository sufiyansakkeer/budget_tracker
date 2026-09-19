/**
 * The worked examples in `CALCULATION_RULES.md` (carried over from the Flutter
 * build) are the spec for this module — each one is encoded as a test below.
 */
import {
  budgetStatus,
  dailyAllowance,
  daysPassed,
  daysRemaining,
  summarizeBudget,
  todayOverspending,
  utilization,
} from './calculations';

const aug = (day: number, hour = 0) => new Date(2025, 7, day, hour);

describe('daysRemaining', () => {
  it('counts today as remaining', () => {
    expect(daysRemaining(aug(25), aug(15))).toBe(11);
  });

  it('returns 1 on the final day', () => {
    expect(daysRemaining(aug(25), aug(25))).toBe(1);
  });

  it('clamps to 1 past the end date so it is safe to divide by', () => {
    expect(daysRemaining(aug(25), aug(30))).toBe(1);
  });

  it('ignores clock time and compares calendar days', () => {
    expect(daysRemaining(aug(25, 1), aug(15, 23))).toBe(11);
  });
});

describe('daysPassed', () => {
  it('includes the start day and today', () => {
    expect(daysPassed(aug(10), aug(15))).toBe(6);
  });

  it('is 1 on day one, so averages never divide by zero', () => {
    expect(daysPassed(aug(10), aug(10))).toBe(1);
  });
});

describe('dailyAllowance', () => {
  it('spreads the remaining budget over the remaining days', () => {
    expect(dailyAllowance(30000, 22)).toBeCloseTo(1363.64, 2);
  });

  it('shrinks after spending', () => {
    expect(dailyAllowance(29200, 22)).toBeCloseTo(1327.27, 2);
  });

  it('floors at zero when the budget is blown', () => {
    expect(dailyAllowance(-500, 10)).toBe(0);
  });
});

describe('todayOverspending', () => {
  it('reports the overshoot', () => {
    expect(todayOverspending(2000, 1428)).toBe(572);
  });

  it('is zero when within the allowance', () => {
    expect(todayOverspending(900, 1428)).toBe(0);
  });
});

describe('utilization', () => {
  it('is spent over budget', () => {
    expect(utilization(7500, 30000)).toBe(0.25);
  });

  it('avoids dividing by a zero budget', () => {
    expect(utilization(100, 0)).toBe(0);
  });
});

describe('budgetStatus', () => {
  it.each([
    [0.5, 'underBudget'],
    [0.79, 'underBudget'],
    [0.8, 'nearLimit'],
    [1.0, 'nearLimit'],
    [1.01, 'overBudget'],
  ])('maps utilization %p to %s', (ratio, expected) => {
    expect(budgetStatus(ratio)).toBe(expected);
  });
});

describe('summarizeBudget', () => {
  const period = { amount: 30000, startDate: aug(1), endDate: aug(30) };

  it('projects period-end spending from the running average', () => {
    // Spent 9000 over 10 days = 900/day; 900 × 30 days = 27000.
    const summary = summarizeBudget(period, 9000, 0, aug(10));

    expect(summary.totalDays).toBe(30);
    expect(summary.daysPassed).toBe(10);
    expect(summary.averageDaily).toBe(900);
    expect(summary.projectedSpending).toBe(27000);
    expect(summary.projectedSavings).toBe(3000);
    expect(summary.projectedOverspending).toBe(0);
  });

  it('reports projected overspending when the pace is too high', () => {
    const summary = summarizeBudget(period, 15000, 0, aug(10));

    expect(summary.projectedSpending).toBe(45000);
    expect(summary.projectedOverspending).toBe(15000);
    expect(summary.projectedSavings).toBe(0);
  });

  it('carries unspent allowance forward instead of expiring it', () => {
    // Nothing spent in the first 9 days: the allowance for the remaining 21
    // days is higher than the day-one allowance of 30000/30 = 1000.
    const untouched = summarizeBudget(period, 0, 0, aug(10));

    expect(untouched.daysRemaining).toBe(21);
    expect(untouched.dailyAllowance).toBeCloseTo(30000 / 21, 2);
    expect(untouched.dailyAllowance).toBeGreaterThan(1000);
  });

  it('goes negative on remaining, not on status, when over budget', () => {
    const blown = summarizeBudget(period, 33000, 0, aug(20));

    expect(blown.remaining).toBe(-3000);
    expect(blown.status).toBe('overBudget');
    expect(blown.dailyAllowance).toBe(0);
  });

  it('flags today as overspent against the current allowance', () => {
    const summary = summarizeBudget(period, 10000, 3000, aug(15));

    // Remaining 20000 over 16 days = 1250/day; spent 3000 today.
    expect(summary.dailyAllowance).toBeCloseTo(1250, 2);
    expect(summary.todayOverspending).toBeCloseTo(1750, 2);
  });
});
