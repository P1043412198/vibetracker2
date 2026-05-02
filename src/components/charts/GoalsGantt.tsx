/**
 * Mini-Gantt: goals on Y axis, time on X axis. Each bar runs from
 * goal.createdAt to goal.deadline (or today, if no deadline). Fill width
 * is driven by the progress ratio.
 */
import React, { useMemo } from 'react';
import { differenceInDays, format, parseISO } from 'date-fns';
import { ru } from 'date-fns/locale';
import { cn } from '../../lib/utils';

export interface GanttGoal {
  id: string;
  title: string;
  start: string; // ISO
  end?: string; // ISO
  progress: number; // 0..1
  type: 'goal' | 'skill' | 'book' | 'learning';
  status: 'not_started' | 'in_progress' | 'completed';
}

interface Props {
  goals: GanttGoal[];
  /** Width per day in pixels — 2 by default. */
  scale?: number;
}

const TYPE_COLOR: Record<string, string> = {
  goal: 'bg-blue-400',
  skill: 'bg-purple-400',
  book: 'bg-emerald-400',
  learning: 'bg-orange-400',
};

const TYPE_BG: Record<string, string> = {
  goal: 'bg-blue-100',
  skill: 'bg-purple-100',
  book: 'bg-emerald-100',
  learning: 'bg-orange-100',
};

export function GoalsGantt({ goals, scale = 2 }: Props) {
  const { earliestStart, latestEnd, today } = useMemo(() => {
    if (goals.length === 0) {
      const now = new Date();
      return { earliestStart: now, latestEnd: now, today: now };
    }
    const starts = goals.map((g) => parseISO(g.start).getTime());
    const ends = goals.map((g) =>
      g.end ? parseISO(g.end).getTime() : Date.now()
    );
    return {
      earliestStart: new Date(Math.min(...starts)),
      latestEnd: new Date(Math.max(...ends, Date.now())),
      today: new Date(),
    };
  }, [goals]);

  if (goals.length === 0) {
    return (
      <div className="flex items-center justify-center text-xs text-zinc-500 italic bg-stone-50 rounded-2xl border border-stone-200 h-32">
        Пока нет целей с датами
      </div>
    );
  }

  const totalDays = Math.max(
    14,
    differenceInDays(latestEnd, earliestStart) + 1
  );
  const todayOffset = differenceInDays(today, earliestStart);

  return (
    <div className="overflow-x-auto pb-2">
      <div className="space-y-1.5" style={{ minWidth: totalDays * scale + 200 }}>
        {goals.map((g) => {
          const startOffset = differenceInDays(parseISO(g.start), earliestStart);
          const endOffset = g.end
            ? differenceInDays(parseISO(g.end), earliestStart)
            : todayOffset;
          const duration = Math.max(1, endOffset - startOffset);
          return (
            <div key={g.id} className="grid grid-cols-[160px_1fr] gap-2 items-center">
              <div className="truncate text-xs text-zinc-700 pr-2">{g.title}</div>
              <div
                className="relative h-5 bg-stone-50 rounded-md border border-stone-200"
                style={{ width: totalDays * scale }}
              >
                <div
                  className={cn('absolute h-full rounded-md', TYPE_BG[g.type])}
                  style={{
                    left: startOffset * scale,
                    width: duration * scale,
                  }}
                />
                <div
                  className={cn('absolute h-full rounded-md', TYPE_COLOR[g.type])}
                  style={{
                    left: startOffset * scale,
                    width: duration * scale * Math.max(0, Math.min(1, g.progress)),
                    opacity: 0.85,
                  }}
                />
                <div
                  className="absolute top-0 bottom-0 w-0.5 bg-rose-500/70"
                  style={{ left: todayOffset * scale }}
                  title={`Сегодня: ${format(today, 'dd.MM.yyyy')}`}
                />
              </div>
            </div>
          );
        })}
        <div className="grid grid-cols-[160px_1fr] gap-2 items-center pt-1">
          <div />
          <div
            className="flex justify-between text-[10px] text-zinc-500"
            style={{ width: totalDays * scale }}
          >
            <span>{format(earliestStart, 'dd MMM yy', { locale: ru })}</span>
            <span>{format(latestEnd, 'dd MMM yy', { locale: ru })}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
