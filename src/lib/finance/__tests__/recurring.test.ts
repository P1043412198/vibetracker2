import { describe, it, expect } from 'vitest';
import { lastDueOccurrence, getDueRecurring, refFor, isOccurrencePosted } from '../recurring';
import type { RegularPayment, Transaction } from '../../../types';

function rule(overrides: Partial<RegularPayment>): RegularPayment {
  return {
    id: 'r1',
    name: 'Test',
    amount: 10,
    dueDate: 1,
    category: 'Связь',
    isActive: true,
    ...overrides,
  };
}

describe('lastDueOccurrence', () => {
  it('monthly: returns this month when due day already passed', () => {
    const occ = lastDueOccurrence(rule({ frequency: 'monthly', dueDate: 10 }), '2026-06-20');
    expect(occ).toEqual({ dateISO: '2026-06-10', periodKey: '2026-06' });
  });

  it('monthly: falls back to previous month when due day is still ahead', () => {
    const occ = lastDueOccurrence(rule({ frequency: 'monthly', dueDate: 25 }), '2026-06-10');
    expect(occ).toEqual({ dateISO: '2026-05-25', periodKey: '2026-05' });
  });

  it('monthly: clamps day 31 to the last day of a short month', () => {
    const occ = lastDueOccurrence(rule({ frequency: 'monthly', dueDate: 31 }), '2026-02-28');
    expect(occ).toEqual({ dateISO: '2026-02-28', periodKey: '2026-02' });
  });

  it('monthly: defaults frequency to monthly when omitted', () => {
    const occ = lastDueOccurrence(rule({ dueDate: 5 }), '2026-06-06');
    expect(occ).toEqual({ dateISO: '2026-06-05', periodKey: '2026-06' });
  });

  it('weekly: returns the most recent matching weekday', () => {
    // 2026-06-26 is a Friday (day 5). Target Wednesday (3) → 2026-06-24.
    const occ = lastDueOccurrence(rule({ frequency: 'weekly', weekday: 3 }), '2026-06-26');
    expect(occ).toEqual({ dateISO: '2026-06-24', periodKey: '2026-06-24' });
  });

  it('weekly: returns today when weekday matches today', () => {
    const occ = lastDueOccurrence(rule({ frequency: 'weekly', weekday: 5 }), '2026-06-26');
    expect(occ).toEqual({ dateISO: '2026-06-26', periodKey: '2026-06-26' });
  });

  it('biweekly: lands on the cadence from the anchor', () => {
    const occ = lastDueOccurrence(
      rule({ frequency: 'biweekly', anchorDate: '2026-06-01' }),
      '2026-06-20',
    );
    // 2026-06-01 + 14 days = 2026-06-15 (next is 06-29, in the future)
    expect(occ).toEqual({ dateISO: '2026-06-15', periodKey: '2026-06-15' });
  });

  it('biweekly: returns null when anchor is in the future', () => {
    const occ = lastDueOccurrence(
      rule({ frequency: 'biweekly', anchorDate: '2026-07-01' }),
      '2026-06-20',
    );
    expect(occ).toBeNull();
  });

  it('yearly: uses month + day and falls back across the year boundary', () => {
    const occ = lastDueOccurrence(
      rule({ frequency: 'yearly', month: 12, dueDate: 31 }),
      '2026-06-26',
    );
    expect(occ).toEqual({ dateISO: '2025-12-31', periodKey: '2025' });
  });
});

describe('getDueRecurring', () => {
  const today = '2026-06-26';

  it('surfaces an active due rule that has not been posted or skipped', () => {
    const rules = [rule({ id: 'rent', frequency: 'monthly', dueDate: 5 })];
    const due = getDueRecurring(rules, [], [], today);
    expect(due).toHaveLength(1);
    expect(due[0].ref).toBe(refFor('rent', '2026-06'));
    expect(due[0].dateISO).toBe('2026-06-05');
  });

  it('skips inactive rules', () => {
    const rules = [rule({ id: 'rent', isActive: false })];
    expect(getDueRecurring(rules, [], [], today)).toHaveLength(0);
  });

  it('excludes occurrences already posted as transactions', () => {
    const rules = [rule({ id: 'rent', frequency: 'monthly', dueDate: 5 })];
    const txns: Transaction[] = [
      { id: 't1', type: 'expense', amount: 10, category: 'Связь', date: '2026-06-05', recurringRef: refFor('rent', '2026-06') },
    ];
    expect(getDueRecurring(rules, txns, [], today)).toHaveLength(0);
  });

  it('excludes occurrences the user skipped', () => {
    const rules = [rule({ id: 'rent', frequency: 'monthly', dueDate: 5 })];
    const skips = [{ ruleId: 'rent', periodKey: '2026-06' }];
    expect(getDueRecurring(rules, [], skips, today)).toHaveLength(0);
  });

  it('sorts due items by date ascending', () => {
    const rules = [
      rule({ id: 'late', frequency: 'monthly', dueDate: 20 }),
      rule({ id: 'early', frequency: 'monthly', dueDate: 3 }),
    ];
    const due = getDueRecurring(rules, [], [], today);
    expect(due.map((d) => d.rule.id)).toEqual(['early', 'late']);
  });
});

describe('isOccurrencePosted', () => {
  it('matches by recurringRef', () => {
    const txns: Transaction[] = [
      { id: 't1', type: 'expense', amount: 10, category: 'x', date: '2026-06-05', recurringRef: 'rent:2026-06' },
    ];
    expect(isOccurrencePosted(txns, 'rent', '2026-06')).toBe(true);
    expect(isOccurrencePosted(txns, 'rent', '2026-07')).toBe(false);
  });
});
