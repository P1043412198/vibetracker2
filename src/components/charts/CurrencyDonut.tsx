/**
 * Donut showing how net worth (or any portfolio) splits across currencies.
 */
import React from 'react';
import { PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer } from 'recharts';

interface Props {
  exposure: { currency: string; share: number; baseValue: number }[];
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

export function CurrencyDonut({ exposure, format, height = 240 }: Props) {
  const data = exposure.filter((e) => e.baseValue > 0);
  if (data.length === 0) {
    return (
      <div
        className="flex items-center justify-center text-xs text-zinc-500 italic bg-stone-50 rounded-2xl border border-stone-200"
        style={{ height }}
      >
        Нет данных
      </div>
    );
  }
  return (
    <div style={{ height }}>
      <ResponsiveContainer>
        <PieChart>
          <Pie
            data={data}
            dataKey="baseValue"
            nameKey="currency"
            cx="50%"
            cy="50%"
            innerRadius="55%"
            outerRadius="85%"
            paddingAngle={2}
          >
            {data.map((d) => (
              <Cell
                key={d.currency}
                fill={COLORS[d.currency] ?? '#6b7280'}
              />
            ))}
          </Pie>
          <Tooltip
            formatter={(v: any, _n, payload) => {
              const share = payload?.payload?.share;
              const fmt = format ? format(Number(v)) : String(v);
              const pct =
                typeof share === 'number'
                  ? ` (${(share * 100).toFixed(0)}%)`
                  : '';
              return `${fmt}${pct}`;
            }}
          />
          <Legend wrapperStyle={{ fontSize: 11 }} />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
}
