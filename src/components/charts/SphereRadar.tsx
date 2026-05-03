/**
 * Radar of attainment per "sphere" (i.e. per life-area) over the chosen
 * period.
 */
import React from 'react';
import {
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';

export interface SphereScore {
  sphere: string;
  /** 0..100 */
  score: number;
}

interface Props {
  data: SphereScore[];
  height?: number;
}

export function SphereRadar({ data, height = 280 }: Props) {
  if (data.length === 0) {
    return (
      <div
        className="flex items-center justify-center text-xs text-zinc-500 italic bg-stone-50 rounded-2xl border border-stone-200"
        style={{ height }}
      >
        Нет данных по сферам
      </div>
    );
  }
  return (
    <div style={{ height }}>
      <ResponsiveContainer>
        <RadarChart data={data} outerRadius="80%">
          <PolarGrid stroke="#e5e7eb" />
          <PolarAngleAxis
            dataKey="sphere"
            tick={{ fontSize: 10, fill: '#52525b' }}
          />
          <PolarRadiusAxis
            domain={[0, 100]}
            tick={{ fontSize: 9, fill: '#a1a1aa' }}
          />
          <Radar
            name="Прогресс"
            dataKey="score"
            stroke="#10b981"
            fill="#10b981"
            fillOpacity={0.4}
          />
          <Tooltip />
        </RadarChart>
      </ResponsiveContainer>
    </div>
  );
}
