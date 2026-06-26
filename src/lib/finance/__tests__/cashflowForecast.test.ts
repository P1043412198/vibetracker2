import { describe, expect, it } from 'vitest';
import { computeCashflowForecast, computeCurrentBalance } from '../budgetPlanner';
import type { Account, IncomeSource, PlannedExpense, Transaction } from '../../../types';

function income(
  partial: Partial<IncomeSource> & Pick<IncomeSource, 'type' | 'amount'>
): IncomeSource {
  return {
    id: partial.id ?? `${partial.type}-1`,
    name: partial.name ?? partial.type,
    type: partial.type,
    amount: partial.amount,
    currency: partial.currency,
    dayOfMonth: partial.dayOfMonth,
    // Keep dates deterministic in tests (no weekend/holiday shifting).
    adjustForHolidays: partial.adjustForHolidays ?? false,
    isActive: partial.isActive ?? true,
    createdAt: '2025-01-01',
  };
}

function account(partial: Partial<Account> & Pick<Account, 'id' | 'initialBalance'>): Account {
  return {
    id: partial.id,
    name: partial.name ?? partial.id,
    type: partial.type ?? 'card',
    currency: partial.currency ?? 'BYN',
    initialBalance: partial.initialBalance,
    color: partial.color ?? '#000',
    createdAt: '2025-01-01',
  };
}

function expense(
  partial: Partial<PlannedExpense> & Pick<PlannedExpense, 'name' | 'amount' | 'dayTo'>
): PlannedExpense {
  return {
    id: partial.id ?? partial.name,
    name: partial.name,
    amount: partial.amount,
    currency: partial.currency,
    dayFrom: partial.dayFrom ?? partial.dayTo,
    dayTo: partial.dayTo,
    isPaid: partial.isPaid ?? false,
    isActive: partial.isActive ?? true,
    createdAt: '2025-01-01',
  };
}

// User's scenario: today 26 June 2026, 360 ₽ on hand, advance +500 on the 30th,
// salary +1200 on the 15th of July.
const today = new Date(2026, 5, 26);
const baseSources = [
  income({ type: 'advance', name: 'Аванс', amount: 500, dayOfMonth: 30 }),
  income({ type: 'salary', name: 'Зарплата', amount: 1200, dayOfMonth: 15 }),
];
const balance360 = [account({ id: 'card', initialBalance: 360 })];

describe('computeCashflowForecast — user scenario', () => {
  it('gives 90 ₽/day until the advance (4 days), reserve 0', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: baseSources,
      plannedExpenses: [],
      reserve: 0,
      today,
    });

    expect(f.ok).toBe(true);
    expect(f.currentBalance).toBeCloseTo(360, 6);
    expect(f.nextIncome?.name).toBe('Аванс');
    expect(f.nextIncome?.daysUntil).toBe(4);
    expect(f.dailyUntilNextIncome).toBeCloseTo(90, 6);
    expect(f.hasCashGap).toBe(false);

    // Two windows: today→advance, advance→salary.
    expect(f.segments).toHaveLength(2);
    expect(f.segments[0].days).toBe(4);
    expect(f.segments[0].dailyLimit).toBeCloseTo(90, 6);
    expect(f.segments[1].incomeAtEnd).toBeCloseTo(1200, 6);
  });

  it('lowers the daily limit to 65 ₽/day when the user keeps a 100 ₽ reserve', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: baseSources,
      plannedExpenses: [],
      reserve: 100,
      today,
    });

    expect(f.reserve).toBe(100);
    expect(f.dailyUntilNextIncome).toBeCloseTo(65, 6); // (360 − 100) / 4
    expect(f.hasCashGap).toBe(false);
  });
});

describe('computeCashflowForecast — obligations', () => {
  it('reserves an upcoming obligation without flagging a gap when affordable', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: baseSources,
      plannedExpenses: [expense({ name: 'Подписка', amount: 60, dayTo: 27 })],
      reserve: 0,
      today,
    });

    expect(f.segments[0].obligations).toBeCloseTo(60, 6);
    expect(f.segments[0].dailyLimit).toBeCloseTo((360 - 60) / 4, 6); // 75 ₽/day
    expect(f.segments[0].shortfall).toBe(false);
    expect(f.hasCashGap).toBe(false);
  });

  it('flags a cash gap when an obligation exceeds the balance before income', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: baseSources,
      plannedExpenses: [expense({ name: 'Кредит', amount: 500, dayTo: 27 })],
      reserve: 0,
      today,
    });

    expect(f.segments[0].shortfall).toBe(true);
    expect(f.segments[0].dailyLimit).toBe(0);
    expect(f.hasCashGap).toBe(true);
  });
});

