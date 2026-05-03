/**
 * GitHub-style year heatmap for a single habit.
 *
 * One square per day. Colour is driven by `valueFor(date)` →  level 0..4.
 * The wrapper passes log data, but the component is presentation-only.
 */
import React, { useMemo } from 'react';
import { format, startOfWeek, addDays, eachDayOfInterval } from 'date-fns';
import { ru } from 'date-fns/locale';
import { cn } from '../../lib/utils';

export interface HeatmapCell {
  date: string; // ISO YYYY-MM-DD
  level: 0 | 1 | 2 | 3 | 4;
  hint?: string;
}

interface Props {
  cells: HeatmapCell[];
  /** End date of the heatmap (defaults to today). */
  endDate?: Date;
  /** Number of weeks to show (default 53 ≈ year). */
  weeks?: number;
  className?: string;
  /** Override default emerald palette. */
  palette?: [string, string, string, string, string];
  title?: string;
  legend?: string;
}

const DEFAULT_PALETTE: [string, string, string, string, string] = [
  '#f1f5f4', // 0 — empty
  '#bbf7d0',
  '#6ee7b7',
  '#34d399',
  '#059669',
];

const MONTH_LABELS = [
  'Янв',
  'Фев',
  'Мар',
  'Апр',
  'Май',
  'Июн',
  'Июл',
  'Авг',
  'Сен',
  'Окт',
  'Ноя',
  'Дек',
];

export function HabitYearHeatmap({
  cells,
  endDate = new Date(),
  weeks = 53,
  className,
  palette = DEFAULT_PALETTE,
  title,
  legend = 'Меньше → Больше',
}: Props) {
  const { columns, monthLabels } = useMemo(() => {
    const start = startOfWeek(addDays(endDate, -weeks * 7 + 1), { weekStartsOn: 1 });
    const end = endDate;
    const dates = eachDayOfInterval({ start, end });

    const map = new Map<string, HeatmapCell>();
    for (const c of cells) map.set(c.date, c);

    const columns: HeatmapCell[][] = [];
    let cur: HeatmapCell[] = [];
    for (const d of dates) {
      const iso = format(d, 'yyyy-MM-dd');
      const cell = map.get(iso) ?? { date: iso, level: 0 as const };
      cur.push(cell);
      if (cur.length === 7) {
        columns.push(cur);
        cur = [];
      }
    }
    if (cur.length) columns.push(cur);

    // Decide label position once per month → first column whose Monday is in
    // a new month gets the month name.
    const monthLabels: { col: number; label: string }[] = [];
    let prevMonth = -1;
    columns.forEach((col, i) => {
      const first = col[0];
      if (!first) return;
      const m = new Date(first.date).getMonth();
      if (m !== prevMonth) {
        monthLabels.push({ col: i, label: MONTH_LABELS[m] });
        prevMonth = m;
      }
    });

    return { columns, monthLabels };
  }, [cells, endDate, weeks]);

  return (
    <div className={cn('w-full', className)}>
      {title && (
        <h3 className="text-xs font-semibold text-zinc-700 mb-2">{title}</h3>
      )}
      <div className="overflow-x-auto pb-1">
        <div
          className="grid"
          style={{
            gridTemplateColumns: `auto repeat(${columns.length}, 12px)`,
            gridTemplateRows: 'auto repeat(7, 12px)',
            columnGap: 3,
            rowGap: 3,
          }}
        >
          {/* Top-left empty corner */}
          <div />
          {/* Month labels row */}
          {columns.map((_, i) => {
            const lbl = monthLabels.find((m) => m.col === i);
            return (
              <div
                key={`m-${i}`}
                className="text-[9px] text-zinc-500 leading-3"
                style={{ height: 12 }}
              >
                {lbl?.label ?? ''}
              </div>
            );
          })}
          {/* Day rows */}
          {Array.from({ length: 7 }).map((_, rowIdx) => (
            <React.Fragment key={`row-${rowIdx}`}>
              <div className="text-[9px] text-zinc-500 leading-3 pr-1">
                {rowIdx % 2 === 1
                  ? format(addDays(new Date(2024, 0, 1 + rowIdx), 0), 'EEEEEE', {
                      locale: ru,
                    })
                  : ''}
              </div>
              {columns.map((col, colIdx) => {
                const cell = col[rowIdx];
                if (!cell) return <div key={`c-${colIdx}-${rowIdx}`} />;
                return (
                  <div
                    key={`c-${colIdx}-${rowIdx}`}
                    title={cell.hint ?? cell.date}
                    className="rounded-[3px]"
                    style={{
                      backgroundColor: palette[cell.level],
                      width: 12,
                      height: 12,
                    }}
                  />
                );
              })}
            </React.Fragment>
          ))}
        </div>
      </div>
      <div className="flex items-center justify-end gap-1 mt-2 text-[10px] text-zinc-500">
        <span>{legend.split('→')[0]}</span>
        {palette.map((c, i) => (
          <div
            key={i}
            className="w-3 h-3 rounded-[3px]"
            style={{ backgroundColor: c }}
          />
        ))}
        <span>{legend.split('→')[1]}</span>
      </div>
    </div>
  );
}
