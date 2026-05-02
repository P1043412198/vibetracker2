import { useMemo } from 'react';
import { format, subDays, addDays, startOfDay, parseISO, differenceInCalendarDays, isWithinInterval } from 'date-fns';
import { ru } from 'date-fns/locale';
import { useStore } from '../store/useStore';

export function useDashboardStats(currentDate: Date) {
  const { 
    tasks, habits, habitLogs, exerciseLogs, workoutNodes, 
    bodyMeasurements, transactions, accounts, budgetLimits, 
    goals, spheres, workSchedule 
  } = useStore();

  const dateStr = format(currentDate, 'yyyy-MM-dd');

  // 30-DAY TREND (Area Chart)
  const last30Days = useMemo(() => {
    return Array.from({ length: 30 }).map((_, i) => {
      const d = new Date();
      d.setDate(d.getDate() - (29 - i));
      const dateStr = d.toISOString().split('T')[0];
      
      const dayTasks = tasks.filter(t => t.date.startsWith(dateStr));
      const dayHabits = habitLogs.filter(l => l.date === dateStr);
      const dayWorkouts = (exerciseLogs || []).filter(l => l.date === dateStr);
      const dayMeasurements = (bodyMeasurements || []).find(m => m.date === dateStr);
      
      const completedT = dayTasks.filter(t => t.completed).length;
      const doneH = dayHabits.filter(l => l.status === 'done').length;
      
      return {
        date: d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' }),
        fullDate: dateStr,
        tasks: completedT,
        habits: doneH,
        workouts: dayWorkouts.length,
        weight: dayMeasurements?.weight,
        totalActivity: completedT + doneH + dayWorkouts.length,
      };
    });
  }, [tasks, habitLogs, exerciseLogs, bodyMeasurements]);

  const recentWorkout = useMemo(() => {
    if (!exerciseLogs || exerciseLogs.length === 0) return null;
    const sortedLogs = [...exerciseLogs].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
    const lastLog = sortedLogs[0];
    const exercise = workoutNodes.find(n => n.id === lastLog.exerciseId);
    return { ...lastLog, exerciseName: exercise?.name || 'Упражнение' };
  }, [exerciseLogs, workoutNodes]);

  const habitStreaks = useMemo(() => {
    return habits.map(h => {
      const logs = habitLogs
        .filter(l => l.habitId === h.id && l.status === 'done')
        .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
      
      if (logs.length === 0) return { id: h.id, title: h.title, streak: 0 };
      
      let streak = 0;
      let checkDate = startOfDay(new Date());
      
      const doneToday = logs.some(l => l.date === format(checkDate, 'yyyy-MM-dd'));
      const doneYesterday = logs.some(l => l.date === format(subDays(checkDate, 1), 'yyyy-MM-dd'));
      
      if (!doneToday && !doneYesterday) {
        streak = 0;
      } else {
        let tempDate = doneToday ? checkDate : subDays(checkDate, 1);
        while (true) {
          const dateStr = format(tempDate, 'yyyy-MM-dd');
          if (logs.some(l => l.date === dateStr)) {
            streak++;
            tempDate = subDays(tempDate, 1);
          } else {
            break;
          }
        }
      }
      return { id: h.id, title: h.title, streak };
    }).sort((a, b) => b.streak - a.streak).slice(0, 3);
  }, [habits, habitLogs]);

  const financeStats = useMemo(() => {
    const totalBalance = (accounts || []).reduce((acc, curr) => acc + (curr.initialBalance || 0), 0);
    const monthStart = format(new Date(new Date().getFullYear(), new Date().getMonth(), 1), 'yyyy-MM-dd');
    const monthExpenses = (transactions || [])
      .filter(t => t.type === 'expense' && t.date >= monthStart)
      .reduce((acc, curr) => acc + curr.amount, 0);
    
    const budgetTotal = (budgetLimits || []).reduce((acc, curr) => acc + curr.amount, 0);
    const budgetProgress = budgetTotal > 0 ? (monthExpenses / budgetTotal) * 100 : 0;

    return { totalBalance, monthExpenses, budgetProgress, budgetTotal };
  }, [accounts, transactions, budgetLimits]);

  const upcomingDeadlines = useMemo(() => {
    const now = new Date();
    const next7Days = addDays(now, 7);
    
    const taskDeadlines = tasks
      .filter(t => !t.completed && !t.failed && t.date >= format(now, 'yyyy-MM-dd') && t.date <= format(next7Days, 'yyyy-MM-dd'))
      .map(t => ({ id: t.id, title: t.title, date: t.date, type: 'task' as const }));
      
    const goalDeadlines = goals
      .filter(g => g.status !== 'completed' && g.deadline && g.deadline >= format(now, 'yyyy-MM-dd') && g.deadline <= format(next7Days, 'yyyy-MM-dd'))
      .map(g => ({ id: g.id, title: g.title, date: g.deadline!, type: 'goal' as const }));
      
    return [...taskDeadlines, ...goalDeadlines].sort((a, b) => a.date.localeCompare(b.date));
  }, [tasks, goals]);

  const habitMatrix = useMemo(() => {
    const last7Days = Array.from({ length: 7 }).map((_, i) => {
      const d = subDays(new Date(), 6 - i);
      return format(d, 'yyyy-MM-dd');
    });

    return habits.map(h => {
      const logs = last7Days.map(date => {
        const log = habitLogs.find(l => l.habitId === h.id && l.date === date);
        return { date, status: log?.status || 'none' };
      });
      return { id: h.id, title: h.title, icon: h.icon, logs };
    });
  }, [habits, habitLogs]);

  const sphereBalance = useMemo(() => {
    return spheres.map(s => {
      const sphereTasks = tasks.filter(t => t.sphereId === s.id);
      const completed = sphereTasks.filter(t => t.completed).length;
      const score = sphereTasks.length > 0 ? (completed / sphereTasks.length) * 100 : 0;
      return { name: s.title, score };
    });
  }, [spheres, tasks]);

  const efficiencyStats = useMemo(() => {
    const calculateDayEfficiency = (date: Date) => {
      const dStr = format(date, 'yyyy-MM-dd');
      const dayTasks = tasks.filter(t => t.date.startsWith(dStr) || (t.period === 'day' && t.date <= dStr && !t.completed && !t.failed));
      const dayHabitLogs = habitLogs.filter(l => l.date === dStr);
      
      const tTotal = dayTasks.length;
      const tCompleted = dayTasks.filter(t => t.completed).length;
      const tProgress = tTotal > 0 ? (tCompleted / tTotal) * 100 : 0;
      
      const goodH = habits.filter(h => h.type === 'good');
      const badH = habits.filter(h => h.type === 'bad');
      
      const ghDone = goodH.filter(h => dayHabitLogs.find(l => l.habitId === h.id && l.status === 'done')).length;
      const ghProgress = goodH.length > 0 ? (ghDone / goodH.length) * 100 : 0;
      
      const bhResisted = badH.filter(h => dayHabitLogs.find(l => l.habitId === h.id && l.status === 'done')).length;
      const bhProgress = badH.length > 0 ? (bhResisted / badH.length) * 100 : 0;
      
      let comps = 0;
      let score = 0;
      if (tTotal > 0) { score += tProgress; comps++; }
      if (goodH.length > 0) { score += ghProgress; comps++; }
      if (badH.length > 0) { score += bhProgress; comps++; }
      
      return comps > 0 ? score / comps : 0;
    };

    const last7DaysEffData = Array.from({ length: 7 }).map((_, i) => {
      const date = subDays(new Date(), 6 - i);
      return {
        date: format(date, 'EE', { locale: ru }),
        fullDate: format(date, 'yyyy-MM-dd'),
        efficiency: Math.round(calculateDayEfficiency(date))
      };
    });

    const last30DaysEffData = Array.from({ length: 30 }).map((_, i) => {
      const date = subDays(new Date(), 29 - i);
      return {
        date: format(date, 'd MMM', { locale: ru }),
        fullDate: format(date, 'yyyy-MM-dd'),
        efficiency: Math.round(calculateDayEfficiency(date))
      };
    });

    const weeklyAvg = Math.round(last7DaysEffData.reduce((a, b) => a + b.efficiency, 0) / 7);
    const monthlyAvg = Math.round(last30DaysEffData.reduce((a, b) => a + b.efficiency, 0) / 30);

    return { weeklyAvg, monthlyAvg, last7DaysEffData, last30DaysEffData };
  }, [tasks, habits, habitLogs]);

  const todaysTasks = tasks.filter(t => t.date.startsWith(dateStr) || (t.period === 'day' && t.date <= dateStr && !t.completed && !t.failed));

  const tasksBySphere = useMemo(() => {
    const sphereCount: Record<string, { name: string, total: number, completed: number, color: string }> = {};
    
    sphereCount['none'] = { name: 'Без сферы', total: 0, completed: 0, color: '#71717a' };
    
    spheres.forEach(s => {
      sphereCount[s.id] = { name: s.title, total: 0, completed: 0, color: s.color || '#6366f1' };
    });

    todaysTasks.forEach(t => {
      const sId = t.sphereId || 'none';
      if (sphereCount[sId]) {
        sphereCount[sId].total++;
        if (t.completed) sphereCount[sId].completed++;
      }
    });

    return Object.values(sphereCount).filter(s => s.total > 0);
  }, [todaysTasks, spheres]);

  const tasksByStatus = useMemo(() => {
    const completed = todaysTasks.filter(t => t.completed).length;
    const failed = todaysTasks.filter(t => t.failed).length;
    const pending = todaysTasks.length - completed - failed;
    return [
      { name: 'Выполнено', value: completed, color: '#10b981' },
      { name: 'Провалено', value: failed, color: '#ef4444' },
      { name: 'В процессе', value: pending, color: '#6366f1' },
    ].filter(s => s.value > 0);
  }, [todaysTasks]);

  const getShiftForDate = (date: Date) => {
    if (!workSchedule) return null;

    const vacation = workSchedule.vacations?.find(v => 
      isWithinInterval(startOfDay(date), { 
        start: startOfDay(parseISO(v.startDate)), 
        end: startOfDay(parseISO(v.endDate)) 
      })
    );
    if (vacation) return 'vacation';

    const anchor = startOfDay(parseISO(workSchedule.anchorDate));
    const target = startOfDay(date);
    const diff = differenceInCalendarDays(target, anchor);
    const cycleLength = workSchedule.cycle.length;
    const index = ((diff % cycleLength) + cycleLength) % cycleLength;
    return workSchedule.cycle[index];
  };

  const currentShift = getShiftForDate(currentDate);

  return {
    last30Days,
    recentWorkout,
    habitStreaks,
    financeStats,
    upcomingDeadlines,
    habitMatrix,
    sphereBalance,
    efficiencyStats,
    tasksBySphere,
    tasksByStatus,
    currentShift,
    todaysTasks
  };
}
