/**
 * Net worth over time. Stacked area by currency, with debts shown as a
 * negative band at the bottom and a single "net" line on top.
 */
import React from 'react';
import {
  AreaChart,
  Area,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ComposedChart,
} from 'recharts';

export interface NetWorthPoint {
  date: string; // ISO YYYY-MM
  /** Sum of assets per currency (in base currency). */
  byCurrency: Record<string, number>;
  /** Total liabilities (positive number, subtracted from net). */
  liabilities: number;
}

interface Props {
  points: NetWorthPoint[];
  format?: (n: number) => string;
  height?: number;
}

const COLORS: Record<string, string> = {
  BYN: '#10b981',
  USD: '#3b82f6',
  EUR: '#6366f1',
  RUB: '#f59e0b',
  PLN: '#a855f7',
  USDT: '#06b6d4',
  CNY: '#dc2626',
};

export function NetWorthChart({ points, format, height = 320 }: Props) {
  const currencies = Array.from(
    new Set(points.flatMap((p) => Object.keys(p.byCurrency)))
  );

  const data = points.map((p) => {
    const total = currencies.reduce((s, c) => s + (p.byCurrency[c] ?? 0), 0);
    return {
      date: p.date,
      ...currencies.reduce<Record<string, number>>((acc, c) => {
        acc[c] = p.byCurrency[c] ?? 0;
        return acc;
      }, {}),
      liabilities: -p.liabilities,
      net: total - p.liabilities,
    };
  });

  if (data.length === 0) {
    return (
      <div
        className="flex items-center justify-center text-xs text-zinc-500 italic bg-stone-50 rounded-2xl border border-stone-200"
        style={{ height }}
      >
        Нет данных для расчёта чистой стоимости
      </div>
    );
  }

  return (
    <div style={{ height }}>
      <ResponsiveContainer>
        <ComposedChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
          <XAxis dataKey="date" stroke="#71717a" fontSize={10} />
          <YAxis
            stroke="#71717a"
            fontSize={10}
            tickFormatter={(v) => (format ? format(Number(v)) : String(v))}
          />
          <Tooltip
            formatter={(v: any) =>
              format ? format(Number(v)) : String(v)
            }
          />
          <Legend wrapperStyle={{ fontSize: 11 }} />
          {currencies.map((c) => (
            <Area
              key={c}
              dataKey={c}
              stackId="assets"
              stroke={COLORS[c] ?? '#6b7280'}
              fill={COLORS[c] ?? '#6b7280'}
              fillOpacity={0.6}
            />
          ))}
          <Area
            dataKey="liabilities"
            stackId="liab"
            stroke="#dc2626"
            fill="#dc2626"
            fillOpacity={0.4}
            name="Долги"
          />
          <Line
            dataKey="net"
            stroke="#0f172a"
            strokeWidth={2}
            dot={{ r: 2 }}
            name="Net Worth"
          />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  );
}
