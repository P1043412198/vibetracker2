import React, { useState } from 'react';
import { useStore } from '../store/useStore';
import { format, addDays, startOfMonth, endOfMonth, eachDayOfInterval, isSameDay, isToday, startOfWeek, endOfWeek, subMonths, addMonths, differenceInDays, differenceInCalendarDays, isWithinInterval, parseISO } from 'date-fns';
import { ru } from 'date-fns/locale';
import { Calendar as CalendarIcon, ChevronLeft, ChevronRight, Sun, Moon, Coffee, Home, Settings2, Plus, Trash2, Plane, Save, X } from 'lucide-react';
import { cn } from '../lib/utils';
import { motion, AnimatePresence } from 'framer-motion';
import { WorkShiftType, Vacation } from '../types';

const SHIFT_COLORS: Record<WorkShiftType, string> = {
  day: 'bg-amber-500/20 text-amber-500 border-amber-500/30',
  night: 'bg-indigo-500/20 text-indigo-400 border-indigo-500/30',
  off: 'bg-zinc-800/50 text-zinc-500 border-zinc-700/50',
  post_night: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30',
  vacation: 'bg-rose-500/20 text-rose-400 border-rose-500/30',
};

const SHIFT_LABELS: Record<WorkShiftType, string> = {
  day: 'День',
  night: 'Ночь',
  off: 'Выходной',
  post_night: 'Отсыпной',
  vacation: 'Отпуск',
};

const SHIFT_ICONS: Record<WorkShiftType, any> = {
  day: Sun,
  night: Moon,
  off: Home,
  post_night: Coffee,
  vacation: Plane,
};

const PRESETS: Record<string, { name: string, cycle: WorkShiftType[] }> = {
  '2/2/2/2': {
    name: '2/2/2/2 (День, Выходной, Ночь, Отсыпной)',
    cycle: ['day', 'day', 'off', 'off', 'night', 'night', 'post_night', 'off']
  },
  '2/2': {
    name: '2/2 (Два через два)',
    cycle: ['day', 'day', 'off', 'off']
  },
  '5/2': {
    name: '5/2 (Пятидневка)',
    cycle: ['day', 'day', 'day', 'day', 'day', 'off', 'off']
  },
  '3/3': {
    name: '3/3 (Три через три)',
    cycle: ['day', 'day', 'day', 'off', 'off', 'off']
  },
  '1/3': {
    name: 'Сутки через трое',
    cycle: ['day', 'night', 'off', 'off', 'off', 'off']
  }
};

