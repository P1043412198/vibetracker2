import { describe, expect, it } from 'vitest';
import { computeMonthlyComparison } from '../budgetPlanner';
import type { Account, Transaction } from '../../../types';

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

function tx(
  partial: Partial<Transaction> & Pick<Transaction, 'type' | 'amount' | 'date'>
): Transaction {
  return {
    id: partial.id ?? `${partial.type}-${partial.date}-${partial.amount}-${partial.category ?? ''}`,
    type: partial.type,
    amount: partial.amount,
    category: partial.category ?? 'misc',
    date: partial.date,
    accountId: partial.accountId ?? 'card',
    toAccountId: partial.toAccountId,
  };
}

const accounts = [account({ id: 'card', initialBalance: 0 })];

describe('computeMonthlyComparison', () => {
  it('returns zeroed sides when there are no transactions', () => {
    const c = computeMonthlyComparison({
      accounts,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      monthKeyA: '2026-05',
      monthKeyB: '2026-06',
    });
    expect(c.a.totalExpense).toBe(0);
    expect(c.b.totalExpense).toBe(0);
    expect(c.expenseDelta).toBe(0);
    expect(c.categories).toHaveLength(0);
    expect(c.a.month).toBe(4); // May = index 4
    expect(c.b.month).toBe(5);
  });

  it('sums income/expense per month and computes b − a deltas', () => {
    const txs = [
      tx({ type: 'expense', amount: 100, date: '2026-05-10', category: 'food' }),
      tx({ type: 'expense', amount: 50, date: '2026-05-15', category: 'fun' }),
      tx({ type: 'income', amount: 1000, date: '2026-05-01' }),
      tx({ type: 'expense', amount: 180, date: '2026-06-10', category: 'food' }),
      tx({ type: 'income', amount: 1200, date: '2026-06-01' }),
      // a transaction outside both months must be ignored
      tx({ type: 'expense', amount: 999, date: '2026-04-10', category: 'food' }),
    ];
    const c = computeMonthlyComparison({
      accounts,
      transactions: txs,
      rates: {},
      baseCurrency: 'BYN',
      monthKeyA: '2026-05',
      monthKeyB: '2026-06',
    });
    expect(c.a.totalExpense).toBe(150);
    expect(c.a.totalIncome).toBe(1000);
    expect(c.a.net).toBe(850);
    expect(c.b.totalExpense).toBe(180);
    expect(c.b.totalIncome).toBe(1200);
    expect(c.b.net).toBe(1020);

    expect(c.expenseDelta).toBe(30); // 180 − 150
    expect(c.incomeDelta).toBe(200); // 1200 − 1000
    expect(c.netDelta).toBe(170); // 1020 − 850

    // food: 100 → 180 (delta 80); fun: 50 → 0 (delta -50). Sorted by |delta|.
    expect(c.categories[0]).toEqual({ category: 'food', a: 100, b: 180, delta: 80 });
    expect(c.categories[1]).toEqual({ category: 'fun', a: 50, b: 0, delta: -50 });
  });

  it('ignores transfers and respects the accountIds filter', () => {
    const txs = [
      tx({ type: 'transfer', amount: 500, date: '2026-06-10', accountId: 'card' }),
      tx({ type: 'expense', amount: 70, date: '2026-06-10', category: 'food', accountId: 'card' }),
      tx({ type: 'expense', amount: 90, date: '2026-06-11', category: 'food', accountId: 'cash' }),
    ];
    const accts = [
      account({ id: 'card', initialBalance: 0 }),
      account({ id: 'cash', initialBalance: 0, type: 'cash' }),
    ];
    const c = computeMonthlyComparison({
      accounts: accts,
      transactions: txs,
      rates: {},
      baseCurrency: 'BYN',
      monthKeyA: '2026-05',
      monthKeyB: '2026-06',
      accountIds: ['card'],
    });
    // transfer ignored; only the card expense counts
    expect(c.b.totalExpense).toBe(70);
    expect(c.b.byCategory.food).toBe(70);
  });

  it('converts foreign-currency amounts into the base currency', () => {
    const accts = [account({ id: 'usd', initialBalance: 0, currency: 'USD' })];
    const txs = [
      tx({ type: 'expense', amount: 100, date: '2026-06-10', category: 'food', accountId: 'usd' }),
    ];
    const c = computeMonthlyComparison({
      accounts: accts,
      transactions: txs,
      rates: { USD: 3, BYN: 1 }, // 1 USD = 3 BYN
      baseCurrency: 'BYN',
      monthKeyA: '2026-05',
      monthKeyB: '2026-06',
    });
    expect(c.b.totalExpense).toBe(300);
  });
});
