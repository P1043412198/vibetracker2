/**
 * Budget planner utilities.
 *
 * Computes actual pay dates for salary/advance considering Belarus weekends
 * and public holidays, and calculates daily/weekly allowances between pay cycles.
 */
import { getDaysInMonth, isWeekend, format, addDays, differenceInCalendarDays, isBefore, isAfter, isSameDay } from 'date-fns';
import { isBYHoliday } from '../belarus/holidays';
import { convertCurrency } from '../utils';
import type { Account, IncomeSource, PlannedExpense, ActualExpense, Transaction } from '../../types';

/**
 * Given a target day-of-month and a year/month, returns the last working day
 * on or before that date. Adjusts backward for weekends and Belarus holidays.
 */
export function adjustedPayDate(year: number, month: number, dayOfMonth: number): Date {
  const daysInMonth = getDaysInMonth(new Date(year, month));
  const day = Math.min(dayOfMonth, daysInMonth);
  let date = new Date(year, month, day);

  // Walk backwards until we find a working day
  for (let i = 0; i < 10; i++) {
    const iso = format(date, 'yyyy-MM-dd');
    if (!isWeekend(date) && !isBYHoliday(iso)) {
      return date;
    }
    date = addDays(date, -1);
  }
  return date;
}

/**
 * Get the actual pay date for a given income source in a specific month.
 * For "last day of month" (advance), use dayOfMonth = 0 or undefined to mean last day.
 */
export function getPayDate(source: IncomeSource, year: number, month: number): Date | null {
  if (!source.dayOfMonth && source.type !== 'advance') return null;

  let targetDay: number;
  if (source.type === 'advance' && (!source.dayOfMonth || source.dayOfMonth >= 28)) {
    targetDay = getDaysInMonth(new Date(year, month));
  } else {
    targetDay = source.dayOfMonth || 15;
  }

  if (source.adjustForHolidays !== false) {
    return adjustedPayDate(year, month, targetDay);
  }
  const daysInMonth = getDaysInMonth(new Date(year, month));
  return new Date(year, month, Math.min(targetDay, daysInMonth));
}

export type BudgetCycle = {
  label: string;
  startDate: Date;
  endDate: Date;
  totalDays: number;
  daysLeft: number;
  totalIncome: number;
  totalPlannedExpenses: number;
  remainingAfterExpenses: number;
  actualSpent: number;
  remainingBudget: number;
  dailyBudget: number;
  weeklyBudget: number;
  fullWeeks: number;
  extraDays: number;
};

/**
 * Calculate budget cycles based on income sources and expenses.
 * Returns cycles: salary→advance, advance→salary, salary→salary.
 */
