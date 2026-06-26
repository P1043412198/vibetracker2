/**
 * Budget planner utilities.
 *
 * Computes actual pay dates for salary/advance considering Belarus weekends
 * and public holidays, and calculates daily/weekly allowances between pay cycles.
 */
import { getDaysInMonth, isWeekend, format, addDays, differenceInCalendarDays, isBefore, isAfter, isSameDay } from 'date-fns';
import { isBYHoliday } from '../belarus/holidays';
import type { IncomeSource, PlannedExpense, ActualExpense } from '../../types';

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
