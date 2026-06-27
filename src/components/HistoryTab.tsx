import { useMemo } from 'react';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { Dumbbell, ChevronRight } from 'lucide-react';
import { useStore } from '../store/useStore';
import type { ExerciseLog, WorkoutMetric } from '../types';

const METRIC_UNIT: Record<WorkoutMetric, string> = {
  weight: 'кг',
  reps: 'повт.',
  distance: 'км',
  time: 'мин',
  speed: 'км/ч',
  calories: 'ккал',
};

function fmt(v: number): string {
  return Number.isInteger(v) ? String(v) : v.toFixed(1);
}

function setSummary(log: ExerciseLog): string {
  const m = log.metrics;
  const parts: string[] = [];
  if (m.weight != null && m.reps != null) {
    parts.push(`${fmt(m.weight)} кг × ${fmt(m.reps)}`);
  } else {
    (Object.entries(m) as [WorkoutMetric, number][]).forEach(([k, v]) => {
      if (v != null) parts.push(`${fmt(v)} ${METRIC_UNIT[k]}`);
    });
  }
  if (parts.length === 0) parts.push('—');
  if (log.restTime && log.restTime > 0) parts.push(`отдых ${log.restTime}с`);
  return parts.join('  ·  ');
}

function volumeOf(logs: ExerciseLog[]): number {
  return logs.reduce((sum, l) => {
    const w = l.metrics.weight ?? 0;
    const r = l.metrics.reps ?? 1;
    return sum + w * r;
  }, 0);
}

export function HistoryTab() {
  const { exerciseLogs, workoutNodes } = useStore();

  const nameOf = (id: string) =>
    workoutNodes.find((n) => n.id === id)?.name ?? '(удалено)';

  const days = useMemo(() => {
    const byDate = new Map<string, ExerciseLog[]>();
    for (const l of exerciseLogs) {
      const arr = byDate.get(l.date) ?? [];
      arr.push(l);
      byDate.set(l.date, arr);
    }
    return Array.from(byDate.entries())
      .sort((a, b) => b[0].localeCompare(a[0]))
      .map(([date, logs]) => {
        const byExercise = new Map<string, ExerciseLog[]>();
        for (const l of logs) {
          const arr = byExercise.get(l.exerciseId) ?? [];
          arr.push(l);
          byExercise.set(l.exerciseId, arr);
        }
        return { date, logs, exercises: Array.from(byExercise.entries()) };
      });
  }, [exerciseLogs]);

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-zinc-900">История тренировок</h2>
      {days.length === 0 ? (
        <div className="text-center text-zinc-500 py-10">
          Пока нет записей. Запиши подход — он появится здесь, сгруппированный по дням.
        </div>
      ) : (
        <div className="space-y-4">
          {days.map(({ date, logs, exercises }) => {
            const d = new Date(date);
            const weekday = format(d, 'EEEE', { locale: ru });
            return (
              <div
                key={date}
                className="bg-white/60 rounded-xl border border-stone-200 overflow-hidden"
              >
                <div className="flex items-center justify-between px-4 py-3 bg-stone-100/60">
                  <h3 className="text-zinc-900 font-semibold capitalize">
                    {weekday}, {format(d, 'd MMMM yyyy', { locale: ru })}
                  </h3>
                  <span className="text-xs text-zinc-500">
                    {logs.length} подх. · объём {fmt(volumeOf(logs))}
                  </span>
                </div>
                <div className="divide-y divide-stone-200/70">
                  {exercises.map(([exId, sets]) => (
                    <div key={exId} className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <div className="p-1.5 bg-stone-100 rounded-lg">
                          <Dumbbell className="w-4 h-4 text-emerald-500" />
                        </div>
                        <span className="text-zinc-900 font-medium flex-1">
                          {nameOf(exId)}
                        </span>
                        <span className="text-xs text-zinc-500">
                          {sets.length} подх.
                        </span>
                        <ChevronRight className="w-4 h-4 text-zinc-400" />
                      </div>
                      <p className="text-sm text-zinc-500 mt-1 pl-9">
                        {sets.map(setSummary).join('   ')}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