export function computeBudgetCycles(opts: {
  incomeSources: IncomeSource[];
  plannedExpenses: PlannedExpense[];
  actualExpenses: ActualExpense[];
  today?: Date;
}): BudgetCycle[] {
  const { incomeSources, plannedExpenses, actualExpenses, today = new Date() } = opts;
  const year = today.getFullYear();
  const month = today.getMonth();
  const cycles: BudgetCycle[] = [];

  // Find salary and advance dates/amounts
  const activeSources = incomeSources.filter(s => s.isActive);
  const salarySource = activeSources.find(s => s.type === 'salary');
  const advanceSource = activeSources.find(s => s.type === 'advance');
  const additionalSources = activeSources.filter(s => s.type === 'additional');
  const additionalTotal = additionalSources.reduce((sum, s) => sum + s.amount, 0);

  if (!salarySource && !advanceSource) return cycles;

  const salaryDate = salarySource ? getPayDate(salarySource, year, month) : null;
  const advanceDate = advanceSource ? getPayDate(advanceSource, year, month) : null;

  // Next month salary date for advance→salary cycle
  const nextMonth = month === 11 ? 0 : month + 1;
  const nextYear = month === 11 ? year + 1 : year;
  const nextSalaryDate = salarySource ? getPayDate(salarySource, nextYear, nextMonth) : null;

  // Previous month advance for salary→advance when salary is before advance
  const prevMonth = month === 0 ? 11 : month - 1;
  const prevYear = month === 0 ? year - 1 : year;
  const prevAdvanceDate = advanceSource ? getPayDate(advanceSource, prevYear, prevMonth) : null;

  const activeExpenses = plannedExpenses.filter(e => e.isActive);

  function expensesInRange(start: Date, end: Date): number {
    return activeExpenses
      .filter(e => {
        if (e.isPaid) return false;
        const expDay = e.dayFrom;
        const startDay = start.getDate();
        const endDay = end.getDate();
        if (start.getMonth() === end.getMonth()) {
          return expDay >= startDay && expDay <= endDay;
        }
        return expDay >= startDay || expDay <= endDay;
      })
      .reduce((sum, e) => sum + e.amount, 0);
  }

  function paidExpensesInRange(start: Date, end: Date): number {
    return activeExpenses
      .filter(e => e.isPaid && e.paidDate)
      .filter(e => {
        const d = new Date(e.paidDate!);
        return (isSameDay(d, start) || isAfter(d, start)) && (isSameDay(d, end) || isBefore(d, end));
      })
      .reduce((sum, e) => sum + (e.paidAmount || e.amount), 0);
  }

  function actualSpentInRange(start: Date, end: Date): number {
    return actualExpenses
      .filter(e => {
        const d = new Date(e.date);
        return (isSameDay(d, start) || isAfter(d, start)) && (isSameDay(d, end) || isBefore(d, end));
      })
      .reduce((sum, e) => sum + e.amount, 0);
  }

  function buildCycle(label: string, startDate: Date, endDate: Date, income: number): BudgetCycle {
    const totalDays = differenceInCalendarDays(endDate, startDate);
    const daysFromToday = isBefore(today, startDate) ? totalDays : Math.max(1, differenceInCalendarDays(endDate, today));
    const expenses = expensesInRange(startDate, endDate);
    const paid = paidExpensesInRange(startDate, endDate);
    const actual = actualSpentInRange(startDate, endDate);
    const totalSpent = paid + actual;
    const remaining = income - expenses - totalSpent;
    const daily = daysFromToday > 0 ? remaining / daysFromToday : 0;
    const fullWeeks = Math.floor(daysFromToday / 7);
    const extraDays = daysFromToday % 7;

    return {
      label,
      startDate,
      endDate,
      totalDays,
      daysLeft: daysFromToday,
      totalIncome: income,
      totalPlannedExpenses: expenses,
      remainingAfterExpenses: income - expenses,
      actualSpent: totalSpent,
      remainingBudget: remaining,
      dailyBudget: Math.max(0, daily),
      weeklyBudget: Math.max(0, daily * 7),
      fullWeeks,
      extraDays,
    };
  }

  // Cycle 1: Salary → Advance (if both exist and salary is before advance)
  if (salaryDate && advanceDate && isBefore(salaryDate, advanceDate)) {
    cycles.push(buildCycle(
      'От зарплаты до аванса',
      salaryDate,
      advanceDate,
      salarySource!.amount,
    ));
  }

  // Cycle 2: Advance → Next Salary
  if (advanceDate && nextSalaryDate) {
    cycles.push(buildCycle(
      'От аванса до зарплаты',
      advanceDate,
      nextSalaryDate,
      advanceSource!.amount,
    ));
  }

  // Cycle 3: Salary → Next Salary (full cycle)
  if (salaryDate && nextSalaryDate) {
    const totalIncome = (salarySource?.amount || 0) + (advanceSource?.amount || 0) + additionalTotal;
    cycles.push(buildCycle(
      'От зарплаты до зарплаты',
      salaryDate,
      nextSalaryDate,
      totalIncome,
    ));
  }

  return cycles;
}

// ── Cashflow forecast / "safe-to-spend" engine ──
//
// Unlike computeBudgetCycles (which is anchored to calendar pay dates and uses
// income amounts as the budget), this engine starts from the *real* current
// balance across all accounts and projects how much can be spent per day until
// the next income arrives, while still covering upcoming obligations and keeping
// an optional untouchable reserve.

/** A future cash event (income received, or an obligation that must be paid). */
export type CashEvent = {
  date: Date;
  /** Positive for income, negative for an obligation. Always in base currency. */
  amount: number;
  name: string;
  kind: 'income' | 'obligation';
};

/** One window between today/an income and the next income. */
export type CashflowSegment = {
  label: string;
  startDate: Date;
  endDate: Date;
  /** Calendar days in the window (>= 1). */
  days: number;
  /** Balance at the start of the window, in base currency. */
  startBalance: number;
  /** Obligations falling due inside the window, in base currency. */
  obligations: number;
  /** Income received at the end of the window (the next paycheck), base currency. */
  incomeAtEnd: number;
  /** Safe discretionary spend per day in this window, keeping reserve + obligations. */
  dailyLimit: number;
  /** Projected balance at the window end if you spend exactly dailyLimit/day. */
  endBalance: number;
  /** True when obligations + reserve cannot be covered before the next income. */
  shortfall: boolean;
};

