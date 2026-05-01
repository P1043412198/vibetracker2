import React, { useEffect, useState } from 'react';
import { get } from 'idb-keyval';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { Trophy, Calendar as CalendarIcon, Dumbbell } from 'lucide-react';

interface WorkoutStat {
  exercise: string;
  count: number;
  date: string;
}

export function HistoryTab() {
  const [stats, setStats] = useState<WorkoutStat[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      const data = await get('workout-stats');
      if (data) {
        setStats(data.sort((a: WorkoutStat, b: WorkoutStat) => new Date(b.date).getTime() - new Date(a.date).getTime()));
      }
      setLoading(false);
    };
    fetchStats();
  }, []);

  if (loading) return <div className="text-center text-zinc-400 py-10">Загрузка...</div>;

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-white">История тренировок</h2>
      {stats.length === 0 ? (
        <div className="text-center text-zinc-500 py-10">Пока нет записей.</div>
      ) : (
        <div className="space-y-4">
          {stats.map((stat, index) => (
            <div key={index} className="bg-zinc-900/50 p-4 rounded-xl flex items-center justify-between border border-zinc-800">
              <div className="flex items-center gap-4">
                <div className="p-2 bg-zinc-800 rounded-lg">
                  <Dumbbell className="w-6 h-6 text-emerald-400" />
                </div>
                <div>
                  <h3 className="text-white font-medium">{stat.exercise}</h3>
                  <p className="text-zinc-400 text-sm">{format(new Date(stat.date), 'd MMMM yyyy, HH:mm', { locale: ru })}</p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-2xl font-bold text-white">{stat.count}</p>
                <p className="text-zinc-500 text-xs uppercase tracking-wider">повторений</p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
