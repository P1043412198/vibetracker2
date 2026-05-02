/**
 * Weekly velocity: created vs completed tasks per ISO-week. Helpful to see
 * whether you're outpacing your incoming workload or piling it up.
 */
import React from 'react';
import {
  BarChart,
  Bar,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ComposedChart,
} from 'recharts';

export interface VelocityPoint {
  week: string; // YYYY-Www
  created: number;
  completed: number;
}

interface Props {
  data: VelocityPoint[];
  height?: number;
}

export function TaskVelocityChart({ data, height = 280 }: Props) {
  if (data.length === 0) {
    return (
      <div
        className="flex items-center justify-center text-xs text-zinc-500 italic bg-stone-50 rounded-2xl border border-stone-200"
        style={{ height }}
      >
        Нет данных по задачам
      </div>
    );
  }
  return (
    <div style={{ height }}>
      <ResponsiveContainer>
        <ComposedChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
          <XAxis dataKey="week" stroke="#71717a" fontSize={10} />
          <YAxis stroke="#71717a" fontSize={10} />
          <Tooltip />
          <Legend wrapperStyle={{ fontSize: 11 }} />
          <Bar dataKey="created" fill="#94a3b8" name="Создано" />
          <Bar dataKey="completed" fill="#10b981" name="Закрыто" />
          <Line
            dataKey="completed"
            stroke="#0f766e"
            strokeWidth={2}
            dot={{ r: 2 }}
            type="monotone"
            name="Тренд закрытий"
          />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  );
}
