import React, { useState } from 'react';
import { Bot, Calendar, Loader2, RefreshCw } from 'lucide-react';
import { useStore } from '../../store/useStore';
import { GoogleGenAI } from '@google/genai';
import ReactMarkdown from 'react-markdown';

export function SmartScheduleWidget() {
  const { inboxItems, workSchedule, plannedWorkouts, tasks, habits } = useStore();
  const [schedule, setSchedule] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const generateSchedule = async () => {
    const apiKey = import.meta.env.VITE_GEMINI_API_KEY;
    if (!apiKey) {
      setError('Не задан API ключ Gemini');
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const ai = new GoogleGenAI({ apiKey });
      
      const today = new Date().toISOString().split('T')[0];
      const todayWorkout = plannedWorkouts.find(w => w.date === today);
      const pendingTasks = tasks.filter(t => !t.completed && !t.failed);
      const pendingInbox = inboxItems;

      const prompt = `
        Составь идеальное расписание на сегодняшний день.
        
        Вводные данные:
        - Рабочий график: ${workSchedule ? `${workSchedule.type}, начало: ${workSchedule.startTime}, конец: ${workSchedule.endTime}` : 'Не задан'}
        - Тренировка сегодня: ${todayWorkout ? 'Запланирована' : 'Нет'}
        - Задачи во входящих (Inbox): ${pendingInbox.map(i => i.content).join(', ') || 'Нет'}
        - Текущие задачи: ${pendingTasks.map(t => t.title).join(', ') || 'Нет'}
        - Привычки: ${habits.map(h => h.title).join(', ') || 'Нет'}

        Правила:
        1. Распредели задачи из Inbox и текущие задачи по времени.
        2. Учти рабочее время (не ставь личные задачи на рабочее время, если это не перерыв).
        3. Выдели время на тренировку, если она запланирована.
        4. Не забудь про время на привычки.
        5. Напиши расписание в формате Markdown, используя списки с указанием времени (например, **08:00 - 09:00** - Завтрак и привычки).
        6. Будь краток и конструктивен.
      `;

      const response = await ai.models.generateContent({
        model: 'gemini-3.1-flash-preview',
        contents: prompt,
      });

      setSchedule(response.text || 'Не удалось сгенерировать расписание.');
    } catch (err: any) {
      setError(err.message || 'Ошибка генерации расписания');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800 flex flex-col h-full min-h-[300px]">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-white flex items-center gap-2">
          <Bot className="w-4 h-4 text-purple-500" />
          Умное расписание
        </h2>
        <button 
          onClick={generateSchedule}
          disabled={isLoading}
          className="p-1.5 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-zinc-400 hover:text-white transition-colors disabled:opacity-50"
          title="Сгенерировать расписание"
        >
          {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <RefreshCw className="w-4 h-4" />}
        </button>
      </div>

      <div className="flex-1 overflow-y-auto pr-2 custom-scrollbar">
        {isLoading ? (
          <div className="h-full flex flex-col items-center justify-center text-zinc-500 space-y-3 py-8">
            <Bot className="w-8 h-8 animate-pulse text-purple-500/50" />
            <p className="text-xs text-center">ИИ анализирует ваши задачи и график...</p>
          </div>
        ) : error ? (
          <div className="p-3 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-xs text-center">
            {error}
          </div>
        ) : schedule ? (
          <div className="prose prose-invert prose-sm max-w-none">
            <ReactMarkdown>{schedule}</ReactMarkdown>
          </div>
        ) : (
          <div className="h-full flex flex-col items-center justify-center text-zinc-500 space-y-3 py-8">
            <Calendar className="w-8 h-8 opacity-20" />
            <p className="text-xs text-center max-w-[200px]">
              Нажмите кнопку обновления, чтобы ИИ составил идеальный план на день
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
