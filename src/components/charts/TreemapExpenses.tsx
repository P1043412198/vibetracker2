/**
 * Treemap of expenses by category. The colour of each tile encodes how
 * the actual spend compares to the planned spend (`MonthlyBudgetPlan`):
 *   < 80%   → green (under budget)
 *   80-100% → emerald
 *   100-120%→ amber (over by a bit)
 *   > 120%  → red
 */
import React, { useMemo } from 'react';
import { ResponsiveTreeMap } from '@nivo/treemap';

export interface TreemapNode {
  category: string;
  value: number;
  /** Planned amount for that category, optional. */
  plan?: number;
}

interface Props {
  data: TreemapNode[];
  format?: (n: number) => string;
  height?: number;
}

function getColor(spent: number, plan?: number) {
  if (!plan || plan <= 0) return '#6b7280';
  const ratio = spent / plan;
  if (ratio < 0.8) return '#10b981';
  if (ratio < 1.0) return '#34d399';
  if (ratio < 1.2) return '#f59e0b';
  return '#dc2626';
}

export function TreemapExpenses({ data, format, height = 360 }: Props) {
  const tree = useMemo(
    () => ({
      name: 'expenses',
      children: data
        .filter((d) => d.value > 0)
        .map((d) => ({
          name: d.category,
          loc: d.value,
          plan: d.plan ?? 0,
          color: getColor(d.value, d.plan),
        })),
    }),
    [data]
  );

  if (tree.children.length === 0) {
    return (
      <div
        className="flex items-center justify-center text-xs text-zinc-500 italic bg-stone-50 rounded-2xl border border-stone-200"
        style={{ height }}
      >
        Нет расходов в выбранном периоде
      </div>
    );
  }

  return (
    <div style={{ height }}>
      <ResponsiveTreeMap
        data={tree as any}
        identity="name"
        value="loc"
        valueFormat={(v) => (format ? format(Number(v)) : String(v))}
        innerPadding={3}
        outerPadding={2}
        labelSkipSize={20}
        leavesOnly
        label={(node) => `${node.id}`}
        nodeOpacity={0.95}
        borderColor={{ from: 'color', modifiers: [['darker', 0.4]] }}
        colors={(node: any) => node.data.color ?? '#6b7280'}
        labelTextColor="#ffffff"
        animate={false}
      />
    </div>
  );
}
