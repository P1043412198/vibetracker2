import React, { useMemo, useState } from 'react';
import { useStore } from '../store/useStore';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip, BarChart, Bar, XAxis, YAxis, CartesianGrid, Legend, RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar, AreaChart, Area, ComposedChart, Line, LineChart } from 'recharts';
import { CheckCircle2, XCircle, ListTodo, Target, Activity, MinusCircle, Flame, Trophy, Calendar, TrendingUp, Zap, Award, AlertTriangle, BrainCircuit, Sparkles, Loader2 } from 'lucide-react';
import { analyzeWeek } from '../services/aiService';
import ReactMarkdown from 'react-markdown';
import { cn } from '../lib/utils';

export function Analytics() {
  const { tasks, spheres, habits, habitLogs, workSchedule, goals, exerciseLogs, hideHabitNames } = useStore();
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysisResult, setAnalysisResult] = useState<string | null>(null);

  const handleAnalyze = async () => {
    setIsAnalyzing(true);
    try {
      const data = {
        tasks: tasks.slice(-50), // Last 50 tasks for context
        habitLogs: habitLogs.slice(-50),
        workSchedule,
        goals: goals.map(g => ({ title: g.title, status: g.status, progress: g.progress })),
        exerciseLogs: exerciseLogs?.slice(-20)
      };
      const result = await analyzeWeek(process.env.GEMINI_API_KEY!, data);
      setAnalysisResult(result || "Не удалось получить анализ.");
    } catch (error) {
      console.error(error);
      setAnalysisResult("Произошла ошибка при анализе.");
    } finally {
      setIsAnalyzing(false);
    }
  };

  // --- MEMOIZED CALCULATIONS ---
  const analyticsData = useMemo(() => {
    const today = new Date();
    today.setHours(0,0,0,0);
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    // 1. STREAKS (Global)
    const activeDates = new Set([
      ...tasks.filter(t => t.completed).map(t => t.date.split('T')[0]),
      ...habitLogs.filter(l => l.status === 'done').map(l => l.date)
    ]);
    const sortedDates = Array.from(activeDates).sort((a, b) => new Date(b).getTime() - new Date(a).getTime());
    
    let currentStreak = 0;
    let maxStreak = 0;
    let checkDate = new Date(today);
    let isActive = false;
    
    if (activeDates.has(today.toISOString().split('T')[0])) {
      isActive = true;
    } else if (activeDates.has(yesterday.toISOString().split('T')[0])) {
      isActive = true;
      checkDate = yesterday;
    }

    if (isActive) {
      while (activeDates.has(checkDate.toISOString().split('T')[0])) {
        currentStreak++;
        checkDate.setDate(checkDate.getDate() - 1);
      }
    }

    if (sortedDates.length > 0) {
      let currDate = new Date(sortedDates[0]);
      let tempStreak = 1;
      maxStreak = 1;
      for (let i = 1; i < sortedDates.length; i++) {
        const prevDate = new Date(sortedDates[i]);
        const diffTime = Math.abs(currDate.getTime() - prevDate.getTime());
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        
        if (diffDays === 1) {
          tempStreak++;
          maxStreak = Math.max(maxStreak, tempStreak);
        } else {
          tempStreak = 1;
        }
        currDate = prevDate;
      }
    }

    // 2. TASKS OVERVIEW
    const totalTasks = tasks.length;
    const completedTasks = tasks.filter(t => t.completed).length;
    const failedTasks = tasks.filter(t => t.failed).length;
    const pendingTasks = totalTasks - completedTasks - failedTasks;
    const taskCompletionRate = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;

    const taskStatusPie = [
      { name: 'Выполнено', value: completedTasks, color: '#10b981' }, // emerald-500
      { name: 'Провалено', value: failedTasks, color: '#ef4444' }, // red-500
      { name: 'В процессе', value: pendingTasks, color: '#3f3f46' }, // zinc-700
    ];

    // 3. SPHERES DATA
    const tasksBySphere = spheres.map(sphere => {
      const sphereTasks = tasks.filter(t => t.sphereId === sphere.id);
      const completed = sphereTasks.filter(t => t.completed).length;
      return {
        name: sphere.title,
        total: sphereTasks.length,
        completed: completed,
        rate: sphereTasks.length > 0 ? Math.round((completed / sphereTasks.length) * 100) : 0,
      };
    }).filter(s => s.total > 0);

    const sphereBalance = tasksBySphere.map(s => ({
      subject: s.name,
      A: s.rate,
      fullMark: 100,
    }));

    const bestSphere = tasksBySphere.length > 0 ? tasksBySphere.reduce((prev, current) => (prev.rate > current.rate) ? prev : current) : null;

    // 4. DAY OF WEEK ANALYSIS
    const daysOfWeek = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    
    // Tasks by day of week
    const tasksByDayOfWeek = daysOfWeek.map((day, index) => {
      const dayTasks = tasks.filter(t => new Date(t.date).getDay() === index);
      const completed = dayTasks.filter(t => t.completed).length;
      return {
        name: day,
        total: dayTasks.length,
        completed: completed,
        rate: dayTasks.length > 0 ? Math.round((completed / dayTasks.length) * 100) : 0
      };
    });
    const shiftedTasksByDayOfWeek = [...tasksByDayOfWeek.slice(1), tasksByDayOfWeek[0]];
    const mostProductiveDay = shiftedTasksByDayOfWeek.reduce((prev, current) => (prev.rate > current.rate && prev.total > 0) ? prev : current, shiftedTasksByDayOfWeek[0]);

    // Habits by day of week
    const habitsByDayOfWeek = daysOfWeek.map((day, index) => {
      const dayLogs = habitLogs.filter(l => new Date(l.date).getDay() === index);
      const done = dayLogs.filter(l => l.status === 'done').length;
      const total = dayLogs.length;
      return {
        name: day,
        done,
        total,
        rate: total > 0 ? Math.round((done / total) * 100) : 0
      };
    });
    const shiftedHabitsByDayOfWeek = [...habitsByDayOfWeek.slice(1), habitsByDayOfWeek[0]];
    const bestHabitDay = shiftedHabitsByDayOfWeek.reduce((prev, current) => (prev.rate > current.rate && prev.total > 0) ? prev : current, shiftedHabitsByDayOfWeek[0]);

    // 5. 30-DAY TREND (Area Chart)
    const last30Days = Array.from({ length: 30 }).map((_, i) => {
      const d = new Date();
      d.setDate(d.getDate() - (29 - i));
      const dateStr = d.toISOString().split('T')[0];
      
      const dayTasks = tasks.filter(t => t.date.startsWith(dateStr));
      const dayHabits = habitLogs.filter(l => l.date === dateStr);
      
      const completedT = dayTasks.filter(t => t.completed).length;
      const doneH = dayHabits.filter(l => l.status === 'done').length;
      
      return {
        date: d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' }),
        fullDate: dateStr,
        tasks: completedT,
        habits: doneH,
        totalActivity: completedT + doneH,
      };
    });

    // 6. HABITS OVERVIEW & STREAKS
    const totalHabitLogs = habitLogs.length;
    const doneHabits = habitLogs.filter(l => l.status === 'done').length;
    const failedHabitLogs = habitLogs.filter(l => l.status === 'failed').length;
    const skippedHabitLogs = habitLogs.filter(l => l.status === 'skipped').length;
    const habitCompletionRate = totalHabitLogs > 0 ? Math.round((doneHabits / totalHabitLogs) * 100) : 0;

    const habitPerformance = habits.map(habit => {
      const logs = habitLogs.filter(l => l.habitId === habit.id).sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
      const done = logs.filter(l => l.status === 'done').length;
      
      // Calculate individual habit streak
      let hStreak = 0;
      let hCheckDate = new Date(today);
      let hIsActive = false;
      
      const logToday = logs.find(l => l.date === today.toISOString().split('T')[0]);
      const logYesterday = logs.find(l => l.date === yesterday.toISOString().split('T')[0]);

      if (logToday?.status === 'done') {
        hIsActive = true;
      } else if (logYesterday?.status === 'done' && (!logToday || logToday.status === 'skipped')) {
        hIsActive = true;
        hCheckDate = yesterday;
      }

      if (hIsActive) {
        while (true) {
          const dateStr = hCheckDate.toISOString().split('T')[0];
          const log = logs.find(l => l.date === dateStr);
          if (log?.status === 'done') {
            hStreak++;
            hCheckDate.setDate(hCheckDate.getDate() - 1);
          } else if (log?.status === 'skipped') {
            // Skip days don't break streak, just move back
            hCheckDate.setDate(hCheckDate.getDate() - 1);
          } else {
            break;
          }
        }
      }

      return {
        name: hideHabitNames ? '***' : habit.title,
        rate: logs.length > 0 ? Math.round((done / logs.length) * 100) : 0,
        total: logs.length,
        streak: hStreak
      };
    }).filter(h => h.total > 0).sort((a, b) => b.rate - a.rate);

    const bestHabits = habitPerformance.slice(0, 4);
    const worstHabits = [...habitPerformance].reverse().slice(0, 4);

    // 7. PERFECT DAYS
    const perfectDaysCount = last30Days.filter(day => {
      const dayTasks = tasks.filter(t => t.date.startsWith(day.fullDate));
      if (dayTasks.length === 0) return false;
      return dayTasks.every(t => t.completed);
    }).length;

    // 8. 7-DAY HABIT TREND
    const last7DaysHabits = Array.from({ length: 7 }).map((_, i) => {
      const d = new Date();
      d.setDate(d.getDate() - (6 - i));
      const dateStr = d.toISOString().split('T')[0];
      
      const dayData: any = {
        name: d.toLocaleDateString('ru-RU', { weekday: 'short' }),
        fullDate: dateStr,
      };

      habits.forEach(habit => {
        const log = habitLogs.find(l => l.habitId === habit.id && l.date === dateStr);
        const key = hideHabitNames ? `*** (${habit.id.slice(0, 4)})` : habit.title;
        dayData[key] = log?.status === 'done' ? 100 : 0;
      });
      
      return dayData;
    });

    // 9. GOOD VS BAD HABITS
    const goodHabits = habits.filter(h => h.type === 'good');
    const badHabits = habits.filter(h => h.type === 'bad');

    const goodHabitLogs = habitLogs.filter(l => goodHabits.some(h => h.id === l.habitId));
    const badHabitLogs = habitLogs.filter(l => badHabits.some(h => h.id === l.habitId));

    const goodDone = goodHabitLogs.filter(l => l.status === 'done').length;
    const goodFailed = goodHabitLogs.filter(l => l.status === 'failed').length;
    const badDone = badHabitLogs.filter(l => l.status === 'done').length; // Resisted
    const badFailed = badHabitLogs.filter(l => l.status === 'failed').length; // Gave in

    const goodVsBadData = [
      { name: 'Хорошие (Сделано)', value: goodDone, fill: '#10b981' },
      { name: 'Хорошие (Пропущено)', value: goodFailed, fill: '#f43f5e' },
      { name: 'Вредные (Сдержался)', value: badDone, fill: '#3b82f6' },
      { name: 'Вредные (Сорвался)', value: badFailed, fill: '#f97316' },
    ].filter(d => d.value > 0);

    // 10. HABIT HEATMAP (Last 90 Days)
    const habitHeatmap = Array.from({ length: 90 }).map((_, i) => {
      const d = new Date();
      d.setDate(d.getDate() - (89 - i));
      const dateStr = d.toISOString().split('T')[0];
      const dayLogs = habitLogs.filter(l => l.date === dateStr);
      const doneCount = dayLogs.filter(l => l.status === 'done').length;
      return {
        date: dateStr,
        count: doneCount
      };
    });

    // 11. DETAILED HABIT STREAKS
    const detailedHabitStreaks = habits.map(habit => {
      const logs = habitLogs.filter(l => l.habitId === habit.id).sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
      
      let currentStreak = 0;
      let maxStreak = 0;
      
      const sortedLogs = [...logs].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
      if (sortedLogs.length > 0) {
        let streak = 0;
        for (let i = 0; i < sortedLogs.length; i++) {
          if (sortedLogs[i].status === 'done') {
            streak++;
            maxStreak = Math.max(maxStreak, streak);
          } else if (sortedLogs[i].status === 'failed') {
            streak = 0;
          }
        }
      }

      let checkDate = new Date(today);
      let isActive = false;
      const logToday = logs.find(l => l.date === today.toISOString().split('T')[0]);
      const logYesterday = logs.find(l => l.date === yesterday.toISOString().split('T')[0]);

      if (logToday?.status === 'done') {
        isActive = true;
      } else if (logYesterday?.status === 'done' && (!logToday || logToday.status === 'skipped')) {
        isActive = true;
        checkDate = yesterday;
      }

      if (isActive) {
        while (true) {
          const dateStr = checkDate.toISOString().split('T')[0];
          const log = logs.find(l => l.date === dateStr);
          if (log?.status === 'done') {
            currentStreak++;
            checkDate.setDate(checkDate.getDate() - 1);
          } else if (log?.status === 'skipped') {
            checkDate.setDate(checkDate.getDate() - 1);
          } else {
            break;
          }
        }
      }

      return {
        id: habit.id,
        name: hideHabitNames ? `*** (${habit.id.slice(0, 4)})` : habit.title,
        type: habit.type,
        currentStreak,
        maxStreak,
        totalDone: logs.filter(l => l.status === 'done').length
      };
    }).sort((a, b) => b.currentStreak - a.currentStreak);

    return {
      currentStreak, maxStreak,
      totalTasks, completedTasks, failedTasks, pendingTasks, taskCompletionRate, taskStatusPie,
      tasksBySphere, sphereBalance, bestSphere,
      shiftedTasksByDayOfWeek, mostProductiveDay,
      shiftedHabitsByDayOfWeek, bestHabitDay,
      last30Days, perfectDaysCount,
      totalHabitLogs, doneHabits, failedHabitLogs, skippedHabitLogs, habitCompletionRate,
      habitPerformance, bestHabits, worstHabits, last7DaysHabits,
      goodVsBadData, habitHeatmap, detailedHabitStreaks
    };
  }, [tasks, spheres, habits, habitLogs]);

  const {
    currentStreak, maxStreak,
    totalTasks, completedTasks, failedTasks, taskCompletionRate, taskStatusPie,
    tasksBySphere, sphereBalance, bestSphere,
    shiftedTasksByDayOfWeek, mostProductiveDay,
    shiftedHabitsByDayOfWeek, bestHabitDay,
    last30Days, perfectDaysCount,
    doneHabits, failedHabitLogs, skippedHabitLogs, habitCompletionRate,
    bestHabits, worstHabits, last7DaysHabits,
    goodVsBadData, habitHeatmap, detailedHabitStreaks
  } = analyticsData;

  return (
    <div className="space-y-8 pb-10">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-zinc-900 flex items-center gap-2">
            <BrainCircuit className="w-7 h-7 text-indigo-500" />
            Глубокая аналитика
          </h1>
          <p className="text-sm text-zinc-500 mt-1">Детальный разбор вашей продуктивности, трендов и привычек.</p>
        </div>
        <button
          onClick={handleAnalyze}
          disabled={isAnalyzing}
          className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-500 disabled:bg-indigo-600/50 text-zinc-900 rounded-xl text-sm font-medium transition-all shadow-lg shadow-indigo-500/20"
        >
          {isAnalyzing ? (
            <Loader2 className="w-4 h-4 animate-spin" />
          ) : (
            <Sparkles className="w-4 h-4" />
          )}
          {isAnalyzing ? 'Анализируем...' : 'Проанализировать неделю'}
        </button>
      </div>

      {analysisResult && (
        <div className="p-6 bg-indigo-500/10 border border-indigo-500/20 rounded-3xl relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
            <BrainCircuit className="w-24 h-24 text-indigo-400" />
          </div>
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-indigo-500/20 rounded-lg">
              <Sparkles className="w-5 h-5 text-indigo-400" />
            </div>
            <h3 className="text-lg font-bold text-zinc-900">AI Аналитик</h3>
            <button 
              onClick={() => setAnalysisResult(null)}
              className="ml-auto text-zinc-500 hover:text-zinc-700"
            >
              <XCircle className="w-5 h-5" />
            </button>
          </div>
          <div className="prose prose-invert prose-sm max-w-none text-zinc-700">
            <ReactMarkdown>{analysisResult}</ReactMarkdown>
          </div>
        </div>
      )}

      {/* SMART INSIGHTS */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-gradient-to-br from-indigo-500/10 to-purple-500/5 p-4 rounded-3xl border border-indigo-500/20 relative overflow-hidden">
          <div className="absolute -right-4 -top-4 opacity-10">
            <Zap className="w-20 h-20 text-indigo-500" />
          </div>
          <h3 className="text-[8px] font-medium text-indigo-400 mb-1 uppercase tracking-wider">Самый продуктивный день</h3>
          <p className="text-base font-bold text-zinc-900 mt-1">{mostProductiveDay?.name || 'Нет данных'}</p>
          <p className="text-[10px] text-indigo-300/80 mt-1">Успешность: {mostProductiveDay?.rate || 0}%</p>
        </div>

        <div className="bg-gradient-to-br from-emerald-500/10 to-teal-500/5 p-4 rounded-3xl border border-emerald-500/20 relative overflow-hidden">
          <div className="absolute -right-4 -top-4 opacity-10">
            <Award className="w-20 h-20 text-emerald-500" />
          </div>
          <h3 className="text-[8px] font-medium text-emerald-400 mb-1 uppercase tracking-wider">Лучшая сфера</h3>
          <p className="text-base font-bold text-zinc-900 mt-1 truncate">{bestSphere?.name || 'Нет данных'}</p>
          <p className="text-[10px] text-emerald-300/80 mt-1">Успешность: {bestSphere?.rate || 0}%</p>
        </div>

        <div className="bg-gradient-to-br from-amber-500/10 to-orange-500/5 p-4 rounded-3xl border border-amber-500/20 relative overflow-hidden">
          <div className="absolute -right-4 -top-4 opacity-10">
            <Trophy className="w-20 h-20 text-amber-500" />
          </div>
          <h3 className="text-[8px] font-medium text-amber-400 mb-1 uppercase tracking-wider">Идеальных дней (за 30 дн.)</h3>
          <p className="text-base font-bold text-zinc-900 mt-1">{perfectDaysCount}</p>
          <p className="text-[10px] text-amber-300/80 mt-1">Дни, когда выполнено 100% задач</p>
        </div>
      </div>

      {/* 30-DAY TREND */}
      <div className="bg-white p-6 rounded-3xl shadow-sm border border-stone-200">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="text-lg font-bold text-zinc-900">Активность за 30 дней</h2>
            <p className="text-xs text-zinc-500">Объем выполненных задач и привычек</p>
          </div>
          <div className="flex items-center gap-4 text-xs">
            <div className="flex items-center gap-1.5"><div className="w-3 h-3 rounded-full bg-indigo-500"></div> Задачи</div>
            <div className="flex items-center gap-1.5"><div className="w-3 h-3 rounded-full bg-emerald-500"></div> Привычки</div>
          </div>
        </div>
        <div className="h-72">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={last30Days} margin={{ top: 10, right: 0, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id="colorTasks" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#6366f1" stopOpacity={0.3}/>
                  <stop offset="95%" stopColor="#6366f1" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="colorHabits" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10b981" stopOpacity={0.3}/>
                  <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#27272a" />
              <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 10 }} minTickGap={20} />
              <YAxis axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 10 }} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '12px' }}
                itemStyle={{ color: '#fff' }}
              />
              <Area type="monotone" dataKey="tasks" name="Задачи" stroke="#6366f1" strokeWidth={2} fillOpacity={1} fill="url(#colorTasks)" />
              <Area type="monotone" dataKey="habits" name="Привычки" stroke="#10b981" strokeWidth={2} fillOpacity={1} fill="url(#colorHabits)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* OVERVIEW & STREAKS */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-gradient-to-br from-orange-500/10 to-orange-500/5 p-4 rounded-3xl shadow-sm border border-orange-500/20">
          <div className="flex items-center gap-2 mb-2">
            <div className="p-1.5 bg-orange-500/20 text-orange-500 rounded-lg">
              <Flame className="w-3 h-3" />
            </div>
            <h3 className="text-[8px] font-medium text-orange-500/80 uppercase tracking-wider">Текущий стрик</h3>
          </div>
          <p className="text-lg font-bold text-orange-500 mt-1">{currentStreak} <span className="text-[8px] font-normal text-orange-500/60 uppercase">дней</span></p>
        </div>
        
        <div className="bg-gradient-to-br from-yellow-500/10 to-yellow-500/5 p-4 rounded-3xl shadow-sm border border-yellow-500/20">
          <div className="flex items-center gap-2 mb-2">
            <div className="p-1.5 bg-yellow-500/20 text-yellow-500 rounded-lg">
              <Trophy className="w-3 h-3" />
            </div>
            <h3 className="text-[8px] font-medium text-yellow-500/80 uppercase tracking-wider">Лучший стрик</h3>
          </div>
          <p className="text-lg font-bold text-yellow-500 mt-1">{maxStreak} <span className="text-[8px] font-normal text-yellow-500/60 uppercase">дней</span></p>
        </div>

        <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
          <div className="flex items-center gap-2 mb-2">
            <div className="p-1.5 bg-stone-100 text-zinc-900 rounded-lg">
              <ListTodo className="w-3 h-3" />
            </div>
            <h3 className="text-[8px] font-medium text-zinc-500 uppercase tracking-wider">Всего задач</h3>
          </div>
          <p className="text-lg font-bold text-zinc-900 mt-1">{totalTasks}</p>
        </div>

        <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
          <div className="flex items-center gap-2 mb-2">
            <div className="p-1.5 bg-stone-100 text-zinc-900 rounded-lg">
              <Activity className="w-3 h-3" />
            </div>
            <h3 className="text-[8px] font-medium text-zinc-500 uppercase tracking-wider">Всего привычек</h3>
          </div>
          <p className="text-lg font-bold text-zinc-900 mt-1">{habits.length}</p>
        </div>
      </div>

      {/* TASKS DEEP DIVE */}
      <div className="space-y-4">
        <h2 className="text-lg font-bold tracking-tight text-zinc-900 flex items-center gap-2">
          <Target className="w-5 h-5 text-zinc-500" />
          Аналитика задач
        </h2>
        
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          {/* Status Donut */}
          <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200 flex flex-col">
            <h3 className="text-xs font-semibold text-zinc-900 mb-1">Статус задач</h3>
            <p className="text-[10px] text-zinc-500 mb-4">Общее распределение</p>
            <div className="flex-1 min-h-[160px] relative">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={taskStatusPie}
                    cx="50%"
                    cy="50%"
                    innerRadius={50}
                    outerRadius={70}
                    paddingAngle={5}
                    dataKey="value"
                    stroke="none"
                  >
                    {taskStatusPie.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip 
                    contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
                    itemStyle={{ color: '#fff' }}
                  />
                </PieChart>
              </ResponsiveContainer>
              <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                <span className="text-xl font-bold text-zinc-900">{taskCompletionRate}%</span>
                <span className="text-[9px] text-zinc-500 uppercase tracking-wider">Успех</span>
              </div>
            </div>
            <div className="flex justify-center gap-3 mt-4">
              {taskStatusPie.map((entry, i) => (
                <div key={i} className="flex items-center gap-1 text-[10px] text-zinc-500">
                  <div className="w-2 h-2 rounded-full" style={{ backgroundColor: entry.color }}></div>
                  {entry.name}
                </div>
              ))}
            </div>
          </div>

          {/* Day of Week Tasks */}
          <div className="lg:col-span-2 bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
            <h3 className="text-xs font-semibold text-zinc-900 mb-1">Продуктивность по дням недели (Задачи)</h3>
            <p className="text-[10px] text-zinc-500 mb-4">Процент успешного выполнения задач</p>
            <div className="h-48">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={shiftedTasksByDayOfWeek} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#27272a" />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 10 }} />
                  <YAxis axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 10 }} />
                  <Tooltip 
                    cursor={{ fill: '#27272a' }}
                    contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
                  />
                  <Bar dataKey="rate" name="Успешность (%)" fill="#6366f1" radius={[4, 4, 0, 0]}>
                    {shiftedTasksByDayOfWeek.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.rate === mostProductiveDay?.rate ? '#8b5cf6' : '#3f3f46'} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>

        {/* Day of Week Habits */}
        <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
          <h3 className="text-xs font-semibold text-zinc-900 mb-1 flex items-center gap-2">
            <Activity className="w-4 h-4 text-emerald-500" />
            Эффективность привычек по дням недели
          </h3>
          <p className="text-[10px] text-zinc-500 mb-4">Процент выполнения привычек по дням недели</p>
          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={shiftedHabitsByDayOfWeek} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorHabitDay" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#10b981" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#27272a" />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 10 }} />
                <YAxis axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 10 }} domain={[0, 100]} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
                />
                <Area type="monotone" dataKey="rate" name="Успешность (%)" stroke="#10b981" strokeWidth={2} fillOpacity={1} fill="url(#colorHabitDay)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Spheres Grouped Bar Chart */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
            <h3 className="text-xs font-semibold text-zinc-900 mb-1">Прогресс по сферам</h3>
            <p className="text-[10px] text-zinc-500 mb-4">Общее количество vs Выполненные задачи</p>
            <div className="h-56">
              {tasksBySphere.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={tasksBySphere} margin={{ top: 10, right: 10, left: -20, bottom: 0 }} barGap={8}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#27272a" />
                    <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 9 }} />
                    <YAxis axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 9 }} />
                    <Tooltip 
                      cursor={{ fill: '#27272a', opacity: 0.4 }}
                      contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
                    />
                    <Legend wrapperStyle={{ fontSize: '10px', color: '#a1a1aa', paddingTop: '10px' }} />
                    <Bar dataKey="total" name="Всего задач" fill="#3f3f46" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="completed" name="Выполнено" fill="#6366f1" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              ) : (
                <div className="h-full flex items-center justify-center text-zinc-500 text-xs">Нет данных</div>
              )}
            </div>
          </div>

          {sphereBalance.length > 2 && (
            <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
              <h3 className="text-xs font-semibold text-zinc-900 mb-1">Баланс сфер жизни</h3>
              <p className="text-[10px] text-zinc-500 mb-2">Радар успешности</p>
              <div className="h-56">
                <ResponsiveContainer width="100%" height="100%">
                  <RadarChart cx="50%" cy="50%" outerRadius="65%" data={sphereBalance}>
                    <PolarGrid stroke="#27272a" />
                    <PolarAngleAxis dataKey="subject" tick={{ fill: '#a1a1aa', fontSize: 9 }} />
                    <PolarRadiusAxis angle={30} domain={[0, 100]} tick={{ fill: '#52525b', fontSize: 8 }} />
                    <Radar name="Успешность (%)" dataKey="A" stroke="#8b5cf6" strokeWidth={2} fill="#8b5cf6" fillOpacity={0.3} />
                    <Tooltip 
                      contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
                    />
                  </RadarChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* HABITS DEEP DIVE */}
      <div className="space-y-4">
        <h2 className="text-lg font-bold tracking-tight text-zinc-900 flex items-center gap-2">
          <Activity className="w-5 h-5 text-zinc-500" />
          Аналитика привычек
        </h2>
        
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
            <h3 className="text-[10px] font-medium text-zinc-500 mb-1">Успешность</h3>
            <p className="text-xl font-bold text-zinc-900">{habitCompletionRate}%</p>
          </div>
          <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
            <h3 className="text-[10px] font-medium text-zinc-500 mb-1">Выполнено</h3>
            <p className="text-xl font-bold text-emerald-500">{doneHabits}</p>
          </div>
          <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
            <h3 className="text-[10px] font-medium text-zinc-500 mb-1">Провалено</h3>
            <p className="text-xl font-bold text-red-500">{failedHabitLogs}</p>
          </div>
          <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
            <h3 className="text-[10px] font-medium text-zinc-500 mb-1">Пропущено</h3>
            <p className="text-xl font-bold text-zinc-500">{skippedHabitLogs}</p>
          </div>
        </div>

        {/* Habit Heatmap */}
        <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200 overflow-hidden">
          <h3 className="text-xs font-semibold text-zinc-900 mb-1 flex items-center gap-2">
            <Calendar className="w-3.5 h-3.5 text-indigo-500" />
            Календарь активности (90 дней)
          </h3>
          <p className="text-[10px] text-zinc-500 mb-4">Интенсивность выполнения привычек</p>
          <div className="flex gap-1 overflow-x-auto pb-2 scrollbar-hide">
            {habitHeatmap.map((day, i) => {
              let colorClass = "bg-stone-50 border border-stone-200";
              if (day.count > 0) {
                if (day.count <= 1) colorClass = "bg-emerald-900/50 border border-emerald-900";
                else if (day.count <= 3) colorClass = "bg-emerald-700/50 border border-emerald-700";
                else if (day.count <= 5) colorClass = "bg-emerald-500 border border-emerald-600";
                else colorClass = "bg-emerald-400 border border-emerald-500";
              }
              return (
                <div 
                  key={i} 
                  className={cn("w-3 h-3 rounded-sm shrink-0", colorClass)}
                  title={`${new Date(day.date).toLocaleDateString('ru-RU')}: ${day.count} привычек`}
                />
              );
            })}
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {/* Good vs Bad Habits */}
          {goodVsBadData.length > 0 && (
            <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
              <h3 className="text-xs font-semibold text-zinc-900 mb-1">Хорошие vs Вредные</h3>
              <p className="text-[10px] text-zinc-500 mb-4">Соотношение успешных и проваленных привычек</p>
              <div className="h-56">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={goodVsBadData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={80}
                      paddingAngle={5}
                      dataKey="value"
                    >
                      {goodVsBadData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.fill} />
                      ))}
                    </Pie>
                    <Tooltip 
                      contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
                    />
                    <Legend wrapperStyle={{ fontSize: '10px', color: '#a1a1aa' }} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}

          {/* 7-Day Habit Trend */}
          <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
            <h3 className="text-xs font-semibold text-zinc-900 mb-1">Динамика привычек (7 дней)</h3>
            <p className="text-[10px] text-zinc-500 mb-4">Процент выполнения по дням</p>
            <div className="h-56">
              {habits.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={last7DaysHabits} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#27272a" />
                    <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 10 }} />
                    <YAxis axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 10 }} domain={[0, 100]} />
                    <Tooltip 
                      contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
                    />
                    <Legend wrapperStyle={{ fontSize: '10px', color: '#a1a1aa' }} />
                    {habits.map((habit, i) => {
                      const colors = ['#6366f1', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#06b6d4'];
                      const key = hideHabitNames ? `*** (${habit.id.slice(0, 4)})` : habit.title;
                      return (
                        <Line key={habit.id} type="monotone" dataKey={key} name={key} stroke={colors[i % colors.length]} strokeWidth={2} dot={{ r: 3 }} />
                      );
                    })}
                  </LineChart>
                </ResponsiveContainer>
              ) : (
                <div className="h-full flex items-center justify-center text-zinc-500 text-xs">Нет привычек</div>
              )}
            </div>
          </div>
        </div>

        {/* Streak Leaderboard */}
        <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
          <h3 className="text-xs font-semibold text-zinc-900 mb-1 flex items-center gap-2">
            <Flame className="w-3.5 h-3.5 text-orange-500" />
            Рекорды (Стрики)
          </h3>
          <p className="text-[10px] text-zinc-500 mb-4">Самые длинные серии выполнения</p>
          <div className="space-y-3">
            {detailedHabitStreaks.length > 0 ? detailedHabitStreaks.map((h, i) => (
              <div key={h.id} className="flex items-center justify-between p-3 rounded-2xl bg-stone-100/60 border border-stone-200">
                <div className="flex items-center gap-3 overflow-hidden">
                  <div className={cn(
                    "w-8 h-8 rounded-full flex items-center justify-center font-bold text-[10px] shrink-0",
                    i === 0 ? "bg-orange-500/20 text-orange-500" :
                    i === 1 ? "bg-zinc-300/20 text-zinc-700" :
                    i === 2 ? "bg-amber-700/20 text-amber-700" :
                    "bg-stone-200/20 text-zinc-500"
                  )}>
                    #{i + 1}
                  </div>
                  <div>
                    <span className="text-xs font-medium text-zinc-900 truncate block">{h.name}</span>
                    <span className="text-[9px] text-zinc-500 uppercase tracking-wider">
                      {h.type === 'good' ? 'Хорошая' : 'Вредная'} • Всего: {h.totalDone}
                    </span>
                  </div>
                </div>
                <div className="flex items-center gap-4 shrink-0 text-right">
                  <div>
                    <div className="text-xs font-bold text-orange-500 flex items-center justify-end gap-1">
                      <Flame className="w-3 h-3" /> {h.currentStreak}
                    </div>
                    <div className="text-[9px] text-zinc-500 uppercase tracking-wider">Текущий</div>
                  </div>
                  <div>
                    <div className="text-xs font-bold text-zinc-700 flex items-center justify-end gap-1">
                      <Trophy className="w-3 h-3" /> {h.maxStreak}
                    </div>
                    <div className="text-[9px] text-zinc-500 uppercase tracking-wider">Максимум</div>
                  </div>
                </div>
              </div>
            )) : (
              <p className="text-[10px] text-zinc-600 italic text-center py-4">Нет данных о привычках</p>
            )}
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {/* Best Habits */}
          <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
            <h3 className="text-xs font-semibold text-zinc-900 mb-1 flex items-center gap-2">
              <TrendingUp className="w-3.5 h-3.5 text-emerald-500" />
              Топ привычек
            </h3>
            <p className="text-[10px] text-zinc-500 mb-4">Самые стабильные привычки</p>
            
            <div className="space-y-3">
              {bestHabits.length > 0 ? bestHabits.map((h, i) => (
                <div key={i} className="flex items-center justify-between p-2.5 rounded-2xl bg-stone-100/60 border border-stone-200">
                  <div className="flex items-center gap-2.5 overflow-hidden">
                    <div className="w-6 h-6 rounded-full bg-emerald-500/10 text-emerald-500 flex items-center justify-center font-bold text-[10px] shrink-0">
                      #{i + 1}
                    </div>
                    <span className="text-xs text-zinc-900 truncate">{h.name}</span>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    {h.streak > 0 && (
                      <div className="flex items-center gap-1 text-orange-500 bg-orange-500/10 px-1.5 py-0.5 rounded-lg text-[10px] font-medium">
                        <Flame className="w-2.5 h-2.5" />
                        {h.streak}
                      </div>
                    )}
                    <span className="text-xs font-bold text-emerald-500 w-10 text-right">{h.rate}%</span>
                  </div>
                </div>
              )) : (
                <p className="text-xs text-zinc-500 text-center py-4">Нет данных</p>
              )}
            </div>
          </div>

          {/* Worst Habits */}
          <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
            <h3 className="text-xs font-semibold text-zinc-900 mb-1 flex items-center gap-2">
              <AlertTriangle className="w-3.5 h-3.5 text-red-500" />
              Требуют внимания
            </h3>
            <p className="text-[10px] text-zinc-500 mb-4">Привычки с низким процентом выполнения</p>
            
            <div className="space-y-3">
              {worstHabits.length > 0 ? worstHabits.map((h, i) => (
                <div key={i} className="flex items-center justify-between p-2.5 rounded-2xl bg-stone-100/60 border border-stone-200">
                  <div className="flex items-center gap-2.5 overflow-hidden">
                    <div className="w-6 h-6 rounded-full bg-red-500/10 text-red-500 flex items-center justify-center font-bold text-[10px] shrink-0">
                      !
                    </div>
                    <span className="text-xs text-zinc-900 truncate">{h.name}</span>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <span className="text-xs font-bold text-red-500 w-10 text-right">{h.rate}%</span>
                  </div>
                </div>
              )) : (
                <p className="text-xs text-zinc-500 text-center py-4">Нет данных</p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
