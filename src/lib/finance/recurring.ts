import type { RegularPayment, RecurringFrequency, RecurringSkip, Transaction } from '../../types';

// All date math is done on plain YYYY-MM-DD strings in UTC to avoid timezone drift.

function pad(n: number): string {
  return n.toString().padStart(2, '0');
}

export function toISO(date: Date): string {
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`;
}

function parseISO(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(Date.UTC(y, (m || 1) - 1, d || 1));
}

function daysInMonth(year: number, month1: number): number {
  // month1 is 1-12
  return new Date(Date.UTC(year, month1, 0)).getUTCDate();
}

export function frequencyOf(rule: RegularPayment): RecurringFrequency {
  return rule.frequency || 'monthly';
}

/**
 * Most recent occurrence on or before `today` for a recurring rule.
 * Returns null if the rule has no occurrence at/before today (e.g. anchor in future).
 */
export function lastDueOccurrence(
  rule: RegularPayment,
  todayISO: string,
): { dateISO: string; periodKey: string } | null {
  const today = parseISO(todayISO);
  const freq = frequencyOf(rule);

  if (freq === 'monthly') {
    const y = today.getUTCFullYear();
    const m = today.getUTCMonth() + 1; // 1-12
    const day = Math.min(Math.max(rule.dueDate || 1, 1), daysInMonth(y, m));
    let occ = new Date(Date.UTC(y, m - 1, day));
    if (occ.getTime() > today.getTime()) {
      // This month's occurrence is still in the future → use previous month.
      const py = m === 1 ? y - 1 : y;
      const pm = m === 1 ? 12 : m - 1;
      const pday = Math.min(Math.max(rule.dueDate || 1, 1), daysInMonth(py, pm));
      occ = new Date(Date.UTC(py, pm - 1, pday));
    }
    const dateISO = toISO(occ);
    return { dateISO, periodKey: `${occ.getUTCFullYear()}-${pad(occ.getUTCMonth() + 1)}` };
  }

  if (freq === 'yearly') {
    const month1 = Math.min(Math.max(rule.month || 1, 1), 12);
    const y = today.getUTCFullYear();
    const day = Math.min(Math.max(rule.dueDate || 1, 1), daysInMonth(y, month1));
    let occ = new Date(Date.UTC(y, month1 - 1, day));
    if (occ.getTime() > today.getTime()) {
      const py = y - 1;
      const pday = Math.min(Math.max(rule.dueDate || 1, 1), daysInMonth(py, month1));
      occ = new Date(Date.UTC(py, month1 - 1, pday));
    }
    return { dateISO: toISO(occ), periodKey: `${occ.getUTCFullYear()}` };
  }

  if (freq === 'weekly') {
    const target = ((rule.weekday ?? today.getUTCDay()) % 7 + 7) % 7;
    const diff = (today.getUTCDay() - target + 7) % 7; // days since last target weekday
    const occ = new Date(today.getTime() - diff * 86400000);
    return { dateISO: toISO(occ), periodKey: toISO(occ) };
  }

  // biweekly: every 14 days anchored on anchorDate
  const anchorISO = rule.anchorDate;
  if (!anchorISO) return null;
  const anchor = parseISO(anchorISO);
  if (anchor.getTime() > today.getTime()) return null;
  const periods = Math.floor((today.getTime() - anchor.getTime()) / (14 * 86400000));
  const occ = new Date(anchor.getTime() + periods * 14 * 86400000);
  return { dateISO: toISO(occ), periodKey: toISO(occ) };
}

/**
 * Earliest occurrence on or after `today` for a recurring rule — the next
 * time the rule will come due. Returns null only when the cadence cannot be
 * resolved (it never does for the supported frequencies).
 */
export function nextDueOccurrence(
  rule: RegularPayment,
  todayISO: string,
): { dateISO: string; periodKey: string } | null {
  const today = parseISO(todayISO);
  const freq = frequencyOf(rule);

  if (freq === 'monthly') {
    const y = today.getUTCFullYear();
    const m = today.getUTCMonth() + 1;
    const day = Math.min(Math.max(rule.dueDate || 1, 1), daysInMonth(y, m));
    let occ = new Date(Date.UTC(y, m - 1, day));
    if (occ.getTime() < today.getTime()) {
      const ny = m === 12 ? y + 1 : y;
      const nm = m === 12 ? 1 : m + 1;
      const nday = Math.min(Math.max(rule.dueDate || 1, 1), daysInMonth(ny, nm));
      occ = new Date(Date.UTC(ny, nm - 1, nday));
    }
    return { dateISO: toISO(occ), periodKey: `${occ.getUTCFullYear()}-${pad(occ.getUTCMonth() + 1)}` };
  }

  if (freq === 'yearly') {
    const month1 = Math.min(Math.max(rule.month || 1, 1), 12);
    const y = today.getUTCFullYear();
    const day = Math.min(Math.max(rule.dueDate || 1, 1), daysInMonth(y, month1));
    let occ = new Date(Date.UTC(y, month1 - 1, day));
    if (occ.getTime() < today.getTime()) {
      const ny = y + 1;
      const nday = Math.min(Math.max(rule.dueDate || 1, 1), daysInMonth(ny, month1));
      occ = new Date(Date.UTC(ny, month1 - 1, nday));
    }
    return { dateISO: toISO(occ), periodKey: `${occ.getUTCFullYear()}` };
  }

  if (freq === 'weekly') {
    const target = ((rule.weekday ?? today.getUTCDay()) % 7 + 7) % 7;
    const diff = (target - today.getUTCDay() + 7) % 7; // days until next target weekday
    const occ = new Date(today.getTime() + diff * 86400000);
    return { dateISO: toISO(occ), periodKey: toISO(occ) };
  }

  // biweekly: every 14 days anchored on anchorDate
  const anchorISO = rule.anchorDate;
  if (!anchorISO) return null;
  const anchor = parseISO(anchorISO);
  if (anchor.getTime() >= today.getTime()) {
    return { dateISO: toISO(anchor), periodKey: toISO(anchor) };
  }
  const periods = Math.ceil((today.getTime() - anchor.getTime()) / (14 * 86400000));
  const occ = new Date(anchor.getTime() + periods * 14 * 86400000);
  return { dateISO: toISO(occ), periodKey: toISO(occ) };
}

export function refFor(ruleId: string, periodKey: string): string {
  return `${ruleId}:${periodKey}`;
}

export function isOccurrencePosted(
  transactions: Transaction[],
  ruleId: string,
  periodKey: string,
): boolean {
  const ref = refFor(ruleId, periodKey);
  return transactions.some((t) => t.recurringRef === ref);
}

export type DueRecurring = {
  rule: RegularPayment;
  periodKey: string;
  dateISO: string;
  ref: string;
};

/**
 * Active recurring rules whose latest occurrence is due (on/before today),
 * not yet posted, and not skipped — i.e. awaiting the user's confirmation.
 */
export function getDueRecurring(
  rules: RegularPayment[],
  transactions: Transaction[],
  skips: RecurringSkip[],
  todayISO: string,
): DueRecurring[] {
  const skipSet = new Set(skips.map((s) => refFor(s.ruleId, s.periodKey)));
  const out: DueRecurring[] = [];
  for (const rule of rules) {
    if (!rule.isActive) continue;
    const occ = lastDueOccurrence(rule, todayISO);
    if (!occ) continue;
    const ref = refFor(rule.id, occ.periodKey);
    if (skipSet.has(ref)) continue;
    if (isOccurrencePosted(transactions, rule.id, occ.periodKey)) continue;
    out.push({ rule, periodKey: occ.periodKey, dateISO: occ.dateISO, ref });
  }
  // Earliest due first.
  out.sort((a, b) => a.dateISO.localeCompare(b.dateISO));
  return out;
}
