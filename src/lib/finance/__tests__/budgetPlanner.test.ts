import { describe, expect, it } from 'vitest';
import { computeBudgetCycles } from '../budgetPlanner';
import type { Account, IncomeSource, PlannedExpense, Transaction } from '../../../types';

function income(partial: Partial<IncomeSource> & Pick<IncomeSource, 'type' | 'amount'>): IncomeSource {
  return {
    id: partial.id ?? `${partial.type}-1`,
    name: partial.name ?? partial.type,
    type: partial.type,
    amount: partial.amount,
    dayOfMonth: partial.dayOfMonth,
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
    dayFrom: partial.dayFrom ?? partial.dayTo,
    dayTo: partial.dayTo,
    isPaid: partial.isPaid ?? false,
    isActive: partial.isActive ?? true,
    createdAt: '2025-01-01',
  };
}

// Today 26 June 2026: advance on the 30th (+500), salary on the 15th (+1200).
const today = new Date(2026, 5, 26);
const incomeSources = [
  income({ type: 'advance', name: 'Аванс', amount: 500, dayOfMonth: 30 }),
  income({ type: 'salary', name: 'Зарплата', amount: 1200, dayOfMonth: 15 }),
];

describe('computeBudgetCycles — real-balance model', () => {
  it('derives cycles from the current balance, not from income amounts', () => {
    const cycles = computeBudgetCycles({
      accounts: [account({ id: 'card', initialBalance: 360 })],
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources,
      plannedExpenses: [],
      today,
    });

    const untilIncome = cycles.find((c) => c.label === 'До ближайшего дохода');
    expect(untilIncome).toBeDefined();
    // today → advance = 4 days, 360 / 4 = 90 ₽/day (same as the safe-to-spend card).
    expect(untilIncome!.daysLeft).toBe(4);
    expect(untilIncome!.dailyBudget).toBeCloseTo(90, 6);
    expect(untilIncome!.remainingBudget).toBeCloseTo(360, 6);

    // The repeating-cycle windows are present.
    expect(cycles.some((c) => c.label === 'Аванс → Аванс')).toBe(true);
    expect(cycles.some((c) => c.label === 'Зарплата → Зарплата')).toBe(true);
  });

  it('sums every obligation in the window rather than keeping only the last (bug #1)', () => {
    const cycles = computeBudgetCycles({
      accounts: [account({ id: 'card', initialBalance: 360 })],
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources,
      plannedExpenses: [
        expense({ name: 'a', amount: 30, dayTo: 27 }),
        expense({ name: 'b', amount: 20, dayTo: 28 }),
        expense({ name: 'c', amount: 10, dayTo: 29 }),
      ],
      today,
    });

    const untilIncome = cycles.find((c) => c.label === 'До ближайшего дохода');
    // 30 + 20 + 10 = 60 reserved → (360 − 60) / 4 = 75 ₽/day. A reduce without an
    // accumulator (the original bug) would have kept only 10.
    expect(untilIncome!.totalPlannedExpenses).toBeCloseTo(60, 6);
    expect(untilIncome!.dailyBudget).toBeCloseTo(75, 6);
  });

  it('keeps the user reserve out of the daily budget', () => {
    const cycles = computeBudgetCycles({
      accounts: [account({ id: 'card', initialBalance: 360 })],
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources,
      plannedExpenses: [],
      reserve: 100,
      today,
    });
    const untilIncome = cycles.find((c) => c.label === 'До ближайшего дохода');
    // (360 − 100) / 4 = 65 ₽/day.
    expect(untilIncome!.dailyBudget).toBeCloseTo(65, 6);
  });

  it('returns no cycles when there are no income sources', () => {
    const cycles = computeBudgetCycles({
      accounts: [account({ id: 'card', initialBalance: 360 })],
      transactions: [] as Transaction[],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: [],
      plannedExpenses: [],
      today,
    });
    expect(cycles).toHaveLength(0);
  });
});
