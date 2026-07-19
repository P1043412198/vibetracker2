import { useMemo, useState } from 'react';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { Dumbbell, ChevronRight, Clock, Trophy, X, TrendingUp, Trash2, Layers } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts';
import { useStore } from '../store/useStore';
import type { ExerciseLog } from '../types';
import { setSummary, volumeOf, fmtNum, oneRepMax, bestWeight, formatDuration } from '../lib/workout';

interface JournalGroup {
  key: string;
  date: string;
  sortKey: string;
  title: string;
  durationSec?: number;
  logs: ExerciseLog[];
  exercises: [string, ExerciseLog[]][];
  sessionId?: string;
}

function groupExercises(logs: ExerciseLog[]): [string, ExerciseLog[]][] {
  const byExercise = new Map<string, ExerciseLog[]>();
  for (const l of logs) {
    const arr = byExercise.get(l.exerciseId) ?? [];
    arr.push(l);
    byExercise.set(l.exerciseId, arr);
  }
  return Array.from(byExercise.entries());
}

export function WorkoutJournal() {
  const { exerciseLogs, workoutNodes, workoutSessions, deleteWorkoutSession } = useStore();
  const [detailExercise, setDetailExercise] = useState<string | null>(null);

  const nameOf = (id: string) =>
    workoutNodes.find((n) => n.id === id)?.name ?? '(удалено)';

  const groups = useMemo<JournalGroup[]>(() => {
    const out: JournalGroup[] = [];
    const usedLogIds = new Set<string>();

    const sessions = [...(workoutSessions || [])].sort((a, b) =>
      (b.startedAt || b.date).localeCompare(a.startedAt || a.date)
    );
    for (const s of sessions) {
      const logs = exerciseLogs.filter((l) => l.sessionId === s.id);
      logs.forEach((l) => usedLogIds.add(l.id));
      out.push({
        key: `session-${s.id}`,
        date: s.date,
        sortKey: s.startedAt || s.date,
        title: s.label || 'Тренировка',
        durationSec: s.durationSec,
        logs,
        exercises: groupExercises(logs),
        sessionId: s.id,
      });
    }

    // Legacy / loose logs (no session) grouped by date
    const byDate = new Map<string, ExerciseLog[]>();
    for (const l of exerciseLogs) {
      if (usedLogIds.has(l.id)) continue;
      const arr = byDate.get(l.date) ?? [];
      arr.push(l);
      byDate.set(l.date, arr);
    }
    for (const [date, logs] of byDate.entries()) {
      out.push({
        key: `date-${date}`,
        date,
        sortKey: date,
        title: 'Тренировка',
        logs,
        exercises: groupExercises(logs),
      });
    }

    return out.sort((a, b) => b.sortKey.localeCompare(a.sortKey));
  }, [exerciseLogs, workoutSessions]);

  return (
    <div className="space-y-4">
      {groups.length === 0 ? (
        <div className="text-center text-zinc-500 py-10">
          Пока нет записей. Начните тренировку во вкладке «Сегодня» — она появится здесь.
        </div>
      ) : (
        groups.map((g) => {
          const d = new Date(g.date);
          const weekday = format(d, 'EEEE', { locale: ru });
          return (
            <div key={g.key} className="bg-white/60 rounded-2xl border border-stone-200 overflow-hidden">
              <div className="flex items-center justify-between px-4 py-3 bg-stone-100/60">
                <div>
                  <h3 className="text-zinc-900 font-semibold capitalize leading-tight">
                    {weekday}, {format(d, 'd MMMM', { locale: ru })}
                  </h3>
                  <span className="text-[11px] text-zinc-500">{g.title}</span>
                </div>
                <div className="flex items-center gap-3">
                  <div className="text-right">
                    <div className="flex items-center justify-end gap-2 text-xs text-zinc-600">
                      {g.durationSec != null && (
                        <span className="flex items-center gap-1">
                          <Clock className="w-3 h-3" />
                          {formatDuration(g.durationSec)}
                        </span>
                      )}
                      <span className="flex items-center gap-1">
                        <Layers className="w-3 h-3" />
                        {g.logs.length}
                      </span>
                    </div>
                    <div className="text-[11px] text-zinc-500">объём {fmtNum(volumeOf(g.logs))}</div>
                  </div>
                  {g.sessionId && (
                    <button
                      onClick={() => {
                        if (confirm('Удалить эту тренировку? Записанные подходы тоже будут удалены.')) {
                          deleteWorkoutSession(g.sessionId!, { deleteLogs: true });
                        }
                      }}
                      className="p-1.5 text-red-400 hover:text-red-500 hover:bg-red-400/10 rounded-lg transition-colors"
                      title="Удалить тренировку"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
              </div>
              <div className="divide-y divide-stone-200/70">
                {g.exercises.map(([exId, sets]) => (
                  <button
                    key={exId}
                    onClick={() => setDetailExercise(exId)}
                    className="w-full text-left px-4 py-3 hover:bg-stone-50 transition-colors"
                  >
                    <div className="flex items-center gap-2">
                      <div className="p-1.5 bg-stone-100 rounded-lg">
                        <Dumbbell className="w-4 h-4 text-emerald-500" />
                      </div>
                      <span className="text-zinc-900 font-medium flex-1">{nameOf(exId)}</span>
                      <span className="text-xs text-zinc-500">{sets.length} подх.</span>
                      <ChevronRight className="w-4 h-4 text-zinc-400" />
                    </div>
                    <p className="text-sm text-zinc-500 mt-1 pl-9">
                      {sets.map(setSummary).join('   ')}
                    </p>
                  </button>
                ))}
              </div>
            </div>
          );
        })
      )}

      <AnimatePresence>
        {detailExercise && (
          <ExerciseDetailModal
            exerciseId={detailExercise}
            name={nameOf(detailExercise)}
            onClose={() => setDetailExercise(null)}
          />
        )}
      </AnimatePresence>
    </div>
  );
}

function ExerciseDetailModal({
  exerciseId,
  name,
  onClose,
}: {
  exerciseId: string;
  name: string;
  onClose: () => void;
}) {
  const { exerciseLogs } = useStore();

  const logs = useMemo(
    () => exerciseLogs.filter((l) => l.exerciseId === exerciseId),
    [exerciseLogs, exerciseId]
  );

  const byDay = useMemo(() => {
    const m = new Map<string, ExerciseLog[]>();
    for (const l of logs) {
      const arr = m.get(l.date) ?? [];
      arr.push(l);
      m.set(l.date, arr);
    }
    return Array.from(m.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [logs]);

  const chartData = byDay.map(([date, sets]) => {
    const maxW = sets.reduce((mx, s) => Math.max(mx, s.metrics.weight ?? 0), 0);
    const bestRm = sets.reduce((mx, s) => {
      const rm = oneRepMax(s.metrics.weight ?? 0, s.metrics.reps ?? 0);
      return Math.max(mx, rm);
    }, 0);
    return {
      label: format(new Date(date), 'd MMM', { locale: ru }),
      volume: Math.round(volumeOf(sets)),
      weight: maxW,
      rm: bestRm,
    };
  });

  const totalSessions = byDay.length;
  const totalSets = logs.length;
  const best = bestWeight(logs, exerciseId);
  const bestRm = logs.reduce(
    (mx, s) => Math.max(mx, oneRepMax(s.metrics.weight ?? 0, s.metrics.reps ?? 0)),
    0
  );

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4"
      onClick={onClose}
    >
      <motion.div
        initial={{ y: 40, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        exit={{ y: 40, opacity: 0 }}
        className="bg-white rounded-t-3xl sm:rounded-3xl border border-stone-200 max-w-2xl w-full max-h-[88vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="sticky top-0 bg-white border-b border-stone-200 p-4 flex items-center justify-between rounded-t-3xl z-10">
          <h3 className="font-semibold text-zinc-900 flex items-center gap-2">
            <Dumbbell className="w-4 h-4 text-emerald-500" />
            {name}
          </h3>
          <button onClick={onClose} className="text-zinc-500 hover:text-zinc-900">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="p-4 space-y-5">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            <Stat label="Тренировок" value={String(totalSessions)} />
            <Stat label="Подходов" value={String(totalSets)} />
            <Stat label="Макс. вес" value={best > 0 ? `${fmtNum(best)} кг` : '—'} />
            <Stat label="1ПМ (оц.)" value={bestRm > 0 ? `${bestRm} кг` : '—'} icon={<Trophy className="w-3 h-3 text-amber-500" />} />
          </div>

          {chartData.length >= 2 ? (
            <>
              <div>
                <p className="text-xs font-medium text-zinc-500 mb-1 flex items-center gap-1">
                  <TrendingUp className="w-3.5 h-3.5" /> Объём по тренировкам
                </p>
                <div className="h-40">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={chartData}>
                      <defs>
                        <linearGradient id="volFill" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#10b981" stopOpacity={0.3} />
                          <stop offset="100%" stopColor="#10b981" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#e7e5e4" />
                      <XAxis dataKey="label" tick={{ fontSize: 10 }} stroke="#a8a29e" />
                      <YAxis tick={{ fontSize: 10 }} stroke="#a8a29e" width={36} />
                      <Tooltip />
                      <Area type="monotone" dataKey="volume" stroke="#10b981" fill="url(#volFill)" strokeWidth={2} />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>
              <div>
                <p className="text-xs font-medium text-zinc-500 mb-1">Макс. вес и оценка 1ПМ</p>
                <div className="h-40">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={chartData}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#e7e5e4" />
                      <XAxis dataKey="label" tick={{ fontSize: 10 }} stroke="#a8a29e" />
                      <YAxis tick={{ fontSize: 10 }} stroke="#a8a29e" width={36} />
                      <Tooltip />
                      <Line type="monotone" dataKey="weight" name="Вес" stroke="#6366f1" strokeWidth={2} dot={false} />
                      <Line type="monotone" dataKey="rm" name="1ПМ" stroke="#f59e0b" strokeWidth={2} strokeDasharray="4 4" dot={false} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </>
          ) : (
            <p className="text-xs text-zinc-500 text-center py-4">
              Запишите подходы хотя бы за 2 разных дня, чтобы увидеть графики прогресса.
            </p>
          )}

          <div>
            <p className="text-xs font-medium text-zinc-500 mb-2">История подходов</p>
            <div className="space-y-2">
              {[...byDay].reverse().map(([date, sets]) => (
                <div key={date} className="border border-stone-200 rounded-xl p-3">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-sm font-medium text-zinc-900 capitalize">
                      {format(new Date(date), 'EEEE, d MMM', { locale: ru })}
                    </span>
                    <span className="text-[11px] text-zinc-500">объём {fmtNum(volumeOf(sets))}</span>
                  </div>
                  <div className="space-y-0.5">
                    {sets.map((s, i) => (
                      <p key={s.id} className="text-sm text-zinc-600">
                        <span className="text-zinc-400">{i + 1}.</span> {setSummary(s)}
                      </p>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </motion.div>
    </motion.div>
  );
}

function Stat({ label, value, icon }: { label: string; value: string; icon?: React.ReactNode }) {
  return (
    <div className="bg-stone-50 border border-stone-200 rounded-xl p-2.5 text-center">
      <div className="text-base font-bold text-zinc-900 flex items-center justify-center gap-1">
        {icon}
        {value}
      </div>
      <div className="text-[10px] text-zinc-500">{label}</div>
    </div>
  );
}
