import { describe, expect, it } from 'vitest';
import {
  computeCashflowForecast,
  computeScenarioProjection,
  computeSpendingAverages,
} from '../budgetPlanner';
import type { Account, IncomeSource, Transaction } from '../../../types';

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

function tx(partial: Partial<Transaction> & Pick<Transaction, 'type' | 'amount' | 'date'>): Transaction {
  return {
    id: partial.id ?? `${partial.type}-${partial.date}-${partial.amount}`,
    type: partial.type,
    amount: partial.amount,
    category: partial.category ?? 'misc',
    date: partial.date,
    accountId: partial.accountId ?? 'card',
    toAccountId: partial.toAccountId,
  };
}

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
    adjustForHolidays: partial.adjustForHolidays ?? false,
    isActive: partial.isActive ?? true,
    createdAt: '2025-01-01',
  };
}

const today = new Date(2026, 5, 26); // 26 June 2026
const accounts = [account({ id: 'card', initialBalance: 0 })];

describe('computeSpendingAverages', () => {
  it('returns empty when there are no income/expense transactions', () => {
    const a = computeSpendingAverages({
      accounts,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      today,
    });
    expect(a.monthsCounted).toBe(0);
    expect(a.avgDailyExpense).toBe(0);
    expect(a.months).toHaveLength(0);
  });

  it('averages each month over its days; current month over elapsed days', () => {
    const txs = [
      // May 2026 (full month, 31 days): 310 expense → 10/day
      tx({ type: 'expense', amount: 310, date: '2026-05-10' }),
      // June 2026 (26 days elapsed): 260 expense → 10/day, 1300 income
      tx({ type: 'expense', amount: 130, date: '2026-06-05' }),
      tx({ type: 'expense', amount: 130, date: '2026-06-20' }),
      tx({ type: 'income', amount: 1300, date: '2026-06-01' }),
    ];
    const a = computeSpendingAverages({
      accounts,
      transactions: txs,
      rates: {},
      baseCurrency: 'BYN',
      today,
    });
    expect(a.monthsCounted).toBe(2);
    const may = a.months.find(m => m.monthKey === '2026-05')!;
    const jun = a.months.find(m => m.monthKey === '2026-06')!;
    expect(may.days).toBe(31);
    expect(may.avgDailyExpense).toBeCloseTo(10, 6);
    expect(jun.days).toBe(26);
    expect(jun.avgDailyExpense).toBeCloseTo(10, 6);
    // Overall: (310 + 260) / (31 + 26) = 10/day
    expect(a.avgDailyExpense).toBeCloseTo(10, 6);
    expect(a.avgDailyIncome).toBeCloseTo(1300 / 57, 6);
    expect(a.avgMonthlyExpense).toBeCloseTo(285, 6); // 570 / 2
  });

  it('respects the account filter and ignores transfers', () => {
    const twoAccounts = [
      account({ id: 'card', initialBalance: 0 }),
      account({ id: 'cash', initialBalance: 0 }),
    ];
    const txs = [
      tx({ type: 'expense', amount: 100, date: '2026-06-10', accountId: 'card' }),
      tx({ type: 'expense', amount: 999, date: '2026-06-10', accountId: 'cash' }),
      tx({ type: 'transfer', amount: 50, date: '2026-06-11', accountId: 'card', toAccountId: 'cash' }),
    ];
    const a = computeSpendingAverages({
      accounts: twoAccounts,
      transactions: txs,
      rates: {},
      baseCurrency: 'BYN',
      today,
      accountIds: ['card'],
    });
    const jun = a.months.find(m => m.monthKey === '2026-06')!;
    expect(jun.totalExpense).toBeCloseTo(100, 6); // cash + transfer excluded
  });
});

describe('computeScenarioProjection', () => {
  const sources = [
    income({ type: 'advance', name: 'Аванс', amount: 500, dayOfMonth: 30 }),
    income({ type: 'salary', name: 'Зарплата', amount: 1200, dayOfMonth: 15 }),
  ];
  const balance360 = [account({ id: 'card', initialBalance: 360 })];
  const forecast = computeCashflowForecast({
    accounts: balance360,
    transactions: [],
    rates: {},
    baseCurrency: 'BYN',
    incomeSources: sources,
    plannedExpenses: [],
    reserve: 0,
    today,
    rangeMode: 'next', // today → advance (4 days), 360 on hand, +0 income inside
  });

  it('planToZero mirrors the smoothed safe daily spend', () => {
    const p = computeScenarioProjection({ scenario: 'planToZero', forecast })!;
    expect(p.dailySpend).toBeCloseTo(90, 6); // 360 / 4
    expect(p.endBalance).toBeCloseTo(0, 6);
    expect(p.shortfall).toBe(false);
  });

  it('customDaily projects the ending balance and flags a deficit', () => {
    const p = computeScenarioProjection({ scenario: 'customDaily', forecast, customDaily: 120 })!;
    // 360 − 120*4 = -120
    expect(p.endBalance).toBeCloseTo(-120, 6);
    expect(p.surplusOverReserve).toBeCloseTo(-120, 6);
    expect(p.shortfall).toBe(true);
  });

  it('avgExpense uses history and does NOT subtract obligations twice', () => {
    const averages = {
      months: [],
      avgDailyExpense: 50,
      avgDailyIncome: 0,
      avgMonthlyExpense: 1500,
      avgMonthlyIncome: 0,
      monthsCounted: 2,
    };
    const p = computeScenarioProjection({ scenario: 'avgExpense', forecast, averages })!;
    expect(p.dailySpend).toBeCloseTo(50, 6);
    expect(p.obligations).toBe(0);
    expect(p.endBalance).toBeCloseTo(360 - 50 * 4, 6); // 160
    expect(p.insufficientHistory).toBe(false);
  });

  it('flags insufficient history for average scenarios with no data', () => {
    const p = computeScenarioProjection({ scenario: 'avgExpenseIncome', forecast })!;
    expect(p.insufficientHistory).toBe(true);
  });
});
