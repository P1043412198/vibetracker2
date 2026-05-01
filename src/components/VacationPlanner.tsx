import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Plane, Hotel, Utensils, Map, Plus, Trash2, Calculator, Calendar, DollarSign, X, ChevronRight, ChevronDown } from 'lucide-react';
import { useStore } from '../store/useStore';
import { cn } from '../lib/utils';

interface VacationExpense {
  id: string;
  category: 'transport' | 'accommodation' | 'food' | 'activities' | 'other';
  name: string;
  amount: number;
}

interface VacationPlan {
  id: string;
  destination: string;
  startDate: string;
  endDate: string;
  budget: number;
  expenses: VacationExpense[];
}

export function VacationPlanner() {
  const [plans, setPlans] = useState<VacationPlan[]>(() => {
    const saved = localStorage.getItem('vacation_plans');
    return saved ? JSON.parse(saved) : [];
  });
  const [isAdding, setIsAdding] = useState(false);
  const [newPlan, setNewPlan] = useState<Partial<VacationPlan>>({
    destination: '',
    startDate: '',
    endDate: '',
    budget: 0,
    expenses: []
  });

  const savePlans = (newPlans: VacationPlan[]) => {
    setPlans(newPlans);
    localStorage.setItem('vacation_plans', JSON.stringify(newPlans));
  };

  const handleAddPlan = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newPlan.destination || !newPlan.startDate || !newPlan.endDate) return;

    const plan: VacationPlan = {
      id: Math.random().toString(36).substr(2, 9),
      destination: newPlan.destination,
      startDate: newPlan.startDate,
      endDate: newPlan.endDate,
      budget: newPlan.budget || 0,
      expenses: []
    };

    savePlans([...plans, plan]);
    setIsAdding(false);
    setNewPlan({ destination: '', startDate: '', endDate: '', budget: 0, expenses: [] });
  };

  const deletePlan = (id: string) => {
    savePlans(plans.filter(p => p.id !== id));
  };

  const addExpense = (planId: string, expense: Omit<VacationExpense, 'id'>) => {
    const updatedPlans = plans.map(p => {
      if (p.id === planId) {
        return {
          ...p,
          expenses: [...p.expenses, { ...expense, id: Math.random().toString(36).substr(2, 9) }]
        };
      }
      return p;
    });
    savePlans(updatedPlans);
  };

  const removeExpense = (planId: string, expenseId: string) => {
    const updatedPlans = plans.map(p => {
      if (p.id === planId) {
        return {
          ...p,
          expenses: p.expenses.filter(e => e.id !== expenseId)
        };
      }
      return p;
    });
    savePlans(updatedPlans);
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-bold text-white flex items-center gap-2">
          <Plane className="w-5 h-5 text-blue-400" />
          Планировщик отпуска
        </h2>
        <button
          onClick={() => setIsAdding(!isAdding)}
          className="p-2 bg-blue-500/20 text-blue-400 rounded-xl hover:bg-blue-500/30 transition-colors"
        >
          {isAdding ? <X className="w-5 h-5" /> : <Plus className="w-5 h-5" />}
        </button>
      </div>

      <AnimatePresence>
        {isAdding && (
          <motion.form
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            onSubmit={handleAddPlan}
            className="bg-zinc-900 p-4 rounded-2xl border border-zinc-800 space-y-4 overflow-hidden"
          >
            <div className="space-y-3">
              <input
                type="text"
                placeholder="Куда едем? (например, Бали)"
                value={newPlan.destination}
                onChange={e => setNewPlan({ ...newPlan, destination: e.target.value })}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
                required
              />
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-[10px] text-zinc-500 ml-1">Дата начала</label>
                  <input
                    type="date"
                    value={newPlan.startDate}
                    onChange={e => setNewPlan({ ...newPlan, startDate: e.target.value })}
                    className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
                    required
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-[10px] text-zinc-500 ml-1">Дата окончания</label>
                  <input
                    type="date"
                    value={newPlan.endDate}
                    onChange={e => setNewPlan({ ...newPlan, endDate: e.target.value })}
                    className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
                    required
                  />
                </div>
              </div>
              <div className="space-y-1">
                <label className="text-[10px] text-zinc-500 ml-1">Общий бюджет (BYN)</label>
                <input
                  type="number"
                  placeholder="Бюджет"
                  value={newPlan.budget}
                  onChange={e => setNewPlan({ ...newPlan, budget: parseFloat(e.target.value) })}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
                  min="0"
                />
              </div>
            </div>
            <button
              type="submit"
              className="w-full py-2 bg-blue-600 text-white rounded-xl text-sm font-medium hover:bg-blue-500 transition-colors"
            >
              Создать план
            </button>
          </motion.form>
        )}
      </AnimatePresence>

      <div className="space-y-4">
        {plans.length === 0 && !isAdding ? (
          <div className="text-center py-10 bg-zinc-900/50 rounded-2xl border border-zinc-800/50">
            <Map className="w-12 h-12 text-zinc-700 mx-auto mb-3" />
            <p className="text-zinc-500 text-sm">У вас пока нет планов на отпуск.</p>
            <p className="text-zinc-600 text-xs mt-1">Спланируйте свое следующее приключение!</p>
          </div>
        ) : (
          plans.map(plan => (
            <PlanItem 
              key={plan.id} 
              plan={plan} 
              onDelete={() => deletePlan(plan.id)}
              onAddExpense={(exp) => addExpense(plan.id, exp)}
              onRemoveExpense={(expId) => removeExpense(plan.id, expId)}
            />
          ))
        )}
      </div>
    </div>
  );
}

