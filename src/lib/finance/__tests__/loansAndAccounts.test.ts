import { describe, expect, it } from 'vitest';
import {
  computeCashflowForecast,
  loanRemaining,
  loansAsPlannedExpenses,
} from '../budgetPlanner';
import type { Account, IncomeSource, Loan } from '../../../types';

function account(
  partial: Partial<Account> & Pick<Account, 'id' | 'initialBalance'>
): Account {
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

function loan(partial: Partial<Loan> & Pick<Loan, 'id' | 'monthlyPayment' | 'totalPayment'>): Loan {
  return {
    id: partial.id,
    name: partial.name ?? partial.id,
    amount: partial.amount ?? partial.totalPayment,
    currency: partial.currency,
    rate: partial.rate ?? 10,
    termMonths: partial.termMonths ?? 12,
    monthlyPayment: partial.monthlyPayment,
    totalPayment: partial.totalPayment,
    overpayment: partial.overpayment ?? 0,
    createdAt: '2025-01-01',
    payments: partial.payments,
    paymentDay: partial.paymentDay,
  };
}

const today = new Date(2026, 5, 26);

describe('loanRemaining', () => {
  it('subtracts net payments from the total scheduled payment', () => {
    const l = loan({
      id: 'l1',
      monthlyPayment: 250,
      totalPayment: 3000,
      payments: [
        { id: 'p1', date: '2026-06-05', amount: 250, type: 'payment' },
        { id: 'p2', date: '2026-05-05', amount: 250, type: 'payment' },
        { id: 'w1', date: '2026-05-10', amount: 100, type: 'withdrawal' },
      ],
    });
    expect(loanRemaining(l)).toBe(3000 - (500 - 100));
  });
});

describe('loansAsPlannedExpenses', () => {
  it('synthesises a planned expense for an active loan', () => {
    const result = loansAsPlannedExpenses({
      loans: [loan({ id: 'l1', name: 'Авто', monthlyPayment: 250, totalPayment: 3000, paymentDay: 10 })],
      rates: {},
      baseCurrency: 'BYN',
      today,
    });
    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      id: 'loan:l1',
      name: 'Кредит: Авто',
      amount: 250,
      dayFrom: 10,
      dayTo: 10,
      category: 'Кредиты',
      isPaid: false,
    });
  });

  it('marks loan paid when a payment exists in the current month', () => {
    const result = loansAsPlannedExpenses({
      loans: [
        loan({
          id: 'l1',
          monthlyPayment: 250,
          totalPayment: 3000,
          payments: [{ id: 'p1', date: '2026-06-05', amount: 250, type: 'payment' }],
        }),
      ],
      rates: {},
      baseCurrency: 'BYN',
      today,
    });
    expect(result[0].isPaid).toBe(true);
    expect(result[0].paidAmount).toBe(250);
  });

  it('skips fully paid-off loans', () => {
    const result = loansAsPlannedExpenses({
      loans: [
        loan({
          id: 'l1',
          monthlyPayment: 250,
          totalPayment: 500,
          payments: [
            { id: 'p1', date: '2026-06-05', amount: 250, type: 'payment' },
            { id: 'p2', date: '2026-05-05', amount: 250, type: 'payment' },
          ],
        }),
      ],
      rates: {},
      baseCurrency: 'BYN',
      today,
    });
    expect(result).toHaveLength(0);
  });
});

describe('computeCashflowForecast — accountIds filter', () => {
  const accounts = [
    account({ id: 'card', name: 'Карта', initialBalance: 360 }),
    account({ id: 'cash', name: 'Наличные', initialBalance: 1000 }),
  ];
  const sources = [income({ type: 'advance', name: 'Аванс', amount: 500, dayOfMonth: 30 })];

  it('uses all accounts when accountIds is empty', () => {
    const all = computeCashflowForecast({
      accounts,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: sources,
      plannedExpenses: [],
      today,
    });
    expect(all.currentBalance).toBe(1360);
  });

  it('restricts the balance to the selected account', () => {
    const onlyCard = computeCashflowForecast({
      accounts,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: sources,
      plannedExpenses: [],
      today,
      accountIds: ['card'],
    });
    expect(onlyCard.currentBalance).toBe(360);
  });
});
