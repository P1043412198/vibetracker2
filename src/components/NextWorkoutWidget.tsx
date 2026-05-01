import React from 'react';
import { useStore } from '../store/useStore';
import { Dumbbell, Clock, ChevronRight, Calendar, AlertCircle } from 'lucide-react';
import { format, isAfter, parseISO, startOfDay } from 'date-fns';
import { ru } from 'date-fns/locale';
import { Link } from 'react-router-dom';
import { cn } from '../lib/utils';

export function NextWorkoutWidget() {
  const { plannedWorkouts, workoutNodes } = useStore();

  const today = startOfDay(new Date());
  const nextWorkout = (plannedWorkouts || [])
    .filter(p => isAfter(parseISO(p.date), today) || p.date === format(today, 'yyyy-MM-dd'))
    .sort((a, b) => a.date.localeCompare(b.date))[0];

  if (!nextWorkout) {
    return (
      <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-white flex items-center gap-2">
            <Dumbbell className="w-4 h-4 text-emerald-500" />
            Следующая тренировка
          </h2>
        </div>
        <div className="text-center py-6 text-zinc-600">
          <Calendar className="w-8 h-8 mx-auto mb-2 opacity-20" />
          <p className="text-[10px] italic">Нет запланированных тренировок.</p>
          <Link
            to="/workouts"
            className="mt-4 inline-flex items-center gap-2 px-4 py-2 bg-white text-black text-[10px] font-bold rounded-xl hover:bg-zinc-200 transition-all"
          >
            Запланировать
            <ChevronRight className="w-3 h-3" />
          </Link>
        </div>
      </div>
    );
  }

  const program = nextWorkout.programId ? workoutNodes.find(n => n.id === nextWorkout.programId) : null;
  const programExercises = program ? workoutNodes.filter(n => n.parentId === program.id && n.type === 'exercise') : [];

  const estimatedTime = programExercises.length > 0 ? programExercises.length * 8 : 30; // 8 mins per exercise avg or 30 default

  return (
    <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-white flex items-center gap-2">
          <Dumbbell className="w-4 h-4 text-emerald-500" />
          Следующая тренировка
        </h2>
        <span className={cn(
          "text-[9px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider",
          nextWorkout.date === format(today, 'yyyy-MM-dd') 
            ? "bg-emerald-500/20 text-emerald-500 border border-emerald-500/30" 
            : "bg-zinc-800 text-zinc-500"
        )}>
          {nextWorkout.date === format(today, 'yyyy-MM-dd') ? 'Сегодня' : format(parseISO(nextWorkout.date), 'd MMM', { locale: ru })}
        </span>
      </div>

      <div className="space-y-4">
        <div className="flex items-center justify-between bg-zinc-950 p-3 rounded-2xl border border-zinc-800">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-emerald-500/10 rounded-xl flex items-center justify-center border border-emerald-500/20">
              <Dumbbell className="w-5 h-5 text-emerald-500" />
            </div>
            <div>
              <p className="text-xs font-bold text-white truncate max-w-[120px]">
                {nextWorkout.label || program?.name || 'Тренировка'}
              </p>
              <div className="flex items-center gap-2 mt-0.5">
                <Clock className="w-3 h-3 text-zinc-600" />
                <span className="text-[10px] text-zinc-500">~{estimatedTime} мин</span>
              </div>
            </div>
          </div>
          <Link
            to={`/workouts?date=${nextWorkout.date}`}
            className="p-2 bg-zinc-800 text-zinc-400 rounded-xl hover:text-white transition-colors"
          >
            <ChevronRight className="w-4 h-4" />
          </Link>
        </div>

        {programExercises.length > 0 && (
          <div className="space-y-1.5">
            <p className="text-[10px] text-zinc-500 uppercase font-bold px-1">План упражнений:</p>
            <div className="space-y-1 max-h-[120px] overflow-y-auto pr-1 scrollbar-hide">
              {programExercises.slice(0, 4).map((ex, idx) => (
                <div key={idx} className="flex items-center justify-between p-2 bg-zinc-950/50 rounded-xl border border-zinc-800/50">
                  <span className="text-[10px] text-zinc-300 truncate max-w-[140px]">{ex.name}</span>
                  <span className="text-[9px] font-bold text-zinc-500">{ex.muscleGroup || 'Силовая'}</span>
                </div>
              ))}
              {programExercises.length > 4 && (
                <p className="text-[9px] text-zinc-600 text-center py-1">
                  + еще {programExercises.length - 4} упражнения
                </p>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
