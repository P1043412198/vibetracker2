import { describe, it, expect } from 'vitest';
import {
  monthKeyOf, previousMonthKey,
  computeMonthFacts, daysLeftInMonth, effectiveLimit,
  computeFreeFunds, dailyAllowance, subscriptionsBudget,
} from '../monthlyBudget';
import type { Account, Transaction, MonthlyBudgetPlan, RegularPayment } from '../../types';

const noop = (n: number) => n;
const accounts: Account[] = [
  { id: 'a1', name: 'Cash', type: 'cash', currency: 'BYN', initialBalance: 0, color: '#000', createdAt: '' },
];

const tx = (
  id: string, type: 'income' | 'expense', amount: number, date: string, category = 'Other',
): Transaction => ({ id, type, amount, category, date, accountId: 'a1' });

describe('monthKeyOf / previousMonthKey', () => {
  it('formats YYYY-MM', () => {
    expect(monthKeyOf(new Date(2026, 0, 15))).toBe('2026-01');
    expect(monthKeyOf(new Date(2026, 11, 1))).toBe('2026-12');
  });

  it('handles year boundary', () => {
    expect(previousMonthKey('2026-01')).toBe('2025-12');
    expect(previousMonthKey('2026-12')).toBe('2026-11');
  });
});

describe('computeMonthFacts', () => {
  const transactions: Transaction[] = [
    tx('1', 'income', 1000, '2026-05-01', 'Salary'),
    tx('2', 'expense', 200, '2026-05-05', 'Food'),
    tx('3', 'expense', 100, '2026-05-15', 'Food'),
    tx('4', 'expense', 50, '2026-05-20', 'Transport'),
    tx('5', 'expense', 999, '2026-04-30', 'Food'),     // out of range
    tx('6', 'expense', 999, '2026-06-01', 'Food'),     // out of range
    tx('7', 'income', 500, '2026-05-25', 'Bonus'),
  ];

  it('aggregates income, expense and category breakdown for the month', () => {
    const f = computeMonthFacts({
      month: new Date(2026, 4, 1),
      transactions, accounts, baseCurrency: 'BYN', convert: noop,
    });
    expect(f.income).toBe(1500);
    expect(f.expense).toBe(350);
    expect(f.expenseByCategory).toEqual({ Food: 300, Transport: 50 });
    expect(f.monthTx).toHaveLength(5);
  });

  it('returns zeros for a month with no transactions', () => {
    const f = computeMonthFacts({
      month: new Date(2030, 0, 1),
      transactions, accounts, baseCurrency: 'BYN', convert: noop,
    });
    expect(f.income).toBe(0);
    expect(f.expense).toBe(0);
    expect(f.expenseByCategory).toEqual({});
  });

  it('skips malformed dates safely', () => {
    const broken: Transaction[] = [
      ...transactions,
      tx('bad', 'expense', 9999, 'not-a-date', 'Food'),
    ];
    const f = computeMonthFacts({
      month: new Date(2026, 4, 1),
      transactions: broken, accounts, baseCurrency: 'BYN', convert: noop,
    });
    expect(f.expense).toBe(350);
  });
});

describe('daysLeftInMonth', () => {
  it('returns days remaining for current month', () => {
    const today = new Date(2026, 4, 10);
    expect(daysLeftInMonth(new Date(2026, 4, 1), today)).toBe(22); // 31 - 10 + 1
  });
  it('returns 1 for past months', () => {
    const today = new Date(2026, 4, 10);
    expect(daysLeftInMonth(new Date(2026, 3, 1), today)).toBe(1);
  });
  it('returns full days for future months', () => {
    const today = new Date(2026, 4, 10);
    expect(daysLeftInMonth(new Date(2026, 5, 1), today)).toBe(30); // June
  });
});

describe('computeFreeFunds', () => {
  it('uses planned income when provided', () => {
    expect(computeFreeFunds(1000, 800, 600)).toEqual({ incomeRef: 1000, free: 400 });
  });
  it('falls back to actual income when plan is zero', () => {
    expect(computeFreeFunds(0, 800, 600)).toEqual({ incomeRef: 800, free: 200 });
  });
  it('returns negative free when over budget', () => {
    expect(computeFreeFunds(500, 100, 700)).toEqual({ incomeRef: 500, free: -200 });
  });
});

describe('dailyAllowance', () => {
  it('splits free funds evenly over remaining days', () => {
    expect(dailyAllowance(300, 10)).toBe(30);
  });
  it('clamps negative free to zero', () => {
    expect(dailyAllowance(-50, 10)).toBe(0);
  });
  it('returns zero when no days are left', () => {
    expect(dailyAllowance(100, 0)).toBe(0);
  });
});

describe('effectiveLimit', () => {
  const monthPlan: MonthlyBudgetPlan = {
    id: 'm1', monthKey: '2026-05', plannedIncome: 1000,
    categoryPlans: [{ category: 'Food', planned: 300 }],
    rollover: true, currency: 'BYN', createdAt: '', updatedAt: '',
  };
  const previousPlan: MonthlyBudgetPlan = {
    id: 'm0', monthKey: '2026-04', plannedIncome: 1000,
    categoryPlans: [{ category: 'Food', planned: 250 }],
    currency: 'BYN', createdAt: '', updatedAt: '',
  };

  it('rolls over the unspent remainder when enabled', () => {
    expect(effectiveLimit({
      category: 'Food', monthPlan, previousPlan,
      previousActuals: { Food: 200 },
    })).toBe(350); // 300 + (250 - 200)
  });

  it('clamps a negative carry-in to zero', () => {
    expect(effectiveLimit({
      category: 'Food', monthPlan, previousPlan,
      previousActuals: { Food: 999 },
    })).toBe(300);
  });

  it('ignores rollover when the flag is off', () => {
    const noRoll = { ...monthPlan, rollover: false };
    expect(effectiveLimit({
      category: 'Food', monthPlan: noRoll, previousPlan,
      previousActuals: { Food: 0 },
    })).toBe(300);
  });

  it('returns zero for unknown categories', () => {
    expect(effectiveLimit({
      category: 'Unknown', monthPlan, previousPlan, previousActuals: {},
    })).toBe(0);
  });
});

describe('subscriptionsBudget', () => {
  const payments: RegularPayment[] = [
    { id: '1', name: 'Netflix', amount: 15, currency: 'USD', dueDate: 5, category: 'Subs', isActive: true },
    { id: '2', name: 'Spotify', amount: 10, currency: 'USD', dueDate: 1, category: 'Subs', isActive: true },
    { id: '3', name: 'Old', amount: 99, currency: 'USD', dueDate: 1, category: 'Subs', isActive: false },
  ];

  it('sums active payments only', () => {
    expect(subscriptionsBudget({
      payments, baseCurrency: 'USD', convert: noop,
    })).toBe(25);
  });

  it('returns zero when no active payments exist', () => {
    expect(subscriptionsBudget({
      payments: payments.map(p => ({ ...p, isActive: false })),
      baseCurrency: 'USD', convert: noop,
    })).toBe(0);
  });

  it('applies the conversion callback', () => {
    expect(subscriptionsBudget({
      payments, baseCurrency: 'BYN',
      convert: (a, from, to) => from === 'USD' && to === 'BYN' ? a * 3 : a,
    })).toBe(75);
  });
});
