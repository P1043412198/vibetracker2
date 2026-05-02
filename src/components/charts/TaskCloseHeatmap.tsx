/**
 * Heatmap day-of-week × hour for when tasks are typically completed.
 * Highlights "your peak productive hours".
 */
import React, { useMemo } from 'react';
import { cn } from '../../lib/utils';

interface Props {
  timestamps: string[];
  height?: number;
}

const DAY_LABELS = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

export function TaskCloseHeatmap({ timestamps }: Props) {
  const matrix = useMemo(() => {
    const m = Array.from({ length: 7 }, () =>
      Array.from({ length: 24 }, () => 0)
    );
    let max = 0;
    for (const t of timestamps) {
      const d = new Date(t);
      if (Number.isNaN(d.getTime())) continue;
      const day = (d.getDay() + 6) % 7; // Mon = 0
      const hour = d.getHours();
      m[day][hour]++;
      if (m[day][hour] > max) max = m[day][hour];
    }
    return { m, max };
  }, [timestamps]);

  if (matrix.max === 0) {
    return (
      <div className="flex items-center justify-center text-xs text-zinc-500 italic bg-stone-50 rounded-2xl border border-stone-200 h-[200px]">
        Пока нечего показывать — закройте несколько задач
      </div>
    );
  }

  const level = (v: number) => {
    if (v === 0) return 0;
    const r = v / matrix.max;
    if (r < 0.25) return 1;
    if (r < 0.5) return 2;
    if (r < 0.75) return 3;
    return 4;
  };

  return (
    <div className="overflow-x-auto pb-1">
      <div
        className="grid"
        style={{
          gridTemplateColumns: `auto repeat(24, 12px)`,
          gridTemplateRows: 'auto repeat(7, 14px)',
          columnGap: 3,
          rowGap: 3,
        }}
      >
        <div />
        {Array.from({ length: 24 }).map((_, h) => (
          <div
            key={h}
            className="text-[8px] text-zinc-500 leading-3 text-center"
          >
            {h % 6 === 0 ? `${h}` : ''}
          </div>
        ))}
        {DAY_LABELS.map((dl, dIdx) => (
          <React.Fragment key={dl}>
            <div className="text-[10px] text-zinc-500 leading-3 pr-1">{dl}</div>
            {Array.from({ length: 24 }).map((_, h) => (
              <div
                key={h}
                title={`${dl} ${h}:00 — ${matrix.m[dIdx][h]} закр.`}
                className={cn(
                  'rounded-[3px]',
                  level(matrix.m[dIdx][h]) === 0 && 'bg-stone-100',
                  level(matrix.m[dIdx][h]) === 1 && 'bg-indigo-100',
                  level(matrix.m[dIdx][h]) === 2 && 'bg-indigo-300',
                  level(matrix.m[dIdx][h]) === 3 && 'bg-indigo-500',
                  level(matrix.m[dIdx][h]) === 4 && 'bg-indigo-700'
                )}
                style={{ width: 12, height: 14 }}
              />
            ))}
          </React.Fragment>
        ))}
      </div>
    </div>
  );
}
