import { describe, it, expect, beforeEach } from 'vitest';
import {
  createMonthlyBudgetActions,
  monthlyBudgetInitialState,
  type MonthlyBudgetState,
  type MonthlyBudgetActions,
} from '../monthlyBudgetSlice';

function harness() {
  let state: MonthlyBudgetState = { ...monthlyBudgetInitialState };
  const set = (
    partial:
      | Partial<MonthlyBudgetState>
      | ((s: MonthlyBudgetState) => Partial<MonthlyBudgetState>)
  ) => {
    const next = typeof partial === 'function' ? partial(state) : partial;
    state = { ...state, ...next };
  };
  const get = () => state;
  const actions: MonthlyBudgetActions = createMonthlyBudgetActions(set, get);
  return { actions, getState: () => state };
}

describe('monthlyBudgetSlice', () => {
  let env: ReturnType<typeof harness>;

  beforeEach(() => { env = harness(); });

  it('creates a brand new plan with id/createdAt/updatedAt', () => {
    env.actions.saveMonthlyBudgetPlan({
      monthKey: '2026-05',
      plannedIncome: 1000,
      categoryPlans: [{ category: 'Food', planned: 300 }],
    });
    const plans = env.getState().monthlyBudgetPlans;
    expect(plans).toHaveLength(1);
    expect(plans[0].id).toBeTruthy();
    expect(plans[0].createdAt).toBeTruthy();
    expect(plans[0].updatedAt).toBeTruthy();
    expect(plans[0].plannedIncome).toBe(1000);
  });

  it('updates an existing plan when called twice for the same month', () => {
    env.actions.saveMonthlyBudgetPlan({
      monthKey: '2026-05', plannedIncome: 1000, categoryPlans: [],
    });
    const firstId = env.getState().monthlyBudgetPlans[0].id;
    env.actions.saveMonthlyBudgetPlan({
      monthKey: '2026-05', plannedIncome: 2000, categoryPlans: [],
    });
    const plans = env.getState().monthlyBudgetPlans;
    expect(plans).toHaveLength(1);
    expect(plans[0].id).toBe(firstId);
    expect(plans[0].plannedIncome).toBe(2000);
  });

  it('keeps separate plans for different months', () => {
    env.actions.saveMonthlyBudgetPlan({ monthKey: '2026-05', plannedIncome: 1000, categoryPlans: [] });
    env.actions.saveMonthlyBudgetPlan({ monthKey: '2026-06', plannedIncome: 1500, categoryPlans: [] });
    expect(env.getState().monthlyBudgetPlans).toHaveLength(2);
  });

  it('deletes a plan by id', () => {
    env.actions.saveMonthlyBudgetPlan({ monthKey: '2026-05', plannedIncome: 1000, categoryPlans: [] });
    const id = env.getState().monthlyBudgetPlans[0].id;
    env.actions.deleteMonthlyBudgetPlan(id);
    expect(env.getState().monthlyBudgetPlans).toHaveLength(0);
  });

  it('looks up a plan by month key', () => {
    env.actions.saveMonthlyBudgetPlan({
      monthKey: '2026-05', plannedIncome: 1000, categoryPlans: [],
    });
    expect(env.actions.getMonthlyBudgetPlan('2026-05')).toBeTruthy();
    expect(env.actions.getMonthlyBudgetPlan('2026-06')).toBeUndefined();
  });

  it('preserves rollover and currency fields across save', () => {
    env.actions.saveMonthlyBudgetPlan({
      monthKey: '2026-05', plannedIncome: 1000, categoryPlans: [],
      currency: 'USD', rollover: true, notes: 'vacation',
    });
    const p = env.actions.getMonthlyBudgetPlan('2026-05');
    expect(p?.currency).toBe('USD');
    expect(p?.rollover).toBe(true);
    expect(p?.notes).toBe('vacation');
  });
});
