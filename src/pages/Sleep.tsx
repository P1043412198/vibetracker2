import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Moon, Plus, Trash2, Star, TrendingUp, AlertCircle, Clock, Calendar, BarChart3, List, BedDouble, Sun, ChevronLeft, ChevronRight } from 'lucide-react';
import { format, subDays, isSameDay, parseISO, startOfWeek, endOfWeek, startOfMonth, endOfMonth, isWithinInterval, eachDayOfInterval, subMonths } from 'date-fns';
import { ru } from 'date-fns/locale';
import { useStore } from '../store/useStore';
import { cn } from '../lib/utils';
import { AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, RadarChart, PolarGrid, PolarAngleAxis, Radar } from 'recharts';

type Tab = 'log' | 'history' | 'analytics';

export function Sleep() {
  const { sleepLogs, logSleep, deleteSleepLog } = useStore();
  const [activeTab, setActiveTab] = useState<Tab>('log');

  return (
    <div className="space-y-6 pb-24">
      <header>
        <h1 className="text-xl font-bold text-zinc-900 mb-2">Сон</h1>
        <p className="text-zinc-500">Отслеживание сна и восстановления</p>
      </header>

      <div className="grid grid-cols-3 gap-1 bg-white/60 p-1 rounded-xl">
        <button
          onClick={() => setActiveTab('log')}
          className={cn(
            "flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-2 py-2 rounded-lg text-[10px] sm:text-sm font-medium transition-all",
            activeTab === 'log' ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-800"
          )}
        >
          <BedDouble className="w-4 h-4" />
          <span>Запись</span>
        </button>
        <button
          onClick={() => setActiveTab('history')}
          className={cn(
            "flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-2 py-2 rounded-lg text-[10px] sm:text-sm font-medium transition-all",
            activeTab === 'history' ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-800"
          )}
        >
          <List className="w-4 h-4" />
          <span>История</span>
        </button>
        <button
          onClick={() => setActiveTab('analytics')}
          className={cn(
            "flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-2 py-2 rounded-lg text-[10px] sm:text-sm font-medium transition-all",
            activeTab === 'analytics' ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-800"
          )}
        >
          <BarChart3 className="w-4 h-4" />
          <span>Аналитика</span>
        </button>
      </div>

      <motion.div
        key={activeTab}
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.2 }}
      >
        {activeTab === 'log' && <LogTab />}
        {activeTab === 'history' && <HistoryTab />}
        {activeTab === 'analytics' && <AnalyticsTab />}
      </motion.div>
    </div>
  );
}