export function WorkSchedule() {
  const { workSchedule, updateWorkSchedule, addVacation, deleteVacation } = useStore();
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [showSettings, setShowSettings] = useState(!workSchedule);
  const [tempAnchorDate, setTempAnchorDate] = useState(workSchedule?.anchorDate || format(new Date(), 'yyyy-MM-dd'));
  const [tempCycle, setTempCycle] = useState<WorkShiftType[]>(workSchedule?.cycle || PRESETS['2/2/2/2'].cycle);
  
  const [isAddingVacation, setIsAddingVacation] = useState(false);
  const [newVacation, setNewVacation] = useState({ title: '', startDate: '', endDate: '' });

  const handleSaveSettings = () => {
    updateWorkSchedule({
      anchorDate: tempAnchorDate,
      cycle: tempCycle,
      vacations: workSchedule?.vacations || []
    });
    setShowSettings(false);
  };

  const getShiftForDate = (date: Date): WorkShiftType | null => {
    if (!workSchedule || !workSchedule.cycle.length) return null;

    const targetDateStr = format(date, 'yyyy-MM-dd');

    // Check vacations
    const vacation = workSchedule.vacations?.find(v => 
      targetDateStr >= v.startDate && targetDateStr <= v.endDate
    );
    if (vacation) return 'vacation';

    // Use string-based parsing to ensure we only compare dates, not times
    const anchorDate = parseISO(workSchedule.anchorDate);
    const targetDate = parseISO(targetDateStr);
    
    const diff = differenceInCalendarDays(targetDate, anchorDate);
    
    const cycleLength = workSchedule.cycle.length;
    const index = ((diff % cycleLength) + cycleLength) % cycleLength;
    return workSchedule.cycle[index];
  };

  const getPreviewShifts = () => {
    const anchor = parseISO(tempAnchorDate);
    return [0, 1, 2].map(offset => {
      const date = addDays(anchor, offset);
      const index = offset % tempCycle.length;
      const shift = tempCycle[index];
      return {
        date,
        shift
      };
    });
  };

  const handleAddShift = () => setTempCycle([...tempCycle, 'off']);
  const handleRemoveShift = (index: number) => setTempCycle(tempCycle.filter((_, i) => i !== index));
  const handleUpdateShift = (index: number, type: WorkShiftType) => {
    const newCycle = [...tempCycle];
    newCycle[index] = type;
    setTempCycle(newCycle);
  };

  const handleAddVacation = () => {
    if (!newVacation.title || !newVacation.startDate || !newVacation.endDate) return;
    addVacation(newVacation);
    setNewVacation({ title: '', startDate: '', endDate: '' });
    setIsAddingVacation(false);
  };

  const monthStart = startOfMonth(currentMonth);
  const monthEnd = endOfMonth(monthStart);
  const calendarStart = startOfWeek(monthStart, { weekStartsOn: 1 });
  const calendarEnd = endOfWeek(monthEnd, { weekStartsOn: 1 });

  const calendarDays = eachDayOfInterval({
    start: calendarStart,
    end: calendarEnd,
  });

  const weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">График работы</h1>
          <p className="text-zinc-400 text-sm">Настройте свой цикл и планируйте отпуск</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setIsAddingVacation(true)}
            className="p-2 rounded-xl bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-white transition-colors"
            title="Добавить отпуск"
          >
            <Plane className="w-5 h-5" />
          </button>
          <button
            onClick={() => setShowSettings(!showSettings)}
            className="p-2 rounded-xl bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-white transition-colors"
            title="Настройки графика"
          >
            <Settings2 className="w-5 h-5" />
          </button>
        </div>
      </div>

      <AnimatePresence>
        {showSettings && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden"
          >
            <div className="p-6 rounded-3xl bg-zinc-900 border border-zinc-800 space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-bold text-white">Настройка графика</h2>
                <button onClick={() => setShowSettings(false)} className="text-zinc-500 hover:text-white">
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-xs text-zinc-500 block">Дата начала цикла</label>
                    <input
                      type="date"
                      value={tempAnchorDate}
                      onChange={(e) => setTempAnchorDate(e.target.value)}
                      className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-4 py-2 text-white outline-none focus:border-white/20 transition-colors"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs text-zinc-500 block">Пресеты графиков</label>
                    <select
                      onChange={(e) => setTempCycle(PRESETS[e.target.value].cycle)}
                      className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-4 py-2 text-white outline-none focus:border-white/20 transition-colors"
                    >
                      <option value="">Выберите пресет...</option>
                      {Object.entries(PRESETS).map(([key, preset]) => (
                        <option key={key} value={key}>{preset.name}</option>
                      ))}
                    </select>
                  </div>
                </div>

                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <div className="flex flex-col">
                      <label className="text-xs text-zinc-500">Ваш цикл ({tempCycle.length} дн.)</label>
                      <span className="text-[10px] text-indigo-400 font-bold">
                        Рабочих дней: {tempCycle.filter(s => s === 'day' || s === 'night').length}
                      </span>
                    </div>
                    <button
                      onClick={handleAddShift}
                      className="text-[10px] uppercase font-bold text-indigo-400 hover:text-indigo-300 flex items-center gap-1"
                    >
                      <Plus className="w-3 h-3" /> Добавить день
                    </button>
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-8 gap-2">
                    {tempCycle.map((shift, i) => (
                      <div key={i} className="relative group">
                        <select
                          value={shift}
                          onChange={(e) => handleUpdateShift(i, e.target.value as WorkShiftType)}
                          className={cn(
                            "w-full appearance-none text-[10px] font-bold py-2 px-2 rounded-xl border transition-all outline-none text-center",
                            SHIFT_COLORS[shift]
                          )}
                        >
                          <option value="day">День</option>
                          <option value="night">Ночь</option>
                          <option value="post_night">Отсыпной</option>
                          <option value="off">Вых.</option>
                        </select>
                        <button
                          onClick={() => handleRemoveShift(i)}
                          className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
                        >
                          <X className="w-2 h-2" />
                        </button>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="p-3 rounded-2xl bg-zinc-950 border border-zinc-800">
                  <p className="text-[10px] text-zinc-500 uppercase font-bold mb-2">Проверка (первые 3 дня):</p>
                  <div className="space-y-2">
                    {getPreviewShifts().map((p, i) => {
                      const Icon = SHIFT_ICONS[p.shift];
                      return (
                        <div key={i} className="flex items-center justify-between">
                          <span className="text-xs text-zinc-400">{format(p.date, 'd MMMM (EEEE)', { locale: ru })}</span>
                          <div className={cn("px-3 py-1 rounded-lg text-[10px] font-bold flex items-center gap-2 border", SHIFT_COLORS[p.shift])}>
                            <Icon className="w-3 h-3" />
                            {SHIFT_LABELS[p.shift]}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>

              <button
                onClick={handleSaveSettings}
                className="w-full py-3 bg-white text-black font-bold rounded-2xl hover:bg-zinc-200 transition-colors flex items-center justify-center gap-2"
              >
                <Save className="w-5 h-5" />
                Сохранить настройки
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <AnimatePresence>
        {isAddingVacation && (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          >
            <div className="bg-zinc-900 border border-zinc-800 rounded-3xl p-6 w-full max-w-md shadow-2xl space-y-4">
              <h2 className="text-xl font-bold text-white">Запланировать отпуск</h2>
              <div className="space-y-3">
                <input
                  type="text"
                  placeholder="Название (например, Отпуск в горах)"
                  value={newVacation.title}
                  onChange={(e) => setNewVacation({ ...newVacation, title: e.target.value })}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-4 py-2 text-white outline-none focus:border-white/20"
                />
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <label className="text-[10px] text-zinc-500 uppercase font-bold">Начало</label>
                    <input
                      type="date"
                      value={newVacation.startDate}
                      onChange={(e) => setNewVacation({ ...newVacation, startDate: e.target.value })}
                      className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-4 py-2 text-white outline-none text-sm"
                    />
                  </div>
                  <div className="space-y-1">
                    <label className="text-[10px] text-zinc-500 uppercase font-bold">Конец</label>
                    <input
                      type="date"
                      value={newVacation.endDate}
                      onChange={(e) => setNewVacation({ ...newVacation, endDate: e.target.value })}
                      className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-4 py-2 text-white outline-none text-sm"
                    />
                  </div>
                </div>
              </div>
              <div className="flex gap-3 pt-2">
                <button
                  onClick={() => setIsAddingVacation(false)}
                  className="flex-1 py-3 bg-zinc-800 text-white font-bold rounded-2xl hover:bg-zinc-700 transition-colors"
                >
                  Отмена
                </button>
                <button
                  onClick={handleAddVacation}
                  className="flex-1 py-3 bg-white text-black font-bold rounded-2xl hover:bg-zinc-200 transition-colors"
                >
                  Добавить
                </button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <div className="bg-zinc-900 border border-zinc-800 rounded-3xl overflow-hidden shadow-xl">
        <div className="p-4 flex items-center justify-between border-b border-zinc-800">
          <h2 className="text-lg font-bold text-white capitalize">
            {format(currentMonth, 'LLLL yyyy', { locale: ru })}
          </h2>
          <div className="flex gap-1">
            <button
              onClick={() => setCurrentMonth(subMonths(currentMonth, 1))}
              className="p-2 rounded-xl hover:bg-zinc-800 text-zinc-400 transition-colors"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
            <button
              onClick={() => setCurrentMonth(new Date())}
              className="px-3 py-1 text-xs font-medium text-zinc-400 hover:text-white transition-colors"
            >
              Сегодня
            </button>
            <button
              onClick={() => setCurrentMonth(addMonths(currentMonth, 1))}
              className="p-2 rounded-xl hover:bg-zinc-800 text-zinc-400 transition-colors"
            >
              <ChevronRight className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="grid grid-cols-7 border-b border-zinc-800">
          {weekDays.map((day) => (
            <div key={day} className="py-2 text-center text-[10px] font-bold text-zinc-500 uppercase tracking-widest">
              {day}
            </div>
          ))}
        </div>

        <div className="grid grid-cols-7">
          {calendarDays.map((day, i) => {
            const shift = getShiftForDate(day);
            const isCurrentMonth = isSameDay(startOfMonth(day), startOfMonth(currentMonth));
            const Icon = shift ? SHIFT_ICONS[shift] : null;

            return (
              <div
                key={day.toString()}
                className={cn(
                  "min-h-[80px] p-1 border-r border-b border-zinc-800 flex flex-col gap-1",
                  !isCurrentMonth && "opacity-30",
                  (i + 1) % 7 === 0 && "border-r-0"
                )}
              >
                <div className="flex justify-between items-start">
                  <span className={cn(
                    "text-[10px] font-medium w-5 h-5 flex items-center justify-center rounded-full",
                    isToday(day) ? "bg-white text-black" : "text-zinc-500"
                  )}>
                    {format(day, 'd')}
                  </span>
                </div>
                
                {shift && (
                  <div className={cn(
                    "flex-1 rounded-lg p-1 border flex flex-col items-center justify-center gap-0.5 transition-all",
                    SHIFT_COLORS[shift]
                  )}>
                    {Icon && <Icon className="w-3.5 h-3.5" />}
                    <span className="text-[7px] font-bold uppercase tracking-tighter text-center leading-none">
                      {SHIFT_LABELS[shift]}
                    </span>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {workSchedule?.vacations && workSchedule.vacations.length > 0 && (
        <div className="space-y-3">
          <h3 className="text-xs font-bold text-zinc-500 uppercase tracking-wider">Ваши отпуска</h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {workSchedule.vacations.map(vacation => (
              <div key={vacation.id} className="p-4 rounded-2xl bg-zinc-900 border border-zinc-800 flex items-center justify-between group">
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-xl bg-rose-500/10 text-rose-400">
                    <Plane className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-white">{vacation.title}</h4>
                    <p className="text-[10px] text-zinc-500">
                      {format(parseISO(vacation.startDate), 'd MMM', { locale: ru })} — {format(parseISO(vacation.endDate), 'd MMM yyyy', { locale: ru })}
                      {' '}({differenceInDays(parseISO(vacation.endDate), parseISO(vacation.startDate)) + 1} дн.)
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => deleteVacation(vacation.id)}
                  className="p-2 text-zinc-600 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-all"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
        {(['day', 'night', 'post_night', 'off', 'vacation'] as WorkShiftType[]).map((type) => {
          const Icon = SHIFT_ICONS[type];
          return (
            <div key={type} className={cn("p-3 rounded-2xl border flex items-center gap-3", SHIFT_COLORS[type])}>
              <Icon className="w-5 h-5" />
              <div className="flex flex-col">
                <span className="text-[10px] uppercase font-bold tracking-wider opacity-70">Смена</span>
                <span className="text-sm font-bold">{SHIFT_LABELS[type]}</span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
