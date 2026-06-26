/**
 * Budget planner utilities.
 *
 * Computes actual pay dates for salary/advance considering Belarus weekends
 * and public holidays, and calculates daily/weekly allowances between pay cycles.
 */
import { getDaysInMonth, isWeekend, format, addDays, differenceInCalendarDays, isBefore, isAfter, isSameDay } from 'date-fns';
import { isBYHoliday } from '../belarus/holidays';
import { convertCurrency } from '../utils';
import type { Account, IncomeSource, PlannedExpense, Transaction } from '../../types';

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
 * Calculate budget cycles anchored to the *real* current balance, using the
 * same cashflow engine as the "safe-to-spend" card so the two never diverge.
 *
 * Produces, when the matching income sources exist:
 *   • До ближайшего дохода   (today → next income)
 *   • Аванс → Аванс          (today → the advance after next)
 *   • Зарплата → Зарплата    (today → the salary after next)
 *
 * Each cycle's budget is `currentBalance + income in window − obligations −
 * reserve`, and the daily figure is the steady safe spend/day for the window.
 */
export function computeBudgetCycles(opts: {
  accounts: Account[];
  transactions: Transaction[];
  rates: Record<string, number>;
  baseCurrency: string;
  incomeSources: IncomeSource[];
  plannedExpenses: PlannedExpense[];
  reserve?: number;
  today?: Date;
}): BudgetCycle[] {
  const { incomeSources, today = new Date() } = opts;
  const activeSources = incomeSources.filter(s => s.isActive);
  const hasAdvance = activeSources.some(s => s.type === 'advance');
  const hasSalary = activeSources.some(s => s.type === 'salary');

  const wanted: CashflowRangeMode[] = ['next'];
  if (hasAdvance) wanted.push('advanceToAdvance');
  if (hasSalary) wanted.push('salaryToSalary');

  const cycles: BudgetCycle[] = [];
  const seen = new Set<string>();

  for (const mode of wanted) {
    const forecast = computeCashflowForecast({ ...opts, rangeMode: mode });
    const range = forecast.range;
    if (!forecast.ok || !range) continue;

    // Skip duplicates (e.g. advance→advance window that coincides with another).
    const key = `${range.startDate.getTime()}-${range.endDate.getTime()}-${range.label}`;
    if (seen.has(key)) continue;
    seen.add(key);

    const available = range.startBalance + range.totalIncome;
    // Keep the budget consistent with the card: total safe discretionary spend
    // over the window is the steady daily figure across all its days.
    const remainingBudget = range.smoothedDaily * range.daysLeft;
    const fullWeeks = Math.floor(range.daysLeft / 7);
    const extraDays = range.daysLeft % 7;

    cycles.push({
      label: range.label,
      startDate: range.startDate,
      endDate: range.endDate,
      totalDays: range.days,
      daysLeft: range.daysLeft,
      totalIncome: available,
      totalPlannedExpenses: range.totalObligations,
      remainingAfterExpenses: available - range.totalObligations,
      actualSpent: 0,
      remainingBudget,
      dailyBudget: range.smoothedDaily,
      weeklyBudget: range.smoothedDaily * 7,
      fullWeeks,
      extraDays,
    });
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

/**
 * Which window the forecast should be calculated over.
 * - `auto`            until the next salary (legacy default)
 * - `next`            until the next income of any kind
 * - `advanceToAdvance` a full advance→advance cycle ahead
 * - `salaryToSalary`   a full salary→salary cycle ahead
 * - `fullHorizon`      the furthest income within `horizonDays`
 * - `custom`           a user-picked date window (`customStart`/`customEnd`)
 */
export type CashflowRangeMode =
  | 'auto'
  | 'next'
  | 'advanceToAdvance'
  | 'salaryToSalary'
  | 'fullHorizon'
  | 'custom';

/** Summary of the period the forecast was calculated over. */
export type CashflowRangeSummary = {
  mode: CashflowRangeMode;
  label: string;
  startDate: Date;
  endDate: Date;
  /** Calendar days inside the window (>= 1). */
  days: number;
  /** Calendar days from today to the window end (>= 0). */
  daysLeft: number;
  /** Real balance at the window start, in base currency. */
  startBalance: number;
  /** Income arriving inside the window, base currency. */
  totalIncome: number;
  /** Obligations falling due inside the window, base currency. */
  totalObligations: number;
  /** Steady safe spend/day across the whole window keeping the reserve. */
  smoothedDaily: number;
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
  /** The window the forecast was calculated over (null when no forecast). */
  range: CashflowRangeSummary | null;
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

/** An income occurrence with the originating source type (for cycle detection). */
type IncomeOccurrence = { date: Date; amount: number; name: string; type: IncomeSource['type'] };

const RANGE_LABELS: Record<CashflowRangeMode, string> = {
  auto: 'До зарплаты',
  next: 'До ближайшего дохода',
  advanceToAdvance: 'Аванс → Аванс',
  salaryToSalary: 'Зарплата → Зарплата',
  fullHorizon: 'Весь горизонт',
  custom: 'Свой период',
};

/**
 * Project a cash runway from the current balance over a chosen window and work
 * out a safe spend-per-day for each segment and for the whole window.
 *
 * The window is controlled by `rangeMode` (default `auto` = until the next
 * salary, preserving the original behaviour). All figures derive from the real
 * current balance across accounts, so the card and the budget cycles stay
 * consistent.
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
  /** Which window to calculate over (default `auto`). */
  rangeMode?: CashflowRangeMode;
  /** Start of the custom window (only for `rangeMode: 'custom'`). */
  customStart?: Date;
  /** End of the custom window (only for `rangeMode: 'custom'`). */
  customEnd?: Date;
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
    rangeMode = 'auto',
    customStart,
    customEnd,
  } = opts;

  const startOf = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const startOfToday = startOf(today);
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
    range: null,
    hasCashGap: false,
    ok: false,
  };

  const active = incomeSources.filter(s => s.isActive);
  if (active.length === 0) return empty;

  const toBase = (amount: number, currency?: string) =>
    convertCurrency(amount, currency || baseCurrency, baseCurrency, rates);

  // Build income occurrences across the next several months (enough to find a
  // second advance/salary for the repeating-cycle modes).
  const incomeEvents: IncomeOccurrence[] = [];
  const advanceDates: Date[] = [];
  const salaryDates: Date[] = [];
  let firstSalary: Date | null = null;
  for (let k = 0; k <= 6; k++) {
    const { year, month } = addMonth(today.getFullYear(), today.getMonth(), k);
    for (const src of active) {
      const date = getPayDate(src, year, month);
      if (!date) continue;
      if (!isAfter(date, startOfToday)) continue;
      if (src.type === 'salary') {
        if (!firstSalary || isBefore(date, firstSalary)) firstSalary = date;
        salaryDates.push(date);
      }
      if (src.type === 'advance') advanceDates.push(date);
      incomeEvents.push({ date, amount: toBase(src.amount, src.currency), name: src.name, type: src.type });
    }
  }
  incomeEvents.sort((a, b) => a.date.getTime() - b.date.getTime());
  advanceDates.sort((a, b) => a.getTime() - b.getTime());
  salaryDates.sort((a, b) => a.getTime() - b.getTime());

  const nextIncomeDate = incomeEvents[0]?.date ?? null;
  const furthestWithinHorizon = incomeEvents
    .map(e => e.date)
    .filter(d => differenceInCalendarDays(d, startOfToday) <= horizonDays)
    .sort((a, b) => b.getTime() - a.getTime())[0] ?? null;

  // Resolve the window [rangeStart, horizonEnd] from the requested mode.
  let rangeStart = startOfToday;
  let horizonEnd: Date | null;
  switch (rangeMode) {
    case 'next':
      horizonEnd = nextIncomeDate;
      break;
    case 'advanceToAdvance':
      horizonEnd = advanceDates[1] ?? advanceDates[0] ?? null;
      break;
    case 'salaryToSalary':
      horizonEnd = salaryDates[1] ?? salaryDates[0] ?? null;
      break;
    case 'fullHorizon':
      horizonEnd = furthestWithinHorizon;
      break;
    case 'custom':
      rangeStart = customStart ? startOf(customStart) : startOfToday;
      horizonEnd = customEnd ? startOf(customEnd) : null;
      break;
    case 'auto':
    default:
      horizonEnd = firstSalary ?? furthestWithinHorizon;
      break;
  }
  // Fall back to the broadest sensible horizon if the requested one is missing.
  if (!horizonEnd) horizonEnd = firstSalary ?? furthestWithinHorizon ?? nextIncomeDate;
  if (!horizonEnd || !isAfter(horizonEnd, startOfToday)) return empty;
  if (rangeStart < startOfToday) rangeStart = startOfToday;
  if (!isAfter(horizonEnd, rangeStart)) return empty;

  // Build obligation occurrences (unpaid planned expenses) at their deadline day.
  const obligations: CashEvent[] = [];
  for (const exp of plannedExpenses) {
    if (!exp.isActive || exp.isPaid) continue;
    for (let k = 0; k <= 6; k++) {
      const { year, month } = addMonth(today.getFullYear(), today.getMonth(), k);
      const dim = getDaysInMonth(new Date(year, month));
      const day = Math.min(exp.dayTo || exp.dayFrom || dim, dim);
      const date = new Date(year, month, day);
      if (isAfter(date, startOfToday) && !isAfter(date, horizonEnd)) {
        obligations.push({ date, amount: -toBase(exp.amount, exp.currency), name: exp.name, kind: 'obligation' });
      }
    }
  }

  /**
   * Walk the windows between `from` and `to`, splitting at each income event.
   * Returns the segments plus aggregate figures for the whole window.
   */
  function walk(from: Date, startBalance: number, to: Date) {
    const incs = incomeEvents.filter(e => isAfter(e.date, from) && !isAfter(e.date, to));
    const boundaries: { date: Date; income: number; name: string | null }[] = incs.map(e => ({
      date: e.date,
      income: e.amount,
      name: e.name,
    }));
    const last = boundaries[boundaries.length - 1];
    if ((!last || isBefore(last.date, to)) && isAfter(to, from)) {
      boundaries.push({ date: to, income: 0, name: null });
    }

    const segs: CashflowSegment[] = [];
    let cursor = from;
    let balance = startBalance;
    let gap = false;
    let smoothed = Infinity;
    let cumDays = 0;
    let cumObligations = 0;
    let cumIncomeBefore = 0;
    let totalIncome = 0;
    let totalObligations = 0;

    for (let i = 0; i < boundaries.length; i++) {
      const b = boundaries[i];
      const days = Math.max(1, differenceInCalendarDays(b.date, cursor));
      const segObligations = obligations
        .filter(o => isAfter(o.date, cursor) || isSameDay(o.date, cursor))
        .filter(o => !isAfter(o.date, b.date))
        .reduce((sum, o) => sum + Math.abs(o.amount), 0);

      const spendable = balance - reserve - segObligations;
      const dailyLimit = Math.max(0, spendable / days);
      const shortfall = spendable < 0;
      if (shortfall) gap = true;

      const endBalance = balance - segObligations - dailyLimit * days + b.income;
      const prevName = i > 0 ? boundaries[i - 1].name : null;
      const label =
        i === 0
          ? (b.name ? `До «${b.name}»` : 'До конца периода')
          : (b.name ? `«${prevName ?? '…'}» → «${b.name}»` : `«${prevName ?? '…'}» → конец периода`);

      segs.push({
        label,
        startDate: cursor,
        endDate: b.date,
        days,
        startBalance: balance,
        obligations: segObligations,
        incomeAtEnd: b.income,
        dailyLimit,
        endBalance,
        shortfall,
      });

      cumDays += days;
      cumObligations += segObligations;
      const feasibleBefore = startBalance + cumIncomeBefore - cumObligations - reserve;
      smoothed = Math.min(smoothed, feasibleBefore / cumDays);
      cumIncomeBefore += b.income;
      // Income that arrives exactly at the window's closing boundary belongs to
      // the *next* cycle, so it is not spendable inside this window.
      if (isBefore(b.date, to)) totalIncome += b.income;
      totalObligations += segObligations;

      balance = endBalance;
      cursor = b.date;
    }

    return {
      segments: segs,
      smoothedDaily: smoothed === Infinity ? 0 : Math.max(0, smoothed),
      hasCashGap: gap,
      totalIncome,
      totalObligations,
    };
  }

  // Project the balance forward to a future window start (custom ranges only),
  // assuming no discretionary spend before the window opens.
  let startBalance = currentBalance;
  if (isAfter(rangeStart, startOfToday)) {
    let projected = currentBalance;
    for (const e of incomeEvents) {
      if (isAfter(e.date, startOfToday) && !isAfter(e.date, rangeStart)) projected += e.amount;
    }
    for (const o of obligations) {
      if (isAfter(o.date, startOfToday) && !isAfter(o.date, rangeStart)) projected -= Math.abs(o.amount);
    }
    startBalance = projected;
  }

  const rangeWalk = walk(rangeStart, startBalance, horizonEnd);
  if (rangeWalk.segments.length === 0) return empty;

  // Headline "until next income" is always measured from today, even when the
  // selected window starts later.
  const headline = nextIncomeDate ? walk(startOfToday, currentBalance, nextIncomeDate) : null;
  const dailyUntilNextIncome =
    rangeStart.getTime() === startOfToday.getTime()
      ? rangeWalk.segments[0]?.dailyLimit ?? 0
      : headline?.segments[0]?.dailyLimit ?? 0;

  const next = incomeEvents[0];

  return {
    currentBalance,
    reserve,
    baseCurrency,
    segments: rangeWalk.segments,
    nextIncome: next
      ? {
          name: next.name,
          date: next.date,
          amount: next.amount,
          daysUntil: Math.max(0, differenceInCalendarDays(next.date, startOfToday)),
        }
      : null,
    dailyUntilNextIncome,
    smoothedDaily: rangeWalk.smoothedDaily,
    horizonEnd,
    range: {
      mode: rangeMode,
      label: RANGE_LABELS[rangeMode],
      startDate: rangeStart,
      endDate: horizonEnd,
      days: Math.max(1, differenceInCalendarDays(horizonEnd, rangeStart)),
      daysLeft: Math.max(0, differenceInCalendarDays(horizonEnd, startOfToday)),
      startBalance,
      totalIncome: rangeWalk.totalIncome,
      totalObligations: rangeWalk.totalObligations,
      smoothedDaily: rangeWalk.smoothedDaily,
    },
    hasCashGap: rangeWalk.hasCashGap,
    ok: true,
  };
}
