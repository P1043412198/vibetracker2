/**
 * Pure helpers for monthly budget plan vs fact calculations.
 *
 * Kept currency-agnostic — the caller is responsible for converting amounts
 * into a single currency (the plan's currency) before passing them in.
 */
import {
  startOfMonth, endOfMonth, parseISO, isWithinInterval,
  getDaysInMonth, getDate, isSameMonth, isAfter, format, subMonths,
} from 'date-fns';
import type { MonthlyBudgetPlan, RegularPayment, Transaction, Account } from '../types';

export const monthKeyOf = (date: Date) => format(date, 'yyyy-MM');
export const previousMonthKey = (monthKey: string) => {
  const [y, m] = monthKey.split('-').map(Number);
  return monthKeyOf(subMonths(new Date(y, m - 1, 1), 1));
};

export type MonthFacts = {
  income: number;
  expense: number;
  expenseByCategory: Record<string, number>;
  monthTx: Transaction[];
};

/**
 * Compute month income/expense in a target currency. Conversion is delegated
 * to a callback so the caller controls FX rates.
 */
export function computeMonthFacts(opts: {
  month: Date;
  transactions: Transaction[];
  accounts: Account[];
  baseCurrency: string;
  convert: (amount: number, from: string, to: string) => number;
}): MonthFacts {
  const { month, transactions, accounts, baseCurrency, convert } = opts;
  const start = startOfMonth(month);
  const end = endOfMonth(month);

  const monthTx = transactions.filter(t => {
    try { return isWithinInterval(parseISO(t.date), { start, end }); } catch { return false; }
  });

  let income = 0;
  let expense = 0;
  const expenseByCategory: Record<string, number> = {};
  for (const t of monthTx) {
    const acc = accounts.find(a => a.id === t.accountId);
    const cur = acc?.currency || baseCurrency;
    const amount = convert(t.amount, cur, baseCurrency);
    if (t.type === 'income') {
      income += amount;
    } else if (t.type === 'expense') {
      expense += amount;
      expenseByCategory[t.category] = (expenseByCategory[t.category] || 0) + amount;
    }
  }

  return { income, expense, expenseByCategory, monthTx };
}

/**
 * Days remaining in the selected month relative to today (1-based, never <1).
 * For past months returns 1, for future returns the full number of days.
 */
export function daysLeftInMonth(month: Date, today: Date = new Date()): number {
  const daysInMonth = getDaysInMonth(month);
  if (isSameMonth(month, today)) {
    return Math.max(daysInMonth - getDate(today) + 1, 1);
  }
  return isAfter(month, today) ? daysInMonth : 1;
}

/**
 * Effective category limit for a month, accounting for an optional rollover
 * carry-in from the previous month.
 */
export function effectiveLimit(opts: {
  category: string;
  monthPlan?: MonthlyBudgetPlan;
  previousPlan?: MonthlyBudgetPlan;
  previousActuals?: Record<string, number>;
}): number {
  const { category, monthPlan, previousPlan, previousActuals } = opts;
  const baseLimit = monthPlan?.categoryPlans.find(c => c.category === category)?.planned ?? 0;
  if (!monthPlan?.rollover) return baseLimit;
  const prevLimit = previousPlan?.categoryPlans.find(c => c.category === category)?.planned ?? 0;
  const prevActual = previousActuals?.[category] ?? 0;
  const carry = Math.max(prevLimit - prevActual, 0);
  return baseLimit + carry;
}

/** Free funds = (planned income or actual income) - actual expense, in plan currency. */
export function computeFreeFunds(plannedIncome: number, actualIncome: number, actualExpense: number) {
  const incomeRef = plannedIncome > 0 ? plannedIncome : actualIncome;
  return { incomeRef, free: incomeRef - actualExpense };
}

/** Even split of free funds across remaining days; clamps negative free to 0. */
export function dailyAllowance(freeFunds: number, daysLeft: number) {
  if (daysLeft <= 0) return 0;
  return freeFunds > 0 ? freeFunds / daysLeft : 0;
}

/**
 * Auto-suggest a "Подписки" limit from active recurring payments due during
 * the selected month. Currency conversion is delegated.
 */
export function subscriptionsBudget(opts: {
  payments: RegularPayment[];
  baseCurrency: string;
  convert: (amount: number, from: string, to: string) => number;
}): number {
  const { payments, baseCurrency, convert } = opts;
  return payments
    .filter(p => p.isActive)
    .reduce((sum, p) => sum + convert(p.amount, p.currency || baseCurrency, baseCurrency), 0);
}
