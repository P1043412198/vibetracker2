import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Plus, Trash2, Target, Calendar, TrendingUp, Bot, Edit2, X, Check, Loader2, Sparkles } from 'lucide-react';
import { useStore } from '../store/useStore';
import { cn } from '../lib/utils';
import { FinancialGoal, FinancialGoalStep } from '../types';
import { GoogleGenAI, Type } from "@google/genai";
import OpenAI from 'openai';
import { v4 as uuidv4 } from 'uuid';

export function FinancialPlanTab({ onSwitchToAI }: { onSwitchToAI: (prompt: string) => void }) {
  const { financialGoals = [], addFinancialGoal, updateFinancialGoal, deleteFinancialGoal, transactions = [], loans = [], customGeminiKey, customOpenAIKey, preferredAiProvider } = useStore();
  const [isAdding, setIsAdding] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [generatingPlanId, setGeneratingPlanId] = useState<string | null>(null);
  const [planError, setPlanError] = useState<string | null>(null);

  const [title, setTitle] = useState('');
  const [targetAmount, setTargetAmount] = useState('');
  const [currentAmount, setCurrentAmount] = useState('');
  const [deadline, setDeadline] = useState('');
  const [notes, setNotes] = useState('');

  const handleAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !targetAmount) return;

    addFinancialGoal({
      title: title.trim(),
      targetAmount: parseFloat(targetAmount),
      currentAmount: parseFloat(currentAmount) || 0,
      deadline: deadline || undefined,
      notes: notes.trim() || undefined,
    });

    setIsAdding(false);
    resetForm();
  };

  const handleUpdate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingId || !title.trim() || !targetAmount) return;

    updateFinancialGoal(editingId, {
      title: title.trim(),
      targetAmount: parseFloat(targetAmount),
      currentAmount: parseFloat(currentAmount) || 0,
      deadline: deadline || undefined,
      notes: notes.trim() || undefined,
    });

    setEditingId(null);
    resetForm();
  };

  const resetForm = () => {
    setTitle('');
    setTargetAmount('');
    setCurrentAmount('');
    setDeadline('');
    setNotes('');
  };

  const startEditing = (goal: FinancialGoal) => {
    setEditingId(goal.id);
    setTitle(goal.title);
    setTargetAmount(goal.targetAmount.toString());
    setCurrentAmount(goal.currentAmount.toString());
    setDeadline(goal.deadline || '');
    setNotes(goal.notes || '');
    setIsAdding(false);
  };

  const askAIForPlan = (goal: FinancialGoal) => {
    const prompt = `Составь мне подробный финансовый план, как накопить ${goal.targetAmount} BYN на цель "${goal.title}"${goal.deadline ? ` к ${goal.deadline}` : ''}. У меня уже накоплено ${goal.currentAmount} BYN. Учитывай мои текущие доходы, расходы и кредиты. Дай пошаговую инструкцию.`;
    onSwitchToAI(prompt);
  };

  const generateAIPlan = async (goal: FinancialGoal) => {
    setGeneratingPlanId(goal.id);
    setPlanError(null);
    try {
      const cleanTransactions = transactions.slice(0, 50).map(({ photoUrl, ...rest }) => rest);
      const shoppingItems = JSON.parse(localStorage.getItem('shopping_items') || '[]');
      const cleanShoppingItems = shoppingItems.map(({ photoUrl, ...rest }: any) => rest);

      const prompt = `Ты — строгий и прагматичный финансовый эксперт. Пользователь живет в Беларуси (валюта BYN).
      Составь пошаговый финансовый план, как накопить ${goal.targetAmount} BYN на цель "${goal.title}"${goal.deadline ? ` к ${goal.deadline}` : ''}. У меня уже накоплено ${goal.currentAmount} BYN. 
      Учитывай мои доходы, расходы и кредиты. 
      ОБЯЗАТЕЛЬНО включай в план практичные шаги по тотальной экономии в быту:
      - Снижение расходов на коммуналку (свет, вода, отопление).
      - Экономия на продуктах и покупках (акции, скидочные карты магазинов РБ, отказ от пакетов на кассе).
      - Отказ от импульсивных трат и кофе навынос.
      - Оптимизация текущих долгов.
      
      Транзакции: ${JSON.stringify(cleanTransactions)}
      Кредиты: ${JSON.stringify(loans)}
      Список покупок: ${JSON.stringify(cleanShoppingItems)}
      
      Верни ответ строго в виде JSON массива шагов, где каждый шаг имеет title (краткое название) и description (подробное описание действия с конкретными советами по экономии).`;

      let stepsData = [];

      if (preferredAiProvider === 'openai' && customOpenAIKey) {
        const openai = new OpenAI({ apiKey: customOpenAIKey, dangerouslyAllowBrowser: true });
        
        const completion = await openai.chat.completions.create({
          messages: [{ role: 'user', content: prompt }],
          model: 'gpt-4o-mini',
          response_format: { type: "json_object" },
        });

        const content = completion.choices[0]?.message?.content || '{"steps": []}';
        const parsed = JSON.parse(content);
        // Handle different possible JSON structures from OpenAI
        stepsData = Array.isArray(parsed) ? parsed : (parsed.steps || parsed.data || []);
      } else {
        const apiKey = customGeminiKey || process.env.GEMINI_API_KEY;
        if (!apiKey) throw new Error('API key is missing');
        
        const ai = new GoogleGenAI({ apiKey });
        
        const response = await ai.models.generateContent({
          model: "gemini-3-flash-preview",
          contents: prompt,
          config: {
            responseMimeType: "application/json",
            responseSchema: {
              type: Type.ARRAY,
              items: {
                type: Type.OBJECT,
                properties: {
                  title: { type: Type.STRING, description: "Краткое название шага" },
                  description: { type: Type.STRING, description: "Подробное описание шага" }
                },
                required: ["title", "description"]
              }
            }
          }
        });

        stepsData = JSON.parse(response.text || "[]");
      }

      const steps: FinancialGoalStep[] = stepsData.map((s: any) => ({
        id: uuidv4(),
        title: s.title || 'Шаг',
        description: s.description || '',
        completed: false
      }));

      updateFinancialGoal(goal.id, {
        aiPlan: {
          steps,
          generatedAt: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error("Failed to generate AI plan:", error);
      setPlanError("Не удалось сгенерировать план. Попробуйте позже. Проверьте API ключи в настройках.");
    } finally {
      setGeneratingPlanId(null);
    }
  };

  const toggleStep = (goalId: string, stepId: string) => {
    const goal = financialGoals.find(g => g.id === goalId);
    if (!goal || !goal.aiPlan) return;

    const updatedSteps = goal.aiPlan.steps.map(s => 
      s.id === stepId ? { ...s, completed: !s.completed } : s
    );

    updateFinancialGoal(goalId, {
      aiPlan: {
        ...goal.aiPlan,
        steps: updatedSteps
      }
    });
  };

  const calculateSavingsForecast = (goal: FinancialGoal) => {
    const now = new Date();
    const threeMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 3, 1);
    
    const relevantTransactions = transactions.filter(t => new Date(t.date) >= threeMonthsAgo);
    
    let totalIncome = 0;
    let totalExpense = 0;
    
    relevantTransactions.forEach(t => {
      if (t.type === 'income') totalIncome += t.amount;
      if (t.type === 'expense') totalExpense += t.amount;
    });
    
    const avgMonthlySavings = (totalIncome - totalExpense) / 3;
    const remaining = goal.targetAmount - goal.currentAmount;
    
    if (avgMonthlySavings <= 0) return { months: Infinity, avg: avgMonthlySavings };
    
    return {
      months: Math.ceil(remaining / avgMonthlySavings),
      avg: avgMonthlySavings
    };
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-bold text-zinc-900 flex items-center gap-2">
          <Target className="w-5 h-5 text-emerald-400" />
          Финансовые цели
        </h2>
        <button
          onClick={() => {
            setIsAdding(true);
            setEditingId(null);
            resetForm();
          }}
          className="p-2 bg-emerald-500/20 text-emerald-400 rounded-xl hover:bg-emerald-500/30 transition-colors"
        >
          <Plus className="w-5 h-5" />
        </button>
      </div>

      <AnimatePresence>
        {(isAdding || editingId) && (
          <motion.form
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            onSubmit={editingId ? handleUpdate : handleAdd}
            className="bg-white p-4 rounded-2xl border border-stone-200 space-y-4 overflow-hidden"
          >
            <div className="flex justify-between items-center mb-2">
              <h3 className="text-sm font-medium text-zinc-900">
                {editingId ? 'Редактировать цель' : 'Новая цель'}
              </h3>
              <button
                type="button"
                onClick={() => {
                  setIsAdding(false);
                  setEditingId(null);
                }}
                className="p-1 text-zinc-500 hover:text-zinc-900 transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-3">
              <input
                type="text"
                placeholder="Название цели (например, Машина)"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full bg-stone-50 border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500"
                required
              />
              <div className="grid grid-cols-2 gap-3">
                <input
                  type="number"
                  placeholder="Целевая сумма"
                  value={targetAmount}
                  onChange={(e) => setTargetAmount(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500"
                  required
                  min="0"
                  step="0.01"
                />
                <input
                  type="number"
                  placeholder="Уже накоплено"
                  value={currentAmount}
                  onChange={(e) => setCurrentAmount(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500"
                  min="0"
                  step="0.01"
                />
              </div>
              <input
                type="date"
                value={deadline}
                onChange={(e) => setDeadline(e.target.value)}
                className="w-full bg-stone-50 border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500"
              />
              <input
                type="text"
                placeholder="Заметки (необязательно)"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                className="w-full bg-stone-50 border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500"
              />
            </div>

            <button
              type="submit"
              className="w-full py-2 bg-emerald-600 text-zinc-900 rounded-xl text-sm font-medium hover:bg-emerald-500 transition-colors"
            >
              {editingId ? 'Сохранить изменения' : 'Добавить цель'}
            </button>
          </motion.form>
        )}
      </AnimatePresence>

      {planError && (
        <div className="bg-red-500/10 border border-red-500/20 text-red-400 p-3 rounded-xl text-sm">
          {planError}
        </div>
      )}

      <div className="space-y-4">
        {financialGoals.length === 0 && !isAdding ? (
          <div className="text-center py-10 bg-white/60 rounded-2xl border border-stone-200/70">
            <Target className="w-12 h-12 text-zinc-700 mx-auto mb-3" />
            <p className="text-zinc-500 text-sm">У вас пока нет финансовых целей.</p>
            <p className="text-zinc-600 text-xs mt-1">Добавьте цель, чтобы начать копить!</p>
          </div>
        ) : (
          financialGoals.map((goal) => {
            const progress = Math.min((goal.currentAmount / goal.targetAmount) * 100, 100);
            const remaining = goal.targetAmount - goal.currentAmount;

            return (
              <div key={goal.id} className="bg-white p-4 rounded-2xl border border-stone-200 space-y-4">
                <div className="flex justify-between items-start">
                  <div>
                    <h3 className="font-bold text-zinc-900 text-lg">{goal.title}</h3>
                    {goal.deadline && (
                      <div className="flex items-center gap-1 text-xs text-zinc-500 mt-1">
                        <Calendar className="w-3 h-3" />
                        <span>Дедлайн: {new Date(goal.deadline).toLocaleDateString('ru-RU')}</span>
                      </div>
                    )}
                  </div>
                  <div className="flex gap-2">
                    <button
                      onClick={() => startEditing(goal)}
                      className="p-2 text-zinc-500 hover:text-zinc-900 transition-colors"
                    >
                      <Edit2 className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => deleteFinancialGoal(goal.id)}
                      className="p-2 text-zinc-500 hover:text-red-400 transition-colors"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
                    <div className="text-xs text-zinc-500 mb-1">Накоплено</div>
                    <div className="text-lg font-bold text-emerald-400">
                      {goal.currentAmount.toLocaleString('ru-RU')} BYN
                    </div>
                  </div>
                  <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
                    <div className="text-xs text-zinc-500 mb-1">Осталось</div>
                    <div className="text-lg font-bold text-zinc-900">
                      {remaining > 0 ? remaining.toLocaleString('ru-RU') : 0} BYN
                    </div>
                  </div>
                </div>

                <div className="space-y-1">
                  <div className="flex justify-between text-xs">
                    <span className="text-zinc-500">Прогресс</span>
                    <span className="text-zinc-500">{progress.toFixed(1)}%</span>
                  </div>
                  <div className="h-1.5 bg-stone-50 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-emerald-500 rounded-full transition-all duration-500"
                      style={{ width: `${progress}%` }}
                    />
                  </div>
                </div>

                {remaining > 0 && (
                  <div className="bg-stone-50/50 p-3 rounded-xl border border-stone-200/70 flex items-center justify-between">
                    <div className="flex items-center gap-2 text-zinc-500">
                      <TrendingUp className="w-4 h-4 text-emerald-400" />
                      <span className="text-xs">Прогноз накоплений</span>
                    </div>
                    <div className="text-right">
                      {(() => {
                        const forecast = calculateSavingsForecast(goal);
                        if (forecast.months === Infinity) {
                          return <span className="text-xs text-red-400">Нужно больше сбережений</span>;
                        }
                        return (
                          <div className="text-xs font-medium text-zinc-900">
                            ~ {forecast.months} {forecast.months === 1 ? 'месяц' : forecast.months < 5 ? 'месяца' : 'месяцев'}
                          </div>
                        );
                      })()}
                    </div>
                  </div>
                )}

                {goal.aiPlan ? (
                  <div className="bg-stone-50 rounded-xl border border-stone-200/70 p-4 space-y-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2 text-emerald-400">
                        <Sparkles className="w-4 h-4" />
                        <h4 className="font-medium text-sm">ИИ-План достижения цели</h4>
                      </div>
                      <button
                        onClick={() => generateAIPlan(goal)}
                        disabled={generatingPlanId === goal.id}
                        className="text-xs text-zinc-500 hover:text-emerald-400 transition-colors flex items-center gap-1"
                      >
                        {generatingPlanId === goal.id ? (
                          <Loader2 className="w-3 h-3 animate-spin" />
                        ) : (
                          <Bot className="w-3 h-3" />
                        )}
                        Обновить
                      </button>
                    </div>
                    <div className="space-y-3">
                      {goal.aiPlan.steps.map((step, index) => (
                        <div 
                          key={step.id}
                          className={cn(
                            "flex gap-3 p-3 rounded-xl border transition-colors cursor-pointer",
                            step.completed 
                              ? "bg-emerald-500/5 border-emerald-500/20" 
                              : "bg-white border-stone-200 hover:border-stone-300"
                          )}
                          onClick={() => toggleStep(goal.id, step.id)}
                        >
                          <div className={cn(
                            "w-5 h-5 rounded-full border flex items-center justify-center flex-shrink-0 mt-0.5 transition-colors",
                            step.completed
                              ? "bg-emerald-500 border-emerald-500 text-zinc-900"
                              : "border-zinc-600 text-transparent"
                          )}>
                            <Check className="w-3 h-3" />
                          </div>
                          <div>
                            <h5 className={cn(
                              "text-sm font-medium transition-colors",
                              step.completed ? "text-emerald-400 line-through opacity-70" : "text-zinc-800"
                            )}>
                              {index + 1}. {step.title}
                            </h5>
                            {step.description && (
                              <p className={cn(
                                "text-xs mt-1 transition-colors",
                                step.completed ? "text-zinc-500 line-through opacity-70" : "text-zinc-500"
                              )}>
                                {step.description}
                              </p>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ) : (
                  <div className="flex gap-2">
                    <button
                      onClick={() => generateAIPlan(goal)}
                      disabled={generatingPlanId === goal.id}
                      className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-emerald-500/10 text-emerald-400 rounded-xl text-sm font-medium hover:bg-emerald-500/20 transition-colors disabled:opacity-50"
                    >
                      {generatingPlanId === goal.id ? (
                        <Loader2 className="w-4 h-4 animate-spin" />
                      ) : (
                        <Sparkles className="w-4 h-4" />
                      )}
                      {generatingPlanId === goal.id ? 'Составляю план...' : 'Сгенерировать план'}
                    </button>
                    <button
                      onClick={() => askAIForPlan(goal)}
                      className="p-2.5 bg-stone-100 text-zinc-500 rounded-xl hover:bg-stone-200 hover:text-zinc-900 transition-colors"
                      title="Спросить в чате"
                    >
                      <Bot className="w-5 h-5" />
                    </button>
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
