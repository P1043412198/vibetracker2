/**
 * Polar histogram of WHEN habits are usually checked off.
 * X axis = hour of day (0..23), radius = number of logs at that hour.
 */
import React, { useMemo } from 'react';
import {
  ResponsiveContainer,
  RadialBarChart,
  RadialBar,
  PolarAngleAxis,
  Tooltip,
} from 'recharts';

interface Props {
  /** Array of timestamps (ISO) of when logs were created. */
  timestamps: string[];
  height?: number;
}

export function HabitClock({ timestamps, height = 240 }: Props) {
  const data = useMemo(() => {
    const buckets = Array.from({ length: 24 }, (_, h) => ({
      hour: h,
      count: 0,
      label: `${String(h).padStart(2, '0')}:00`,
    }));
    for (const t of timestamps) {
      const d = new Date(t);
      if (Number.isNaN(d.getTime())) continue;
      buckets[d.getHours()].count++;
    }
    return buckets;
  }, [timestamps]);

  const total = data.reduce((s, b) => s + b.count, 0);
  if (total === 0) {
    return (
      <div
        className="flex items-center justify-center text-xs text-zinc-500 italic bg-stone-50 rounded-2xl border border-stone-200"
        style={{ height }}
      >
        Пока нет отметок для распределения по часам
      </div>
    );
  }

  return (
    <div style={{ height }}>
      <ResponsiveContainer>
        <RadialBarChart
          innerRadius="20%"
          outerRadius="100%"
          data={data}
          startAngle={90}
          endAngle={-270}
        >
          <PolarAngleAxis
            type="category"
            dataKey="label"
            tick={{ fontSize: 9, fill: '#71717a' }}
            tickFormatter={(v: string) =>
              ['00:00', '06:00', '12:00', '18:00'].includes(v) ? v : ''
            }
          />
          <RadialBar dataKey="count" fill="#6366f1" />
          <Tooltip
            formatter={(v: any, _n, payload: any) =>
              `${v} раз в ${payload?.payload?.label}`
            }
          />
        </RadialBarChart>
      </ResponsiveContainer>
    </div>
  );
}
