import { describe, expect, it } from 'vitest';
import { computeCashflowForecast, computeCurrentBalance, isPlannedExpensePaidByTx, plannedExpenseAppliesToMonth } from '../budgetPlanner';
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
    category: partial.category,
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

describe('computeCashflowForecast — auto-detect paid planned expense', () => {
  // Rent due 20–29, today 28 June: unpaid → demands 1000; a matching expense
  // transaction this month should auto-clear the current-month obligation.
  const todayJun28 = new Date(2026, 5, 28);
  const advance30 = [income({ type: 'advance', name: 'Аванс', amount: 500, dayOfMonth: 30 })];
  const rent = expense({ name: 'Квартира', amount: 1000, dayFrom: 20, dayTo: 29, category: 'Жильё' });

  it('counts the obligation when no matching transaction exists', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: advance30,
      plannedExpenses: [rent],
      reserve: 0,
      today: todayJun28,
      rangeMode: 'next',
    });
    expect(f.range?.totalObligations).toBeCloseTo(1000, 6);
  });

  it('drops the current-month obligation when a matching transaction is found', () => {
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [
        { id: 't1', type: 'expense', amount: 1000, category: 'Жильё', date: '2026-06-22', accountId: 'card' },
      ],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: advance30,
      plannedExpenses: [rent],
      reserve: 0,
      today: todayJun28,
      rangeMode: 'next',
    });
    expect(f.range?.totalObligations).toBeCloseTo(0, 6);
  });
});

describe('plannedExpenseAppliesToMonth / recurrence', () => {
  const todayJun28 = new Date(2026, 5, 28);
  const advance30 = [income({ type: 'advance', name: 'Аванс', amount: 500, dayOfMonth: 30 })];

  it('once: applies only in its startMonth', () => {
    const e = expense({ name: 'Квартира', amount: 1000, dayFrom: 20, dayTo: 29 });
    const once = { ...e, recurrence: 'once' as const, startMonth: '2026-07' };
    expect(plannedExpenseAppliesToMonth(once, '2026-07', '2026-06')).toBe(true);
    expect(plannedExpenseAppliesToMonth(once, '2026-06', '2026-06')).toBe(false);
    expect(plannedExpenseAppliesToMonth(once, '2026-08', '2026-06')).toBe(false);
  });

  it('monthly with startMonth: suppressed before startMonth', () => {
    const e = expense({ name: 'Квартира', amount: 1000, dayFrom: 20, dayTo: 29 });
    const fromJuly = { ...e, startMonth: '2026-07' };
    expect(plannedExpenseAppliesToMonth(fromJuly, '2026-06', '2026-06')).toBe(false);
    expect(plannedExpenseAppliesToMonth(fromJuly, '2026-07', '2026-06')).toBe(true);
    expect(plannedExpenseAppliesToMonth(fromJuly, '2026-09', '2026-06')).toBe(true);
  });

  it('legacy (no recurrence/startMonth): applies every month', () => {
    const e = expense({ name: 'Квартира', amount: 1000, dayFrom: 20, dayTo: 29 });
    expect(plannedExpenseAppliesToMonth(e, '2026-06', '2026-06')).toBe(true);
    expect(plannedExpenseAppliesToMonth(e, '2027-01', '2026-06')).toBe(true);
  });

  it('a one-time July rent creates no obligation in a 28 Jun–1 Jul window', () => {
    const e = expense({ name: 'Квартира', amount: 1000, dayFrom: 20, dayTo: 29 });
    const julyRent: PlannedExpense = { ...e, recurrence: 'once', startMonth: '2026-07' };
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: advance30,
      plannedExpenses: [julyRent],
      reserve: 0,
      today: todayJun28,
      rangeMode: 'custom',
      customStart: new Date(2026, 5, 28),
      customEnd: new Date(2026, 6, 1),
    });
    expect(f.range?.totalObligations).toBeCloseTo(0, 6);
  });
});