function PlanItem({ plan, onDelete, onAddExpense, onRemoveExpense }: { 
  plan: VacationPlan, 
  onDelete: () => void,
  onAddExpense: (exp: Omit<VacationExpense, 'id'>) => void,
  onRemoveExpense: (id: string) => void
}) {
  const [isExpanded, setIsExpanded] = useState(false);
  const [isAddingExpense, setIsAddingExpense] = useState(false);
  const [newExp, setNewExp] = useState<Omit<VacationExpense, 'id'>>({
    category: 'transport',
    name: '',
    amount: 0
  });

  const totalExpenses = plan.expenses.reduce((sum, e) => sum + e.amount, 0);
  const remaining = plan.budget - totalExpenses;
  const progress = plan.budget > 0 ? Math.min((totalExpenses / plan.budget) * 100, 100) : 0;

  const categoryIcons = {
    transport: <Plane className="w-4 h-4" />,
    accommodation: <Hotel className="w-4 h-4" />,
    food: <Utensils className="w-4 h-4" />,
    activities: <Map className="w-4 h-4" />,
    other: <Calculator className="w-4 h-4" />
  };

  const categoryLabels = {
    transport: 'Транспорт',
    accommodation: 'Жилье',
    food: 'Еда',
    activities: 'Развлечения',
    other: 'Другое'
  };

  return (
    <div className="bg-zinc-900 rounded-2xl border border-zinc-800 overflow-hidden">
      <div 
        className="p-4 cursor-pointer hover:bg-zinc-800/50 transition-colors"
        onClick={() => setIsExpanded(!isExpanded)}
      >
        <div className="flex justify-between items-start mb-3">
          <div>
            <h3 className="text-lg font-bold text-white">{plan.destination}</h3>
            <div className="flex items-center gap-2 text-xs text-zinc-400 mt-1">
              <Calendar className="w-3 h-3" />
              <span>{new Date(plan.startDate).toLocaleDateString('ru-RU')} - {new Date(plan.endDate).toLocaleDateString('ru-RU')}</span>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={(e) => {
                e.stopPropagation();
                onDelete();
              }}
              className="p-2 text-zinc-500 hover:text-red-400 transition-colors"
            >
              <Trash2 className="w-4 h-4" />
            </button>
            {isExpanded ? <ChevronDown className="w-5 h-5 text-zinc-500" /> : <ChevronRight className="w-5 h-5 text-zinc-500" />}
          </div>
        </div>

        <div className="space-y-3">
          <div className="flex justify-between items-end">
            <div className="space-y-1">
              <div className="text-[10px] text-zinc-500 uppercase tracking-wider">Бюджет</div>
              <div className="text-sm font-bold text-white">{plan.budget.toLocaleString('ru-RU')} BYN</div>
            </div>
            <div className="text-right space-y-1">
              <div className="text-[10px] text-zinc-500 uppercase tracking-wider">Расходы</div>
              <div className="text-sm font-bold text-blue-400">{totalExpenses.toLocaleString('ru-RU')} BYN</div>
            </div>
          </div>

          <div className="space-y-1">
            <div className="h-1.5 bg-zinc-950 rounded-full overflow-hidden">
              <div 
                className={cn(
                  "h-full rounded-full transition-all duration-500",
                  progress > 90 ? "bg-red-500" : progress > 70 ? "bg-yellow-500" : "bg-blue-500"
                )}
                style={{ width: `${progress}%` }}
              />
            </div>
            <div className="flex justify-between text-[10px]">
              <span className="text-zinc-500">Использовано {progress.toFixed(1)}%</span>
              <span className={cn(remaining < 0 ? "text-red-400" : "text-zinc-400")}>
                {remaining < 0 ? `Перебор: ${Math.abs(remaining).toLocaleString('ru-RU')} BYN` : `Осталось: ${remaining.toLocaleString('ru-RU')} BYN`}
              </span>
            </div>
          </div>
        </div>
      </div>

      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="border-t border-zinc-800 bg-zinc-950/30"
          >
            <div className="p-4 space-y-4">
              <div className="flex justify-between items-center">
                <h4 className="text-xs font-bold text-zinc-400 uppercase tracking-wider">Расходы</h4>
                <button
                  onClick={() => setIsAddingExpense(!isAddingExpense)}
                  className="text-xs text-blue-400 hover:text-blue-300 transition-colors flex items-center gap-1"
                >
                  {isAddingExpense ? <X className="w-3 h-3" /> : <Plus className="w-3 h-3" />}
                  {isAddingExpense ? 'Отмена' : 'Добавить'}
                </button>
              </div>

              {isAddingExpense && (
                <div className="bg-zinc-900 p-3 rounded-xl border border-zinc-800 space-y-3">
                  <div className="grid grid-cols-2 gap-2">
                    <select
                      value={newExp.category}
                      onChange={e => setNewExp({ ...newExp, category: e.target.value as any })}
                      className="bg-zinc-950 border border-zinc-800 rounded-lg px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500"
                    >
                      {Object.entries(categoryLabels).map(([val, label]) => (
                        <option key={val} value={val}>{label}</option>
                      ))}
                    </select>
                    <input
                      type="number"
                      placeholder="Сумма"
                      value={newExp.amount || ''}
                      onChange={e => setNewExp({ ...newExp, amount: parseFloat(e.target.value) || 0 })}
                      className="bg-zinc-950 border border-zinc-800 rounded-lg px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500"
                    />
                  </div>
                  <input
                    type="text"
                    placeholder="Описание (например, Билеты)"
                    value={newExp.name}
                    onChange={e => setNewExp({ ...newExp, name: e.target.value })}
                    className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500"
                  />
                  <button
                    onClick={() => {
                      if (!newExp.name || !newExp.amount) return;
                      onAddExpense(newExp);
                      setNewExp({ category: 'transport', name: '', amount: 0 });
                      setIsAddingExpense(false);
                    }}
                    className="w-full py-1.5 bg-blue-600 text-white rounded-lg text-xs font-medium hover:bg-blue-500 transition-colors"
                  >
                    Добавить расход
                  </button>
                </div>
              )}

              <div className="space-y-2">
                {plan.expenses.map(exp => (
                  <div key={exp.id} className="flex items-center justify-between bg-zinc-900/50 p-2 rounded-xl border border-zinc-800/50">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-zinc-800 rounded-lg text-blue-400">
                        {categoryIcons[exp.category]}
                      </div>
                      <div>
                        <div className="text-xs font-medium text-white">{exp.name}</div>
                        <div className="text-[10px] text-zinc-500">{categoryLabels[exp.category]}</div>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className="text-xs font-bold text-white">{exp.amount.toLocaleString('ru-RU')} BYN</div>
                      <button
                        onClick={() => onRemoveExpense(exp.id)}
                        className="text-zinc-600 hover:text-red-400 transition-colors"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                ))}
                {plan.expenses.length === 0 && !isAddingExpense && (
                  <p className="text-center py-4 text-[10px] text-zinc-600 uppercase tracking-widest">Нет расходов</p>
                )}
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
