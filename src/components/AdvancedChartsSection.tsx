/**
 * Расширенный блок графиков, который монтируется внизу страницы Аналитики.
 * Объединяет визуализации привычек, задач и целей: year-heatmap, streak
 * chains, радар сфер, velocity, heatmap закрытий задач, Gantt целей.
 */
import React, { useMemo, useState } from 'react';
import {
  format,
  parseISO,
  startOfWeek,
  differenceInDays,
} from 'date-fns';
import { useStore } from '../store/useStore';
import { HabitYearHeatmap, type HeatmapCell } from './charts/HabitYearHeatmap';
import { StreakChains } from './charts/StreakChains';
import { SphereRadar } from './charts/SphereRadar';
import { TaskVelocityChart } from './charts/TaskVelocityChart';
import { TaskCloseHeatmap } from './charts/TaskCloseHeatmap';
import { GoalsGantt, type GanttGoal } from './charts/GoalsGantt';

type Section = 'habits' | 'tasks' | 'goals';

const SECTIONS: { id: Section; label: string }[] = [
  { id: 'habits', label: 'Привычки' },
  { id: 'tasks', label: 'Задачи' },
  { id: 'goals', label: 'Цели' },
];

export function AdvancedChartsSection() {
  const [section, setSection] = useState<Section>('habits');
  const { habits = [], habitLogs = [], tasks = [], spheres = [], goals = [] } = useStore();
  const [selectedHabitId, setSelectedHabitId] = useState<string>(
    habits[0]?.id ?? ''
  );

  // habit year heatmap data
  const heatmapCells = useMemo<HeatmapCell[]>(() => {
    if (!selectedHabitId) return [];
    const logs = habitLogs.filter((l) => l.habitId === selectedHabitId);
    return logs.map((l) => ({
      date: l.date,
      level: (l.status === 'done' ? 4 : l.status === 'failed' ? 1 : 2) as
        | 0
        | 1
        | 2
        | 3
        | 4,
      hint: `${l.date}: ${l.status}${l.notes ? ' — ' + l.notes : ''}`,
    }));
  }, [habitLogs, selectedHabitId]);

  // current/best streak per selected habit
  const streakInfo = useMemo(() => {
    const logs = habitLogs
      .filter((l) => l.habitId === selectedHabitId && l.status === 'done')
      .map((l) => l.date)
      .sort();
    let current = 0,
      best = 0,
      run = 0;
    let prev: string | null = null;
    for (const d of logs) {
      if (prev) {
        const diff = differenceInDays(parseISO(d), parseISO(prev));
        if (diff === 1) run++;
        else run = 1;
      } else {
        run = 1;
      }
      best = Math.max(best, run);
      prev = d;
    }
    if (logs.length) {
      const last = parseISO(logs[logs.length - 1]);
      const today = new Date();
      if (differenceInDays(today, last) <= 1) current = run;
    }
    const days = logs.slice(-90).map((iso) => ({
      iso,
      status: 'done' as const,
    }));
    return { current, best, days };
  }, [habitLogs, selectedHabitId]);

  // sphere radar — % completed tasks per sphere
  const sphereScores = useMemo(() => {
    const result: { sphere: string; score: number }[] = [];
    for (const sphere of spheres) {
      const sTasks = tasks.filter((t) => t.sphereId === sphere.id);
      if (sTasks.length === 0) continue;
      const done = sTasks.filter((t) => t.completed).length;
      result.push({
        sphere: sphere.title,
        score: Math.round((done / sTasks.length) * 100),
      });
    }
    return result;
  }, [tasks, spheres]);

  const velocity = useMemo(() => {
    const map = new Map<string, { created: number; completed: number }>();
    const ensure = (key: string) =>
      map.get(key) ?? map.set(key, { created: 0, completed: 0 }).get(key)!;
    for (const t of tasks) {
      const created = parseISO(t.date);
      if (!Number.isFinite(created.getTime())) continue;
      const week = format(startOfWeek(created, { weekStartsOn: 1 }), 'yyyy-MM-dd');
      ensure(week).created++;
      if (t.completed) ensure(week).completed++;
    }
    return Array.from(map.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .slice(-12)
      .map(([week, counts]) => ({ week, ...counts }));
  }, [tasks]);

  const taskCloseTimestamps = useMemo(
    () =>
      tasks
        .filter((t) => t.completed)
        // tasks have a `date` (start) but no completion timestamp; assume same day at noon
        .map((t) => `${t.date.split('T')[0]}T12:00:00`),
    [tasks]
  );

  const ganttGoals = useMemo<GanttGoal[]>(
    () =>
      goals.map((g) => ({
        id: g.id,
        title: g.title,
        start: g.createdAt,
        end: g.deadline,
        progress: (g.progress ?? 0) / 100,
        type: g.type as GanttGoal['type'],
        status: g.status as GanttGoal['status'],
      })),
    [goals]
  );

  return (
    <section className="bg-white border border-stone-200 rounded-3xl p-4 sm:p-5 mt-6">
      <header className="flex items-center justify-between gap-2 mb-4 flex-wrap">
        <div>
          <h2 className="text-base font-bold text-zinc-900">Расширенные графики</h2>
          <p className="text-xs text-zinc-500">
            Привычки на год, скорость задач, Gantt целей.
          </p>
        </div>
        <div className="flex gap-1 bg-stone-100 p-1 rounded-xl">
          {SECTIONS.map((s) => (
            <button
              key={s.id}
              onClick={() => setSection(s.id)}
              className={
                'px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ' +
                (section === s.id
                  ? 'bg-white text-zinc-900 shadow-sm'
                  : 'text-zinc-500 hover:text-zinc-800')
              }
            >
              {s.label}
            </button>
          ))}
        </div>
      </header>

      {section === 'habits' && (
        <div className="space-y-5">
          {habits.length > 0 && (
            <div className="flex items-center gap-2 text-xs">
              <label className="text-zinc-500">Привычка:</label>
              <select
                value={selectedHabitId}
                onChange={(e) => setSelectedHabitId(e.target.value)}
                className="bg-white border border-stone-200 rounded-lg px-3 py-1.5 text-xs"
              >
                {habits.map((h) => (
                  <option key={h.id} value={h.id}>
                    {h.title}
                  </option>
                ))}
              </select>
            </div>
          )}
          <HabitYearHeatmap
            cells={heatmapCells}
            title="Год активности"
            legend="Меньше → Больше"
          />
          <div>
            <h3 className="text-xs font-semibold text-zinc-700 mb-2">Серии</h3>
            <StreakChains
              days={streakInfo.days}
              current={streakInfo.current}
              best={streakInfo.best}
            />
          </div>
          <div>
            <h3 className="text-xs font-semibold text-zinc-700 mb-2">По сферам</h3>
            <SphereRadar data={sphereScores} />
          </div>
        </div>
      )}

      {section === 'tasks' && (
        <div className="space-y-5">
          <div>
            <h3 className="text-xs font-semibold text-zinc-700 mb-2">
              Скорость (созданные vs закрытые)
            </h3>
            <TaskVelocityChart data={velocity} />
          </div>
          <div>
            <h3 className="text-xs font-semibold text-zinc-700 mb-2">
              Часы / дни закрытия задач
            </h3>
            <TaskCloseHeatmap timestamps={taskCloseTimestamps} />
          </div>
        </div>
      )}

      {section === 'goals' && (
        <div className="space-y-5">
          <div>
            <h3 className="text-xs font-semibold text-zinc-700 mb-2">
              Календарь целей (Gantt)
            </h3>
            <GoalsGantt goals={ganttGoals} />
          </div>
        </div>
      )}
    </section>
  );
}