function LogTab() {
  const { sleepLogs, logSleep } = useStore();
  const [bedtime, setBedtime] = useState('23:00');
  const [wakeTime, setWakeTime] = useState('07:00');
  const [quality, setQuality] = useState(3);
  const [notes, setNotes] = useState('');
  const [selectedDate, setSelectedDate] = useState(format(new Date(), 'yyyy-MM-dd'));

  const calcHours = useMemo(() => {
    const [bh, bm] = bedtime.split(':').map(Number);
    const [wh, wm] = wakeTime.split(':').map(Number);
    let diff = (wh * 60 + wm) - (bh * 60 + bm);
    if (diff <= 0) diff += 24 * 60;
    return Math.round((diff / 60) * 10) / 10;
  }, [bedtime, wakeTime]);

  const todayLog = sleepLogs.find(l => l.date === selectedDate);

  const readinessScore = useMemo(() => {
    const recentLogs = sleepLogs.slice(-7);
    if (recentLogs.length === 0) return 0;
    const avgHours = recentLogs.reduce((acc, l) => acc + l.hours, 0) / recentLogs.length;
    const avgQuality = recentLogs.reduce((acc, l) => acc + l.quality, 0) / recentLogs.length;
    return Math.min(100, Math.round((avgHours / 8) * 60 + (avgQuality / 5) * 40));
  }, [sleepLogs]);

  const last7 = useMemo(() => {
    return Array.from({ length: 7 }, (_, i) => {
      const date = subDays(new Date(), i);
      const log = sleepLogs.find(l => isSameDay(parseISO(l.date), date));
      return {
        date: format(date, 'dd.MM', { locale: ru }),
        hours: log?.hours || 0,
        quality: log?.quality || 0,
      };
    }).reverse();
  }, [sleepLogs]);

  const handleSave = () => {
    logSleep({
      date: selectedDate,
      hours: calcHours,
      quality: quality as 1 | 2 | 3 | 4 | 5,
      notes: notes || undefined,
      bedtime,
      wakeTime,
    });
    setNotes('');
  };

  const qualityLabels = ['', 'Ужасно', 'Плохо', 'Нормально', 'Хорошо', 'Отлично'];
  const qualityColors = ['', 'text-rose-500', 'text-orange-500', 'text-amber-500', 'text-emerald-500', 'text-indigo-500'];

  return (
    <div className="space-y-4">
      {/* Stats Cards */}
      <div className="grid grid-cols-3 gap-3">
        <div className="bg-white p-3 rounded-2xl border border-stone-200">
          <div className="flex items-center gap-1.5 mb-1">
            <TrendingUp className="w-3 h-3 text-emerald-500" />
            <span className="text-[10px] text-zinc-500 uppercase font-bold">Готовность</span>
          </div>
          <span className="text-lg font-bold text-zinc-900">{readinessScore}%</span>
        </div>
        <div className="bg-white p-3 rounded-2xl border border-stone-200">
          <div className="flex items-center gap-1.5 mb-1">
            <Moon className="w-3 h-3 text-indigo-500" />
            <span className="text-[10px] text-zinc-500 uppercase font-bold">Средний</span>
          </div>
          <span className="text-lg font-bold text-zinc-900">
            {sleepLogs.length > 0
              ? (sleepLogs.reduce((a, l) => a + l.hours, 0) / sleepLogs.length).toFixed(1)
              : '0'}ч
          </span>
        </div>
        <div className="bg-white p-3 rounded-2xl border border-stone-200">
          <div className="flex items-center gap-1.5 mb-1">
            <Star className="w-3 h-3 text-amber-500" />
            <span className="text-[10px] text-zinc-500 uppercase font-bold">Качество</span>
          </div>
          <span className="text-lg font-bold text-zinc-900">
            {sleepLogs.length > 0
              ? (sleepLogs.reduce((a, l) => a + l.quality, 0) / sleepLogs.length).toFixed(1)
              : '0'}/5
          </span>
        </div>
      </div>

      {/* Mini chart */}
      <div className="bg-white p-4 rounded-2xl border border-stone-200">
        <h3 className="text-xs font-bold text-zinc-500 uppercase mb-3">Последние 7 дней</h3>
        <div className="h-24 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={last7}>
              <defs>
                <linearGradient id="sleepGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#6366f1" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#6366f1" stopOpacity={0} />
                </linearGradient>
              </defs>
              <Area type="monotone" dataKey="hours" stroke="#6366f1" fill="url(#sleepGrad)" strokeWidth={2} />
              <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fontSize: 8, fill: '#71717a' }} />
              <YAxis hide domain={[0, 12]} />
              <Tooltip
                contentStyle={{ backgroundColor: '#fff', border: '1px solid #e4e4e7', borderRadius: '12px', fontSize: '10px' }}
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Log Form */}
      <div className="bg-white p-5 rounded-2xl border border-stone-200 space-y-5">
        <h3 className="text-sm font-bold text-zinc-900 flex items-center gap-2">
          <Moon className="w-4 h-4 text-indigo-500" />
          Записать сон
        </h3>

        <div>
          <label className="text-[10px] text-zinc-500 uppercase font-bold mb-2 block">Дата</label>
          <input
            type="date"
            value={selectedDate}
            onChange={(e) => setSelectedDate(e.target.value)}
            className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/30"
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="text-[10px] text-zinc-500 uppercase font-bold mb-2 flex items-center gap-1">
              <Moon className="w-3 h-3" /> Лёг спать
            </label>
            <input
              type="time"
              value={bedtime}
              onChange={(e) => setBedtime(e.target.value)}
              className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/30"
            />
          </div>
          <div>
            <label className="text-[10px] text-zinc-500 uppercase font-bold mb-2 flex items-center gap-1">
              <Sun className="w-3 h-3" /> Проснулся
            </label>
            <input
              type="time"
              value={wakeTime}
              onChange={(e) => setWakeTime(e.target.value)}
              className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/30"
            />
          </div>
        </div>

        <div className="bg-indigo-50 p-3 rounded-xl border border-indigo-100 text-center">
          <span className="text-xs text-zinc-500">Продолжительность:</span>
          <span className="ml-2 text-lg font-bold text-indigo-600">{calcHours}ч</span>
        </div>

        <div>
          <label className="text-[10px] text-zinc-500 uppercase font-bold mb-2 block">
            Качество сна: <span className={cn("capitalize", qualityColors[quality])}>{qualityLabels[quality]}</span>
          </label>
          <div className="flex gap-2">
            {[1, 2, 3, 4, 5].map(q => (
              <button
                key={q}
                onClick={() => setQuality(q)}
                className={cn(
                  "flex-1 py-2 rounded-xl border transition-all text-sm font-medium",
                  quality === q
                    ? "bg-indigo-500 text-white border-indigo-500 shadow-md shadow-indigo-500/30"
                    : "bg-stone-50 text-zinc-500 border-stone-200 hover:text-zinc-700 hover:border-stone-300"
                )}
              >
                {q}
              </button>
            ))}
          </div>
        </div>

        <div>
          <label className="text-[10px] text-zinc-500 uppercase font-bold mb-2 block">Заметки</label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Сны, ощущения, что повлияло на сон..."
            rows={2}
            className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm resize-none focus:outline-none focus:ring-2 focus:ring-indigo-500/30"
          />
        </div>

        <button
          onClick={handleSave}
          className="w-full py-3 bg-indigo-500 text-white rounded-xl font-bold text-sm hover:bg-indigo-600 transition-colors shadow-md shadow-indigo-500/30"
        >
          {todayLog ? 'Обновить запись' : 'Сохранить'}
        </button>

        {todayLog && (
          <p className="text-[10px] text-zinc-400 text-center">
            Уже есть запись за {format(parseISO(selectedDate), 'd MMMM', { locale: ru })} — {todayLog.hours}ч, качество {todayLog.quality}/5
          </p>
        )}
      </div>

      {readinessScore > 0 && readinessScore < 60 && (
        <div className="flex items-start gap-2 p-3 bg-rose-50 rounded-xl border border-rose-100">
          <AlertCircle className="w-4 h-4 text-rose-500 shrink-0 mt-0.5" />
          <p className="text-xs text-rose-600 leading-tight">
            Низкий уровень восстановления. Рекомендуется снизить интенсивность тренировок.
          </p>
        </div>
      )}
    </div>
  );
}

