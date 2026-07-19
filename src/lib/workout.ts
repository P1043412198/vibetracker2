import type { ExerciseLog, WorkoutMetric, WorkoutNode } from '../types';

export const METRIC_UNIT: Record<WorkoutMetric, string> = {
  weight: 'кг',
  reps: 'повт.',
  distance: 'км',
  time: 'мин',
  speed: 'км/ч',
  calories: 'ккал',
};

export const METRIC_LABEL: Record<WorkoutMetric, string> = {
  weight: 'Вес (кг)',
  reps: 'Повторения',
  distance: 'Дистанция (км)',
  time: 'Время (мин)',
  speed: 'Скорость (км/ч)',
  calories: 'Калории (ккал)',
};

export function fmtNum(v: number): string {
  return Number.isInteger(v) ? String(v) : v.toFixed(1);
}

/** "60 кг × 10  ·  отдых 90с" */
export function setSummary(log: ExerciseLog): string {
  const m = log.metrics;
  const parts: string[] = [];
  if (m.weight != null && m.reps != null) {
    parts.push(`${fmtNum(m.weight)} кг × ${fmtNum(m.reps)}`);
  } else {
    (Object.entries(m) as [WorkoutMetric, number][]).forEach(([k, v]) => {
      if (v != null) parts.push(`${fmtNum(v)} ${METRIC_UNIT[k]}`);
    });
  }
  if (parts.length === 0) parts.push('—');
  if (log.restTime && log.restTime > 0) parts.push(`отдых ${log.restTime}с`);
  return parts.join('  ·  ');
}

/** Total tonnage (weight × reps) of a set of logs. */
export function volumeOf(logs: ExerciseLog[]): number {
  return logs.reduce((sum, l) => {
    const w = l.metrics.weight ?? 0;
    const r = l.metrics.reps ?? 1;
    return sum + w * r;
  }, 0);
}

/** Epley estimated one-rep max. */
export function oneRepMax(weight: number, reps: number): number {
  if (weight <= 0 || reps <= 0) return 0;
  return Math.round(weight * (1 + reps / 30));
}

/** Best (max) weight ever recorded for an exercise. */
export function bestWeight(logs: ExerciseLog[], exerciseId: string): number {
  return logs.reduce((max, l) => {
    if (l.exerciseId !== exerciseId) return max;
    const w = l.metrics.weight ?? 0;
    return w > max ? w : max;
  }, 0);
}

/** All exercise nodes that are descendants of a folder (recursive). */
export function exercisesUnder(nodes: WorkoutNode[], folderId: string): WorkoutNode[] {
  const out: WorkoutNode[] = [];
  const walk = (parentId: string) => {
    for (const n of nodes.filter((x) => x.parentId === parentId)) {
      if (n.type === 'exercise') out.push(n);
      else walk(n.id);
    }
  };
  walk(folderId);
  return out;
}

export function formatDuration(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  const h = Math.floor(m / 60);
  if (h > 0) return `${h}ч ${m % 60}м`;
  if (m > 0) return `${m}м ${s.toString().padStart(2, '0')}с`;
  return `${s}с`;
}

export const WEEKDAY_SHORT = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];

export function todayISO(): string {
  return new Date().toISOString().split('T')[0];
}