describe('computeCashflowForecast — edge cases', () => {
  it('returns ok=false when there are no active income sources', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: [],
      plannedExpenses: [],
      today,
    });

    expect(f.ok).toBe(false);
    expect(f.segments).toHaveLength(0);
    expect(f.dailyUntilNextIncome).toBe(0);
  });

  it('converts multi-currency balances into the base currency', () => {
    const f = computeCashflowForecast({
      accounts: [
        account({ id: 'byn', initialBalance: 360, currency: 'BYN' }),
        account({ id: 'usd', initialBalance: 50, currency: 'USD' }),
      ],
      transactions: [],
      // 1 USD = 3 BYN.
      rates: { BYN: 1, USD: 3 },
      baseCurrency: 'BYN',
      incomeSources: baseSources,
      plannedExpenses: [],
      reserve: 0,
      today,
    });

    // 360 BYN + 50 USD × 3 = 510 BYN.
    expect(f.currentBalance).toBeCloseTo(510, 6);
    expect(f.dailyUntilNextIncome).toBeCloseTo(510 / 4, 6);
  });
});

describe('computeCashflowForecast — range modes', () => {
  it('defaults to the salary horizon (auto) with the next income as the headline', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: baseSources,
      plannedExpenses: [],
      today,
    });
    expect(f.range?.mode).toBe('auto');
    // Salary on the 15th of July → horizon ends there.
    expect(f.horizonEnd?.getMonth()).toBe(6); // July
    expect(f.horizonEnd?.getDate()).toBe(15);
  });

  it('stops at the next income for the "next" mode', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: baseSources,
      plannedExpenses: [],
      today,
      rangeMode: 'next',
    });
    expect(f.segments).toHaveLength(1);
    expect(f.range?.endDate.getDate()).toBe(30); // advance
    expect(f.range?.label).toBe('До ближайшего дохода');
    expect(f.dailyUntilNextIncome).toBeCloseTo(90, 6);
  });

  it('projects a full advance→advance cycle (over the salary in between)', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: baseSources,
      plannedExpenses: [],
      today,
      rangeMode: 'advanceToAdvance',
    });
    expect(f.range?.label).toBe('Аванс → Аванс');
    // Advance (dayOfMonth >= 28) means last day of month → 31 July 2026.
    expect(f.horizonEnd?.getMonth()).toBe(6); // July
    expect(f.horizonEnd?.getDate()).toBe(31);
    // Both the next advance and the salary fall inside the window.
    expect(f.range?.totalIncome).toBeCloseTo(500 + 1200, 6);
    // today→adv, adv→salary, salary→adv = 3 segments.
    expect(f.segments).toHaveLength(3);
  });

  it('honours a custom end date', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: baseSources,
      plannedExpenses: [],
      today,
      rangeMode: 'custom',
      customEnd: new Date(2026, 6, 5), // 5 July 2026
    });
    expect(f.range?.mode).toBe('custom');
    expect(f.range?.endDate.getDate()).toBe(5);
    expect(f.range?.endDate.getMonth()).toBe(6);
    // Only the advance (30 June) falls inside; salary (15 July) does not.
    expect(f.range?.totalIncome).toBeCloseTo(500, 6);
  });
});

describe('computeCurrentBalance', () => {
  it('applies income, expense and transfers per account', () => {
    const accounts = [
      account({ id: 'a', initialBalance: 1000, currency: 'BYN' }),
      account({ id: 'b', initialBalance: 0, currency: 'BYN' }),
    ];
    const transactions: Transaction[] = [
      { id: '1', type: 'income', amount: 200, category: 'x', date: '2026-06-01', accountId: 'a' },
      { id: '2', type: 'expense', amount: 50, category: 'x', date: '2026-06-02', accountId: 'a' },
      { id: '3', type: 'transfer', amount: 300, category: 'x', date: '2026-06-03', accountId: 'a', toAccountId: 'b' },
    ];

    // a: 1000 + 200 − 50 − 300 = 850; b: 0 + 300 = 300; total = 1150.
    expect(computeCurrentBalance(accounts, transactions, {}, 'BYN')).toBeCloseTo(1150, 6);
  });
});
