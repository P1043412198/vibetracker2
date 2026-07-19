import { describe, it, expect } from 'vitest';
import { getUpcomingReminders } from '../reminders';
import { nextDueOccurrence } from '../recurring';
import type { Loan, RegularPayment } from '../../../types';

function rule(overrides: Partial<RegularPayment> = {}): RegularPayment {
  return {
    id: 'r1',
    name: 'Netflix',
    amount: 15,
    dueDate: 1,
    category: 'Подписки',
    isActive: true,
    type: 'expense',
    frequency: 'monthly',
    ...overrides,
  };
}

function loan(overrides: Partial<Loan> = {}): Loan {
  return {
    id: 'l1',
    name: 'Авто',
    amount: 10000,
    rate: 10,
    termMonths: 24,
    monthlyPayment: 500,
    totalPayment: 12000,
    overpayment: 2000,
    createdAt: '2026-01-01',
    paymentDay: 10,
    ...overrides,
  };
}

describe('nextDueOccurrence', () => {
  it('monthly: returns this month when due day ahead', () => {
    const occ = nextDueOccurrence(rule({ frequency: 'monthly', dueDate: 20 }), '2026-06-10');
    expect(occ).toEqual({ dateISO: '2026-06-20', periodKey: '2026-06' });
  });

  it('monthly: rolls to next month when due day passed', () => {
    const occ = nextDueOccurrence(rule({ frequency: 'monthly', dueDate: 5 }), '2026-06-10');
    expect(occ).toEqual({ dateISO: '2026-07-05', periodKey: '2026-07' });
  });

  it('weekly: returns next matching weekday', () => {
    // 2026-06-26 is Friday (getUTCDay 5); next Monday (1) is 2026-06-29.
    const occ = nextDueOccurrence(rule({ frequency: 'weekly', weekday: 1 }), '2026-06-26');
    expect(occ?.dateISO).toBe('2026-06-29');
  });

  it('yearly: rolls into next year when month passed', () => {
    const occ = nextDueOccurrence(rule({ frequency: 'yearly', month: 1, dueDate: 15 }), '2026-06-26');
    expect(occ).toEqual({ dateISO: '2027-01-15', periodKey: '2027' });
  });

  it('biweekly: lands on next cadence from anchor', () => {
    const occ = nextDueOccurrence(rule({ frequency: 'biweekly', anchorDate: '2026-06-01' }), '2026-06-10');
    expect(occ?.dateISO).toBe('2026-06-15');
  });
});

describe('getUpcomingReminders', () => {
  const today = '2026-06-26';

  it('includes a recurring rule due within the window', () => {
    const out = getUpcomingReminders([rule({ dueDate: 30 })], [], today, 7);
    expect(out).toHaveLength(1);
    expect(out[0].id).toBe('recurring:r1:2026-06');
    expect(out[0].daysUntil).toBe(4);
  });

  it('excludes rules due beyond the window', () => {
    const out = getUpcomingReminders([rule({ dueDate: 20 })], [], today, 7);
    expect(out).toHaveLength(0); // next due 2026-07-20, >7 days
  });

  it('excludes autoConfirm rules (they post silently)', () => {
    const out = getUpcomingReminders([rule({ dueDate: 30, autoConfirm: true })], [], today, 7);
    expect(out).toHaveLength(0);
  });

  it('excludes inactive rules', () => {
    const out = getUpcomingReminders([rule({ dueDate: 30, isActive: false })], [], today, 7);
    expect(out).toHaveLength(0);
  });

  it('includes a loan instalment due within the window', () => {
    const out = getUpcomingReminders([], [loan({ paymentDay: 28 })], today, 7);
    expect(out).toHaveLength(1);
    expect(out[0].kind).toBe('loan');
    expect(out[0].amount).toBe(500);
    expect(out[0].dueISO).toBe('2026-06-28');
  });

  it('excludes fully-repaid loans', () => {
    const paid = loan({
      paymentDay: 28,
      totalPayment: 1000,
      payments: [{ id: 'p', date: '2026-06-01', amount: 1000, type: 'payment' }],
    });
    const out = getUpcomingReminders([], [paid], today, 7);
    expect(out).toHaveLength(0);
  });

  it('sorts soonest-first across sources', () => {
    const out = getUpcomingReminders(
      [rule({ id: 'late', dueDate: 30 })],
      [loan({ id: 'early', paymentDay: 27 })],
      today,
      7,
    );
    expect(out.map((r) => r.sourceId)).toEqual(['early', 'late']);
  });
});
