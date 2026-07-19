import type { Currency, Loan, RegularPayment } from '../../types';
import { nextDueOccurrence, toISO } from './recurring';

export type ReminderKind = 'recurring' | 'loan';

export type Reminder = {
  /** Stable key `kind:sourceId:periodKey` — used for acknowledge tracking. */
  id: string;
  kind: ReminderKind;
  sourceId: string;
  periodKey: string;
  name: string;
  amount: number;
  currency: Currency;
  type: 'income' | 'expense';
  dueISO: string;
  daysUntil: number;
};

function daysBetween(fromISO: string, toISOStr: string): number {
  const [fy, fm, fd] = fromISO.split('-').map(Number);
  const [ty, tm, td] = toISOStr.split('-').map(Number);
  const a = Date.UTC(fy, (fm || 1) - 1, fd || 1);
  const b = Date.UTC(ty, (tm || 1) - 1, td || 1);
  return Math.round((b - a) / 86400000);
}

/** Total principal repaid so far (ignores withdrawals). */
function loanPaid(loan: Loan): number {
  return (loan.payments || [])
    .filter((p) => p.type === 'payment')
    .reduce((sum, p) => sum + p.amount, 0);
}

/** Next monthly-payment due date for a loan (paymentDay, default 5). */
function loanNextDue(loan: Loan, todayISO: string): string {
  const [y, m, d] = todayISO.split('-').map(Number);
  const day = Math.min(Math.max(loan.paymentDay || 5, 1), 28);
  let occ = Date.UTC(y, m - 1, day);
  if (occ < Date.UTC(y, m - 1, d)) {
    occ = Date.UTC(m === 12 ? y + 1 : y, m === 12 ? 0 : m, day);
  }
  return toISO(new Date(occ));
}

/**
 * Upcoming payment reminders within `windowDays`, drawn from active recurring
 * rules (subscriptions/bills) and not-yet-repaid loans. Sorted soonest-first.
 * `recurring` rules flagged `autoConfirm` are excluded — they post silently and
 * don't need a nudge.
 */
export function getUpcomingReminders(
  rules: RegularPayment[],
  loans: Loan[],
  todayISO: string,
  windowDays = 7,
): Reminder[] {
  const out: Reminder[] = [];

  for (const rule of rules) {
    if (!rule.isActive || rule.autoConfirm) continue;
    const occ = nextDueOccurrence(rule, todayISO);
    if (!occ) continue;
    const daysUntil = daysBetween(todayISO, occ.dateISO);
    if (daysUntil < 0 || daysUntil > windowDays) continue;
    out.push({
      id: `recurring:${rule.id}:${occ.periodKey}`,
      kind: 'recurring',
      sourceId: rule.id,
      periodKey: occ.periodKey,
      name: rule.name,
      amount: rule.amount,
      currency: rule.currency || 'BYN',
      type: rule.type === 'income' ? 'income' : 'expense',
      dueISO: occ.dateISO,
      daysUntil,
    });
  }

  for (const loan of loans) {
    if (loanPaid(loan) >= loan.totalPayment) continue; // fully repaid
    if (!(loan.monthlyPayment > 0)) continue;
    const dueISO = loanNextDue(loan, todayISO);
    const daysUntil = daysBetween(todayISO, dueISO);
    if (daysUntil < 0 || daysUntil > windowDays) continue;
    const periodKey = dueISO.slice(0, 7);
    out.push({
      id: `loan:${loan.id}:${periodKey}`,
      kind: 'loan',
      sourceId: loan.id,
      periodKey,
      name: loan.name,
      amount: loan.monthlyPayment,
      currency: loan.currency || 'BYN',
      type: 'expense',
      dueISO,
      daysUntil,
    });
  }

  out.sort((a, b) => a.dueISO.localeCompare(b.dueISO) || a.name.localeCompare(b.name));
  return out;
}
