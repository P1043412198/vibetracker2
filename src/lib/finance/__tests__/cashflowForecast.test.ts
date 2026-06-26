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