describe('isPlannedExpensePaidByTx', () => {
  const acc = [account({ id: 'card', initialBalance: 0, currency: 'BYN' })];
  const rent = expense({ name: 'Квартира', amount: 1000, dayFrom: 20, dayTo: 29, category: 'Жильё' });

  it('matches by category and a comparable amount', () => {
    expect(
      isPlannedExpensePaidByTx({
        expense: rent,
        transactions: [
          { id: 't', type: 'expense', amount: 1000, category: 'Жильё', date: '2026-06-22', accountId: 'card' },
        ],
        monthKey: '2026-06',
        accounts: acc,
        rates: {},
        baseCurrency: 'BYN',
      }),
    ).toBe(true);
  });

  it('does not match a different month or a too-small amount', () => {
    expect(
      isPlannedExpensePaidByTx({
        expense: rent,
        transactions: [
          { id: 't1', type: 'expense', amount: 1000, category: 'Жильё', date: '2026-05-22', accountId: 'card' },
          { id: 't2', type: 'expense', amount: 100, category: 'Жильё', date: '2026-06-22', accountId: 'card' },
        ],
        monthKey: '2026-06',
        accounts: acc,
        rates: {},
        baseCurrency: 'BYN',
      }),
    ).toBe(false);
  });
});

describe('computeCashflowForecast — PR review regressions', () => {
  it('counts an unpaid obligation whose deadline is today', () => {
    // Rent due on the 28th, today is the 28th, advance on the 30th.
    const todayJun28 = new Date(2026, 5, 28);
    const advance30 = [income({ type: 'advance', name: 'Аванс', amount: 500, dayOfMonth: 30 })];
    const rentToday = expense({ name: 'Квартира', amount: 1000, dayFrom: 28, dayTo: 28, category: 'Жильё' });
    const f = computeCashflowForecast({
      accounts: balance360,
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: advance30,
      plannedExpenses: [rentToday],
      reserve: 0,
      today: todayJun28,
      rangeMode: 'next',
    });
    expect(f.range?.totalObligations).toBeCloseTo(1000, 6);
  });

  it('keeps future monthly occurrences when isPaid clears only the current cycle', () => {
    // Monthly rent marked paid in June must still be owed in July.
    const todayJun26 = new Date(2026, 5, 26);
    const salary5 = [income({ type: 'salary', name: 'Зарплата', amount: 2000, dayOfMonth: 5 })];
    const paidRent: PlannedExpense = {
      ...expense({ name: 'Квартира', amount: 1000, dayFrom: 10, dayTo: 10, category: 'Жильё' }),
      isPaid: true,
    };
    const f = computeCashflowForecast({
      accounts: [account({ id: 'card', initialBalance: 5000 })],
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: salary5,
      plannedExpenses: [paidRent],
      reserve: 0,
      today: todayJun26,
      rangeMode: 'salaryToSalary', // today → the salary after next (spans into July)
    });
    // June occurrence suppressed by isPaid; the July occurrence still counts.
    expect(f.range?.totalObligations).toBeCloseTo(1000, 6);
  });

  it('coalesces two income sources on the same day into one boundary', () => {
    // Salary and extra income both land on the 30th — must not create a
    // phantom 1-day segment nor double-count obligations that day.
    const todayJun26 = new Date(2026, 5, 26);
    const sameDay = [
      income({ id: 's', type: 'salary', name: 'Зарплата', amount: 1000, dayOfMonth: 30 }),
      income({ id: 'x', type: 'additional', name: 'Подработка', amount: 500, dayOfMonth: 30 }),
    ];
    const f = computeCashflowForecast({
      accounts: [account({ id: 'card', initialBalance: 400 })],
      transactions: [],
      rates: {},
      baseCurrency: 'BYN',
      incomeSources: sameDay,
      plannedExpenses: [],
      reserve: 0,
      today: todayJun26,
      rangeMode: 'next',
    });
    // One window today→30th (4 days), income at end summed to 1500.
    expect(f.segments).toHaveLength(1);
    expect(f.segments[0].days).toBe(4);
    expect(f.segments[0].incomeAtEnd).toBeCloseTo(1500, 6);
    expect(f.dailyUntilNextIncome).toBeCloseTo(100, 6);
  });

  it('preserves transfer FX metadata when summing only selected accounts', () => {
    // USD account transfers into a selected BYN account; the USD amount must be
    // converted, not credited raw, even though the USD account is excluded.
    const accounts = [
      account({ id: 'usd', initialBalance: 100, currency: 'USD' }),
      account({ id: 'byn', initialBalance: 0, currency: 'BYN' }),
    ];
    const transactions: Transaction[] = [
      { id: 't', type: 'transfer', amount: 100, category: 'x', date: '2026-06-03', accountId: 'usd', toAccountId: 'byn' },
    ];
    const rates = { BYN: 1, USD: 3 }; // 1 USD = 3 BYN
    // Only the BYN account is summed. It received a 100 USD transfer → 300 BYN.
    const only = computeCurrentBalance(accounts, transactions, rates, 'BYN', ['byn']);
    expect(only).toBeCloseTo(300, 6);
  });
});
