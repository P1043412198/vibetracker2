/**
 * Heatmap-календарь трат: одна клетка — день, цвет — сколько потрачено.
 * 6 строк × 53 столбца ≈ год.
 */
import React, { useMemo } from 'react';
import { format, startOfWeek, addDays, eachDayOfInterval } from 'date-fns';
import { ru } from 'date-fns/locale';
import { cn } from '../../lib/utils';

interface Props {
  /** Map of ISO date → expense amount in base currency. */
  expensesByDate: Record<string, number>;
  endDate?: Date;
  weeks?: number;
  format?: (n: number) => string;
  className?: string;
}

const PALETTE = ['#f1f5f4', '#fed7aa', '#fdba74', '#f97316', '#c2410c'];

export function ExpensesCalendarHeatmap({
  expensesByDate,
  endDate = new Date(),
  weeks = 26,
  format: fmt,
  className,
}: Props) {
  const { columns, max } = useMemo(() => {
    const start = startOfWeek(addDays(endDate, -weeks * 7 + 1), {
      weekStartsOn: 1,
    });
    const dates = eachDayOfInterval({ start, end: endDate });
    const cols: { iso: string; v: number }[][] = [];
    let cur: { iso: string; v: number }[] = [];
    let maxV = 0;
    for (const d of dates) {
      const iso = format(d, 'yyyy-MM-dd');
      const v = expensesByDate[iso] ?? 0;
      if (v > maxV) maxV = v;
      cur.push({ iso, v });
      if (cur.length === 7) {
        cols.push(cur);
        cur = [];
      }
    }
    if (cur.length) cols.push(cur);
    return { columns: cols, max: maxV };
  }, [expensesByDate, endDate, weeks]);

  const level = (v: number) => {
    if (max === 0 || v === 0) return 0;
    const r = v / max;
    if (r < 0.25) return 1;
    if (r < 0.5) return 2;
    if (r < 0.75) return 3;
    return 4;
  };

  return (
    <div className={cn('w-full', className)}>
      <div className="overflow-x-auto pb-1">
        <div
          className="grid"
          style={{
            gridTemplateColumns: `repeat(${columns.length}, 12px)`,
            gridTemplateRows: 'repeat(7, 12px)',
            columnGap: 3,
            rowGap: 3,
          }}
        >
          {Array.from({ length: 7 }).map((_, rowIdx) =>
            columns.map((col, colIdx) => {
              const cell = col[rowIdx];
              if (!cell) return <div key={`c-${colIdx}-${rowIdx}`} />;
              return (
                <div
                  key={`c-${colIdx}-${rowIdx}`}
                  title={
                    cell.v
                      ? `${format(new Date(cell.iso), 'dd MMM', { locale: ru })}: ${
                          fmt ? fmt(cell.v) : cell.v.toFixed(0)
                        }`
                      : format(new Date(cell.iso), 'dd MMM', { locale: ru })
                  }
                  className="rounded-[3px]"
                  style={{
                    backgroundColor: PALETTE[level(cell.v)],
                    width: 12,
                    height: 12,
                  }}
                />
              );
            })
          )}
        </div>
      </div>
      <div className="flex items-center justify-end gap-1 mt-2 text-[10px] text-zinc-500">
        <span>Меньше</span>
        {PALETTE.map((c, i) => (
          <div
            key={i}
            className="w-3 h-3 rounded-[3px]"
            style={{ backgroundColor: c }}
          />
        ))}
        <span>Больше</span>
      </div>
    </div>
  );
}
