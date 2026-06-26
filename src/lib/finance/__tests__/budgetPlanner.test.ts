import { describe, expect, it } from 'vitest';
import { computeBudgetCycles } from '../budgetPlanner';
import type { IncomeSource, PlannedExpense, ActualExpense } from '../../../types';

function income(partial: Partial<IncomeSource> & Pick<IncomeSource, 'type' | 'amount'>): IncomeSource {
  return {
    id: partial.id ?? `${partial.type}-1`,
    name: partial.name ?? partial.type,
    type: partial.type,
    amount: partial.amount,
    dayOfMonth: partial.dayOfMonth,
    adjustForHolidays: partial.adjustForHolidays ?? false,
    isActive: partial.isActive ?? true,
    createdAt: '2025-01-01',
  };
}

function paid(id: string, amount: number, paidAmount: number | undefined, paidDate: string): PlannedExpense {
  return {
    id,
    name: id,
    amount,
    dayFrom: 1,
    dayTo: 28,
    isPaid: true,
    paidDate,
    paidAmount,
    isActive: true,
    createdAt: '2025-01-01',
  };
}

describe('computeBudgetCycles — paid-expense accumulation (bug #1)', () => {
  // Salary on the 5th, advance on the 20th of June 2025 → a deterministic cycle.
  const today = new Date(2025, 5, 1);
  const incomeSources = [
    income({ type: 'salary', amount: 2000, dayOfMonth: 5 }),
    income({ type: 'advance', amount: 1000, dayOfMonth: 20 }),
  ];

  it('sums every paid expense in the window rather than keeping only the last', () => {
    const plannedExpenses: PlannedExpense[] = [
      paid('rent', 500, undefined, '2025-06-06'),
      paid('food', 300, undefined, '2025-06-10'),
      paid('phone', 50, 60, '2025-06-12'), // paidAmount overrides amount
    ];
    const actualExpenses: ActualExpense[] = [];

    const cycles = computeBudgetCycles({
      incomeSources,
      plannedExpenses,
      actualExpenses,
      today,
    });

    const salaryToAdvance = cycles.find((c) => c.label === 'От зарплаты до аванса');
    expect(salaryToAdvance).toBeDefined();
    // 500 + 300 + 60 = 860 — the pre-fix bug returned only the last item (60).
    expect(salaryToAdvance!.actualSpent).toBeCloseTo(860, 6);
    expect(salaryToAdvance!.remainingBudget).toBeCloseTo(2000 - 860, 6);
  });

  it('returns 0 spent when no expenses are paid', () => {
    const cycles = computeBudgetCycles({
      incomeSources,
      plannedExpenses: [],
      actualExpenses: [],
      today,
    });
    const salaryToAdvance = cycles.find((c) => c.label === 'От зарплаты до аванса');
    expect(salaryToAdvance!.actualSpent).toBe(0);
  });
});