export type CashflowForecast = {
  /** Real current balance summed across accounts, converted to base currency. */
  currentBalance: number;
  /** Untouchable reserve kept on top of obligations (base currency). */
  reserve: number;
  baseCurrency: string;
  segments: CashflowSegment[];
  /** The next income event after today (null when none is projected). */
  nextIncome: { name: string; date: Date; amount: number; daysUntil: number } | null;
  /** Headline number: safe spend/day from today until the next income. */
  dailyUntilNextIncome: number;
  /** Single steady spend/day across the whole horizon that never breaks reserve. */
  smoothedDaily: number;
  /** End of the projection horizon (next salary, or furthest projected income). */
  horizonEnd: Date | null;
  /** True when any segment cannot cover its obligations + reserve. */
  hasCashGap: boolean;
  /** True when a forecast could be produced (income sources + dates available). */
  ok: boolean;
};

function addMonth(year: number, month: number, k: number): { year: number; month: number } {
  const total = month + k;
  return { year: year + Math.floor(total / 12), month: ((total % 12) + 12) % 12 };
}

/**
 * Current balance per account = initialBalance + income − expense ± transfers,
 * each account's running total converted into `baseCurrency`.
 */
export function computeCurrentBalance(
  accounts: Account[],
  transactions: Transaction[],
  rates: Record<string, number>,
  baseCurrency: string
): number {
  const byAccount: Record<string, number> = {};
  for (const a of accounts) byAccount[a.id] = a.initialBalance;

  for (const t of transactions) {
    if (t.type === 'income' && t.accountId) {
      byAccount[t.accountId] = (byAccount[t.accountId] || 0) + t.amount;
    } else if (t.type === 'expense' && t.accountId) {
      byAccount[t.accountId] = (byAccount[t.accountId] || 0) - t.amount;
    } else if (t.type === 'transfer') {
      if (t.accountId) byAccount[t.accountId] = (byAccount[t.accountId] || 0) - t.amount;
      if (t.toAccountId) {
        const from = accounts.find(a => a.id === t.accountId);
        const to = accounts.find(a => a.id === t.toAccountId);
        const credited =
          from && to && from.currency !== to.currency
            ? convertCurrency(t.amount, from.currency, to.currency, rates)
            : t.amount;
        byAccount[t.toAccountId] = (byAccount[t.toAccountId] || 0) + credited;
      }
    }
  }

  let total = 0;
  for (const a of accounts) {
    total += convertCurrency(byAccount[a.id] || 0, a.currency, baseCurrency, rates);
  }
  return total;
}

/**
 * Project a cash runway from the current balance until the next salary (or the
 * furthest income within `horizonDays` when there is no salary source), and work
 * out a safe spend-per-day for each window and for the whole horizon.
 */
