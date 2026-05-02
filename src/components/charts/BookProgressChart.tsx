/**
 * Book reading progression. X axis: dates from `progressHistory`,
 * Y: pages read so far. Shows a forecast line to the deadline (if any).
 */
import React, { useMemo } from 'react';
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
  ReferenceLine,
} from 'recharts';
import { format, parseISO, differenceInDays } from 'date-fns';
import { ru } from 'date-fns/locale';

export interface BookPoint {
  date: string;
  pages: number;
}

interface Props {
  points: BookPoint[];
  totalPages?: number;
  deadline?: string;
  height?: number;
}

export function BookProgressChart({
  points,
  totalPages,
  deadline,
  height = 240,
}: Props) {
  const sorted = useMemo(
    () =>
      [...points].sort(
        (a, b) => parseISO(a.date).getTime() - parseISO(b.date).getTime()
      ),
    [points]
  );

  if (sorted.length === 0) {
    return (
      <div
        className="flex items-center justify-center text-xs text-zinc-500 italic bg-stone-50 rounded-2xl border border-stone-200"
        style={{ height }}
      >
        Пока нет записей о чтении
      </div>
    );
  }

  const last = sorted.at(-1)!;
  const first = sorted[0];
  const days = Math.max(1, differenceInDays(parseISO(last.date), parseISO(first.date)));
  const pagesPerDay = days > 0 ? (last.pages - first.pages) / days : 0;

  let forecastDate: Date | null = null;
  if (totalPages && pagesPerDay > 0 && last.pages < totalPages) {
    const remaining = totalPages - last.pages;
    forecastDate = new Date(
      parseISO(last.date).getTime() + (remaining / pagesPerDay) * 86_400_000
    );
  }

  return (
    <div style={{ height }}>
      <ResponsiveContainer>
        <ComposedChart data={sorted}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
          <XAxis dataKey="date" stroke="#71717a" fontSize={10} />
          <YAxis
            stroke="#71717a"
            fontSize={10}
            domain={[0, totalPages ?? 'dataMax']}
          />
          <Tooltip
            labelFormatter={(v) =>
              format(parseISO(String(v)), 'dd MMM yyyy', { locale: ru })
            }
            formatter={(v: any) => [`${v} стр.`, 'Прочитано']}
          />
          <Legend wrapperStyle={{ fontSize: 11 }} />
          <Area
            type="monotone"
            dataKey="pages"
            stroke="#10b981"
            fill="#10b981"
            fillOpacity={0.3}
            name="Прочитано страниц"
          />
          {totalPages && (
            <ReferenceLine
              y={totalPages}
              stroke="#dc2626"
              strokeDasharray="3 3"
              label={{ value: 'Всего', fill: '#dc2626', fontSize: 10 }}
            />
          )}
          {deadline && (
            <ReferenceLine
              x={deadline}
              stroke="#0ea5e9"
              strokeDasharray="3 3"
              label={{ value: 'Дедлайн', fill: '#0ea5e9', fontSize: 10 }}
            />
          )}
          {forecastDate && (
            <ReferenceLine
              x={format(forecastDate, 'yyyy-MM-dd')}
              stroke="#f59e0b"
              strokeDasharray="3 3"
              label={{ value: 'Прогноз', fill: '#f59e0b', fontSize: 10 }}
            />
          )}
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  );
}
