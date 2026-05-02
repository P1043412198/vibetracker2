import { v4 as uuidv4 } from 'uuid';
import type { MonthlyBudgetPlan } from '../../types';

/**
 * Slice with the per-month budget plan state and actions, factored out of
 * `useStore.ts`. Plug into the main store by spreading into `create()`.
 *
 * Kept dependency-light (no Zustand imports) so it can be unit-tested by
 * passing a fake `set`/`get`.
 */

export type MonthlyBudgetState = {
  monthlyBudgetPlans: MonthlyBudgetPlan[];
};

export type MonthlyBudgetActions = {
  saveMonthlyBudgetPlan: (
    plan: Omit<MonthlyBudgetPlan, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }
  ) => void;
  deleteMonthlyBudgetPlan: (id: string) => void;
  getMonthlyBudgetPlan: (monthKey: string) => MonthlyBudgetPlan | undefined;
};

export const monthlyBudgetInitialState: MonthlyBudgetState = {
  monthlyBudgetPlans: [],
};

type SetFn = (
  partial:
    | Partial<MonthlyBudgetState>
    | ((state: MonthlyBudgetState) => Partial<MonthlyBudgetState>)
) => void;

type GetFn = () => MonthlyBudgetState;

export function createMonthlyBudgetActions(set: SetFn, get: GetFn): MonthlyBudgetActions {
  return {
    saveMonthlyBudgetPlan: (plan) => set((state) => {
      const now = new Date().toISOString();
      const plans = state.monthlyBudgetPlans || [];
      const existing = plan.id
        ? plans.find(p => p.id === plan.id)
        : plans.find(p => p.monthKey === plan.monthKey);
      if (existing) {
        return {
          monthlyBudgetPlans: plans.map(p => p.id === existing.id
            ? { ...existing, ...plan, id: existing.id, createdAt: existing.createdAt, updatedAt: now }
            : p),
        };
      }
      return {
        monthlyBudgetPlans: [
          ...plans,
          {
            ...plan,
            id: uuidv4(),
            createdAt: now,
            updatedAt: now,
          } as MonthlyBudgetPlan,
        ],
      };
    }),

    deleteMonthlyBudgetPlan: (id) => set((state) => ({
      monthlyBudgetPlans: (state.monthlyBudgetPlans || []).filter(p => p.id !== id),
    })),

    getMonthlyBudgetPlan: (monthKey) =>
      (get().monthlyBudgetPlans || []).find(p => p.monthKey === monthKey),
  };
}