function HistoryTab() {
  const { sleepLogs, deleteSleepLog } = useStore();
  const [monthOffset, setMonthOffset] = useState(0);

  const currentMonth = subMonths(new Date(), monthOffset);
  const monthStart = startOfMonth(currentMonth);
  const monthEnd = endOfMonth(currentMonth);

  const filteredLogs = useMemo(() => {
    return sleepLogs
      .filter(l => {
        const d = parseISO(l.date);
        return isWithinInterval(d, { start: monthStart, end: monthEnd });
      })
      .sort((a, b) => b.date.localeCompare(a.date));
  }, [sleepLogs, monthStart, monthEnd]);

  const monthStats = useMemo(() => {
    if (filteredLogs.length === 0) return { avg: 0, avgQuality: 0, total: 0, best: 0, worst: 12 };
    const hours = filteredLogs.map(l => l.hours);
    return {
      avg: hours.reduce((a, b) => a + b, 0) / hours.length,
      avgQuality: filteredLogs.reduce((a, l) => a + l.quality, 0) / filteredLogs.length,
      total: filteredLogs.length,
      best: Math.max(...hours),
      worst: Math.min(...hours),
    };
  }, [filteredLogs]);

  const qualityEmoji = (q: number) => {
    const emojis = ['', '😫', '😕', '😐', '😊', '😴'];
    return emojis[q] || '';
  };

  return (
    <div className="space-y-4">
      {/* Month nav */}
      <div className="flex items-center justify-between bg-white p-3 rounded-2xl border border-stone-200">
        <button onClick={() => setMonthOffset(monthOffset + 1)} className="p-2 hover:bg-stone-100 rounded-xl transition-colors">
          <ChevronLeft className="w-4 h-4 text-zinc-500" />
        </button>
        <span className="text-sm font-bold text-zinc-900 capitalize">
          {format(currentMonth, 'LLLL yyyy', { locale: ru })}
        </span>
        <button
          onClick={() => setMonthOffset(Math.max(0, monthOffset - 1))}
          disabled={monthOffset === 0}
          className="p-2 hover:bg-stone-100 rounded-xl transition-colors disabled:opacity-30"
        >
          <ChevronRight className="w-4 h-4 text-zinc-500" />
        </button>
      </div>

      {/* Month stats */}
      <div className="grid grid-cols-4 gap-2">
        <div className="bg-white p-3 rounded-2xl border border-stone-200 text-center">
          <span className="text-[9px] text-zinc-500 uppercase font-bold block">Записей</span>
          <span className="text-base font-bold text-zinc-900">{monthStats.total}</span>
        </div>
        <div className="bg-white p-3 rounded-2xl border border-stone-200 text-center">
          <span className="text-[9px] text-zinc-500 uppercase font-bold block">Средний</span>
          <span className="text-base font-bold text-zinc-900">{monthStats.avg.toFixed(1)}ч</span>
        </div>
        <div className="bg-white p-3 rounded-2xl border border-stone-200 text-center">
          <span className="text-[9px] text-zinc-500 uppercase font-bold block">Макс</span>
          <span className="text-base font-bold text-emerald-600">{monthStats.best.toFixed(1)}ч</span>
        </div>
        <div className="bg-white p-3 rounded-2xl border border-stone-200 text-center">
          <span className="text-[9px] text-zinc-500 uppercase font-bold block">Мин</span>
          <span className="text-base font-bold text-rose-500">{filteredLogs.length > 0 ? monthStats.worst.toFixed(1) : '0'}ч</span>
        </div>
      </div>

      {/* Log list */}
      <div className="space-y-2">
        <AnimatePresence>
          {filteredLogs.length === 0 ? (
            <div className="bg-white p-8 rounded-2xl border border-stone-200 text-center">
              <Moon className="w-8 h-8 text-zinc-300 mx-auto mb-3" />
              <p className="text-sm text-zinc-400">Нет записей за этот месяц</p>
            </div>
          ) : (
            filteredLogs.map((log) => (
              <motion.div
                key={log.id}
                layout
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, x: -50 }}
                className="bg-white p-4 rounded-2xl border border-stone-200"
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-sm font-bold text-zinc-900">
                        {format(parseISO(log.date), 'd MMMM, EEEEEE', { locale: ru })}
                      </span>
                      <span className="text-base">{qualityEmoji(log.quality)}</span>
                    </div>
                    <div className="flex items-center gap-3 text-xs text-zinc-500">
                      <span className="flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        {log.hours}ч
                      </span>
                      <span className="flex items-center gap-1">
                        <Star className="w-3 h-3 text-amber-400" />
                        {log.quality}/5
                      </span>
                      {log.bedtime && log.wakeTime && (
                        <span className="flex items-center gap-1">
                          <Moon className="w-3 h-3" />
                          {log.bedtime} — {log.wakeTime}
                        </span>
                      )}
                    </div>
                    {log.notes && (
                      <p className="text-[11px] text-zinc-400 mt-1.5 leading-snug">{log.notes}</p>
                    )}
                  </div>
                  <button
                    onClick={() => deleteSleepLog(log.id)}
                    className="p-2 text-zinc-300 hover:text-rose-500 transition-colors rounded-xl hover:bg-rose-50"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </motion.div>
            ))
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}

function AnalyticsTab() {
  const { sleepLogs } = useStore();
  const [period, setPeriod] = useState<'week' | 'month' | '3months'>('month');

  const periodDays = period === 'week' ? 7 : period === 'month' ? 30 : 90;

  const chartData = useMemo(() => {
    return Array.from({ length: periodDays }, (_, i) => {
      const date = subDays(new Date(), periodDays - 1 - i);
      const log = sleepLogs.find(l => isSameDay(parseISO(l.date), date));
      return {
        date: format(date, periodDays <= 7 ? 'EE' : 'dd.MM', { locale: ru }),
        hours: log?.hours || 0,
        quality: log?.quality || 0,
      };
    });
  }, [sleepLogs, periodDays]);

  const stats = useMemo(() => {
    const relevantLogs = sleepLogs.filter(l => {
      const d = parseISO(l.date);
      const cutoff = subDays(new Date(), periodDays);
      return d >= cutoff;
    });
    if (relevantLogs.length === 0) return null;

    const hours = relevantLogs.map(l => l.hours);
    const qualities = relevantLogs.map(l => l.quality);
    const avgHours = hours.reduce((a, b) => a + b, 0) / hours.length;
    const avgQuality = qualities.reduce((a, b) => a + b, 0) / qualities.length;

    const daysUnder7 = relevantLogs.filter(l => l.hours < 7).length;
    const daysOver8 = relevantLogs.filter(l => l.hours >= 8).length;

    const weekdayAvg = Array.from({ length: 7 }, (_, day) => {
      const dayLogs = relevantLogs.filter(l => parseISO(l.date).getDay() === day);
      return {
        day: ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'][day],
        hours: dayLogs.length > 0 ? dayLogs.reduce((a, l) => a + l.hours, 0) / dayLogs.length : 0,
      };
    });

    return { avgHours, avgQuality, daysUnder7, daysOver8, total: relevantLogs.length, weekdayAvg };
  }, [sleepLogs, periodDays]);

  return (
    <div className="space-y-4">
      {/* Period selector */}
      <div className="flex gap-2">
        {([['week', 'Неделя'], ['month', 'Месяц'], ['3months', '3 Месяца']] as const).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setPeriod(key)}
            className={cn(
              "flex-1 py-2 rounded-xl text-xs font-bold transition-all",
              period === key
                ? "bg-indigo-500 text-white shadow-md shadow-indigo-500/30"
                : "bg-white text-zinc-500 border border-stone-200 hover:text-zinc-700"
            )}
          >
            {label}
          </button>
        ))}
      </div>

      {!stats ? (
        <div className="bg-white p-8 rounded-2xl border border-stone-200 text-center">
          <Moon className="w-8 h-8 text-zinc-300 mx-auto mb-3" />
          <p className="text-sm text-zinc-400">Недостаточно данных для аналитики</p>
          <p className="text-xs text-zinc-300 mt-1">Начните записывать сон на вкладке "Запись"</p>
        </div>
      ) : (
        <>
          {/* Stats overview */}
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-white p-4 rounded-2xl border border-stone-200">
              <span className="text-[10px] text-zinc-500 uppercase font-bold block mb-1">Средний сон</span>
              <span className={cn(
                "text-2xl font-bold",
                stats.avgHours >= 7 ? "text-emerald-600" : stats.avgHours >= 6 ? "text-amber-500" : "text-rose-500"
              )}>
                {stats.avgHours.toFixed(1)}ч
              </span>
              <span className="text-[10px] text-zinc-400 block mt-0.5">
                Норма: 7-9 часов
              </span>
            </div>
            <div className="bg-white p-4 rounded-2xl border border-stone-200">
              <span className="text-[10px] text-zinc-500 uppercase font-bold block mb-1">Среднее качество</span>
              <span className="text-2xl font-bold text-indigo-600">
                {stats.avgQuality.toFixed(1)}/5
              </span>
              <span className="text-[10px] text-zinc-400 block mt-0.5">
                {stats.total} записей
              </span>
            </div>
            <div className="bg-white p-4 rounded-2xl border border-stone-200">
              <span className="text-[10px] text-zinc-500 uppercase font-bold block mb-1">Недосып (&lt;7ч)</span>
              <span className="text-2xl font-bold text-rose-500">{stats.daysUnder7}</span>
              <span className="text-[10px] text-zinc-400 block mt-0.5">дней</span>
            </div>
            <div className="bg-white p-4 rounded-2xl border border-stone-200">
              <span className="text-[10px] text-zinc-500 uppercase font-bold block mb-1">Хороший сон (&ge;8ч)</span>
              <span className="text-2xl font-bold text-emerald-600">{stats.daysOver8}</span>
              <span className="text-[10px] text-zinc-400 block mt-0.5">дней</span>
            </div>
          </div>

          {/* Hours chart */}
          <div className="bg-white p-4 rounded-2xl border border-stone-200">
            <h3 className="text-xs font-bold text-zinc-500 uppercase mb-3">Часы сна</h3>
            <div className="h-40 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f4f4f5" />
                  <XAxis
                    dataKey="date"
                    axisLine={false}
                    tickLine={false}
                    tick={{ fontSize: 8, fill: '#71717a' }}
                    interval={period === 'week' ? 0 : period === 'month' ? 4 : 14}
                  />
                  <YAxis
                    axisLine={false}
                    tickLine={false}
                    tick={{ fontSize: 8, fill: '#71717a' }}
                    domain={[0, 12]}
                  />
                  <Tooltip
                    contentStyle={{ backgroundColor: '#fff', border: '1px solid #e4e4e7', borderRadius: '12px', fontSize: '10px' }}
                    formatter={(value: number) => [`${value}ч`, 'Сон']}
                  />
                  <Bar
                    dataKey="hours"
                    fill="#6366f1"
                    radius={[4, 4, 0, 0]}
                    maxBarSize={period === 'week' ? 40 : 12}
                  />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Quality trend */}
          <div className="bg-white p-4 rounded-2xl border border-stone-200">
            <h3 className="text-xs font-bold text-zinc-500 uppercase mb-3">Качество сна</h3>
            <div className="h-32 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData}>
                  <defs>
                    <linearGradient id="qualGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#f59e0b" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <Area type="monotone" dataKey="quality" stroke="#f59e0b" fill="url(#qualGrad)" strokeWidth={2} />
                  <XAxis
                    dataKey="date"
                    axisLine={false}
                    tickLine={false}
                    tick={{ fontSize: 8, fill: '#71717a' }}
                    interval={period === 'week' ? 0 : period === 'month' ? 4 : 14}
                  />
                  <YAxis hide domain={[0, 5]} />
                  <Tooltip
                    contentStyle={{ backgroundColor: '#fff', border: '1px solid #e4e4e7', borderRadius: '12px', fontSize: '10px' }}
                    formatter={(value: number) => [`${value}/5`, 'Качество']}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Weekday pattern */}
          <div className="bg-white p-4 rounded-2xl border border-stone-200">
            <h3 className="text-xs font-bold text-zinc-500 uppercase mb-3">Сон по дням недели</h3>
            <div className="h-40 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={stats.weekdayAvg}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f4f4f5" />
                  <XAxis
                    dataKey="day"
                    axisLine={false}
                    tickLine={false}
                    tick={{ fontSize: 9, fill: '#71717a' }}
                  />
                  <YAxis
                    axisLine={false}
                    tickLine={false}
                    tick={{ fontSize: 8, fill: '#71717a' }}
                    domain={[0, 12]}
                  />
                  <Tooltip
                    contentStyle={{ backgroundColor: '#fff', border: '1px solid #e4e4e7', borderRadius: '12px', fontSize: '10px' }}
                    formatter={(value: number) => [`${value.toFixed(1)}ч`, 'Средний сон']}
                  />
                  <Bar dataKey="hours" fill="#a78bfa" radius={[6, 6, 0, 0]} maxBarSize={32} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
