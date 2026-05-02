/**
 * Income → Expense Sankey diagram. Wraps `@nivo/sankey` so consumers
 * deal in plain category names + amounts.
 */
import React, { useMemo } from 'react';
import { ResponsiveSankey } from '@nivo/sankey';

export interface FlowItem {
  source: string;
  target: string;
  value: number;
}

interface Props {
  flows: FlowItem[];
  /** Format function for tooltip values (e.g. currency formatter). */
  format?: (n: number) => string;
  height?: number;
}

export function SankeyFlow({ flows, format, height = 360 }: Props) {
  const data = useMemo(() => {
    const nodeIds = new Set<string>();
    for (const f of flows) {
      if (f.value <= 0) continue;
      nodeIds.add(f.source);
      nodeIds.add(f.target);
    }
    return {
      nodes: Array.from(nodeIds).map((id) => ({ id })),
      links: flows
        .filter((f) => f.value > 0)
        .map((f) => ({ source: f.source, target: f.target, value: f.value })),
    };
  }, [flows]);

  if (data.links.length === 0) {
    return (
      <div
        className="flex items-center justify-center text-xs text-zinc-500 italic bg-stone-50 rounded-2xl border border-stone-200"
        style={{ height }}
      >
        Пока нет данных для потока «Доходы → Расходы»
      </div>
    );
  }

  return (
    <div style={{ height }}>
      <ResponsiveSankey
        data={data}
        margin={{ top: 8, right: 120, bottom: 8, left: 120 }}
        align="justify"
        colors={{ scheme: 'category10' }}
        nodeOpacity={1}
        nodeThickness={14}
        nodeBorderWidth={0}
        nodeBorderRadius={3}
        linkOpacity={0.5}
        linkContract={3}
        enableLinkGradient
        labelPosition="outside"
        labelOrientation="horizontal"
        labelPadding={6}
        labelTextColor={{ from: 'color', modifiers: [['darker', 1.4]] }}
        valueFormat={(v) => (format ? format(Number(v)) : String(v))}
        animate={false}
      />
    </div>
  );
}