export function computeCashflowForecast(opts: {
  accounts: Account[];
  transactions: Transaction[];
  rates: Record<string, number>;
  baseCurrency: string;
  incomeSources: IncomeSource[];
  plannedExpenses: PlannedExpense[];
  /** Untouchable reserve in base currency (user-configurable, default 0). */
  reserve?: number;
  today?: Date;
  /** How far ahead to look for income when there is no salary source. */
  horizonDays?: number;
}): CashflowForecast {
  const {
    accounts,
    transactions,
    rates,
    baseCurrency,
    incomeSources,
    plannedExpenses,
    reserve = 0,
    today = new Date(),
    horizonDays = 45,
  } = opts;

  const startOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const currentBalance = computeCurrentBalance(accounts, transactions, rates, baseCurrency);

  const empty: CashflowForecast = {
    currentBalance,
    reserve,
    baseCurrency,
    segments: [],
    nextIncome: null,
    dailyUntilNextIncome: 0,
    smoothedDaily: 0,
    horizonEnd: null,
    hasCashGap: false,
    ok: false,
  };

  const active = incomeSources.filter(s => s.isActive);
  if (active.length === 0) return empty;

  const toBase = (amount: number, currency?: string) =>
    convertCurrency(amount, currency || baseCurrency, baseCurrency, rates);

  // Build income occurrences across the next few months.
  const incomeEvents: CashEvent[] = [];
  let firstSalary: Date | null = null;
  for (let k = 0; k <= 3; k++) {
    const { year, month } = addMonth(today.getFullYear(), today.getMonth(), k);
    for (const src of active) {
      const date = getPayDate(src, year, month);
      if (!date) continue;
      if (!isAfter(date, startOfToday)) continue;
      if (src.type === 'salary' && (!firstSalary || isBefore(date, firstSalary))) {
        firstSalary = date;
      }
      incomeEvents.push({ date, amount: toBase(src.amount, src.currency), name: src.name, kind: 'income' });
    }
  }

  // Horizon: up to and including the next salary; otherwise the furthest income
  // within horizonDays.
  const horizonEnd =
    firstSalary ?? incomeEvents
      .map(e => e.date)
      .filter(d => differenceInCalendarDays(d, startOfToday) <= horizonDays)
      .sort((a, b) => b.getTime() - a.getTime())[0] ?? null;

  if (!horizonEnd) return empty;

  const incomesInHorizon = incomeEvents
    .filter(e => !isAfter(e.date, horizonEnd))
    .sort((a, b) => a.date.getTime() - b.date.getTime());

  if (incomesInHorizon.length === 0) return empty;

  // Build obligation occurrences (unpaid planned expenses) at their deadline day.
  const obligations: CashEvent[] = [];
  for (const exp of plannedExpenses) {
    if (!exp.isActive || exp.isPaid) continue;
    for (let k = 0; k <= 3; k++) {
      const { year, month } = addMonth(today.getFullYear(), today.getMonth(), k);
      const dim = getDaysInMonth(new Date(year, month));
      const day = Math.min(exp.dayTo || exp.dayFrom || dim, dim);
      const date = new Date(year, month, day);
      if (isAfter(date, startOfToday) && !isAfter(date, horizonEnd)) {
        obligations.push({ date, amount: -toBase(exp.amount, exp.currency), name: exp.name, kind: 'obligation' });
      }
    }
  }

  // Walk segments between today and each income boundary.
  const segments: CashflowSegment[] = [];
  let cursor = startOfToday;
  let balance = currentBalance;
  let hasCashGap = false;

  // Feasibility accumulators for the smoothed daily figure.
  let smoothedDaily = Infinity;
  let cumDays = 0;
  let cumObligations = 0;
  let cumIncomeBefore = 0; // income received strictly before the current boundary

  for (let i = 0; i < incomesInHorizon.length; i++) {
    const inc = incomesInHorizon[i];
    const days = Math.max(1, differenceInCalendarDays(inc.date, cursor));
    const segObligations = obligations
      .filter(o => isAfter(o.date, cursor) || isSameDay(o.date, cursor))
      .filter(o => !isAfter(o.date, inc.date))
      .reduce((sum, o) => sum + Math.abs(o.amount), 0);

    const spendable = balance - reserve - segObligations;
    const dailyLimit = Math.max(0, spendable / days);
    const shortfall = spendable < 0;
    if (shortfall) hasCashGap = true;

    const endBalance = balance - segObligations - dailyLimit * days + inc.amount;

    segments.push({
      label: i === 0 ? `До «${inc.name}»` : `«${incomesInHorizon[i - 1].name}» → «${inc.name}»`,
      startDate: cursor,
      endDate: inc.date,
      days,
      startBalance: balance,
      obligations: segObligations,
      incomeAtEnd: inc.amount,
      dailyLimit,
      endBalance,
      shortfall,
    });

    // Smoothed daily: keep balance ≥ reserve just before each income arrives.
    cumDays += days;
    cumObligations += segObligations;
    const feasibleBefore = currentBalance + cumIncomeBefore - cumObligations - reserve;
    smoothedDaily = Math.min(smoothedDaily, feasibleBefore / cumDays);
    cumIncomeBefore += inc.amount;

    balance = endBalance;
    cursor = inc.date;
  }

  const next = incomesInHorizon[0];
  return {
    currentBalance,
    reserve,
    baseCurrency,
    segments,
    nextIncome: {
      name: next.name,
      date: next.date,
      amount: next.amount,
      daysUntil: Math.max(0, differenceInCalendarDays(next.date, startOfToday)),
    },
    dailyUntilNextIncome: segments[0]?.dailyLimit ?? 0,
    smoothedDaily: Math.max(0, smoothedDaily === Infinity ? 0 : smoothedDaily),
    horizonEnd,
    hasCashGap,
    ok: true,
  };
}
