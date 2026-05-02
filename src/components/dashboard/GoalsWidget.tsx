import React, { useState } from 'react';
import { Target, ArrowRight, Minus, Plus, ChevronUp, ChevronDown, CheckCircle2, Circle } from 'lucide-react';
import { Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'motion/react';
import { cn } from '../../lib/utils';
import { BookVisualization } from '../BookVisualization';
import { Goal } from '../../types';

interface GoalsWidgetProps {
  goals: Goal[];
  updateGoal: (id: string, updates: Partial<Goal>) => void;
  updateGoalStep: (goalId: string, stepId: string, updates: any) => void;
  addGoalStep: (goalId: string, step: any) => void;
}

export const GoalsWidget: React.FC<GoalsWidgetProps> = ({
  goals,
  updateGoal,
  updateGoalStep,
  addGoalStep
}) => {
  const [expandedGoalId, setExpandedGoalId] = useState<string | null>(null);

  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-zinc-900 flex items-center gap-2">
          <Target className="w-4 h-4" />
          Развитие
        </h2>
        <Link to="/goals" className="text-xs text-zinc-500 hover:text-zinc-700 font-medium flex items-center gap-1">
          Все цели <ArrowRight className="w-3.5 h-3.5" />
        </Link>
      </div>
      <div className="space-y-4">
        {goals.filter(g => g.status !== 'completed').slice(0, 2).map(goal => {
          const completedSteps = goal.steps.filter(s => s.completed).length;
          const isBook = goal.type === 'book';
          const isNumeric = goal.type === 'skill' || (goal.targetValue && goal.targetValue > 0);
          const isReading = isBook && goal.totalPages && goal.totalPages > 0;
          
          let progress = 0;
          if (isReading) {
            progress = ((goal.readPages || 0) / goal.totalPages!) * 100;
          } else if (isNumeric && goal.targetValue) {
            progress = ((goal.currentValue || 0) / goal.targetValue!) * 100;
          } else {
            progress = goal.steps.length > 0 ? (completedSteps / goal.steps.length) * 100 : 0;
          }
          
          const isExpanded = expandedGoalId === goal.id;
          
          return (
            <div key={goal.id} className="bg-stone-50 p-4 rounded-2xl border border-stone-200">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-xl bg-white flex items-center justify-center text-lg">
                    {goal.icon || (isBook ? '📚' : '🎯')}
                  </div>
                  <div>
                    <h3 className="text-xs font-bold text-zinc-900">{goal.title}</h3>
                    {isReading ? (
                      <p className="text-[10px] text-zinc-500">{goal.readPages || 0} из {goal.totalPages} стр.</p>
                    ) : isNumeric && goal.targetValue ? (
                      <p className="text-[10px] text-zinc-500">{goal.currentValue || 0} из {goal.targetValue} {goal.type === 'skill' ? 'ед.' : 'шагов'}</p>
                    ) : (
                      <p className="text-[10px] text-zinc-500">{completedSteps} из {goal.steps.length} шагов</p>
                    )}
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  {isReading && goal.totalPages && (
                    <div className="shrink-0">
                      <BookVisualization read={goal.readPages || 0} total={goal.totalPages} />
                    </div>
                  )}
                  {(isBook || isNumeric) && (
                    <div className="flex items-center gap-1 bg-white rounded-lg p-0.5 border border-stone-200">
                      <button 
                        onClick={(e) => {
                          e.stopPropagation();
                          if (isBook) {
                            updateGoal(goal.id, { readPages: Math.max(0, (goal.readPages || 0) - 1) });
                          } else if (isNumeric) {
                            updateGoal(goal.id, { currentValue: Math.max(0, (goal.currentValue || 0) - 1) });
                          }
                        }}
                        className="w-5 h-5 flex items-center justify-center text-zinc-500 hover:text-zinc-900 transition-colors"
                      >
                        <Minus className="w-3 h-3" />
                      </button>
                      <input 
                        type="number"
                        className="w-8 bg-transparent text-[10px] text-center text-zinc-900 focus:outline-none [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                        value={isBook ? (goal.readPages || 0) : (goal.currentValue || 0)}
                        onChange={(e) => {
                          const val = parseInt(e.target.value) || 0;
                          if (isBook) {
                            updateGoal(goal.id, { readPages: Math.min(goal.totalPages || Infinity, Math.max(0, val)) });
                          } else if (isNumeric) {
                            updateGoal(goal.id, { currentValue: Math.min(goal.targetValue || Infinity, Math.max(0, val)) });
                          }
                        }}
                        onClick={(e) => e.stopPropagation()}
                      />
                      <button 
                        onClick={(e) => {
                          e.stopPropagation();
                          if (isBook) {
                            updateGoal(goal.id, { readPages: Math.min(goal.totalPages || Infinity, (goal.readPages || 0) + 1) });
                          } else if (isNumeric) {
                            updateGoal(goal.id, { currentValue: Math.min(goal.targetValue || Infinity, (goal.currentValue || 0) + 1) });
                          }
                        }}
                        className="w-5 h-5 flex items-center justify-center text-zinc-500 hover:text-zinc-900 transition-colors"
                      >
                        <Plus className="w-3 h-3" />
                      </button>
                    </div>
                  )}
                  <button 
                    onClick={() => setExpandedGoalId(isExpanded ? null : goal.id)}
                    className="p-1 text-zinc-500 hover:text-zinc-900 transition-colors"
                  >
                    {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                  </button>
                </div>
              </div>
              <div className="w-full bg-white h-1.5 rounded-full overflow-hidden mb-3">
                <motion.div 
                  initial={{ width: 0 }}
                  animate={{ width: `${progress}%` }}
                  className="bg-white h-full rounded-full" 
                />
              </div>
              
              <AnimatePresence>
                {isExpanded && (
                  <motion.div 
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: 'auto', opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    className="overflow-hidden"
                  >
                    <div className="pt-2 space-y-2">
                      {goal.type !== 'book' && goal.steps.slice(0, 3).map(step => (
                        <div key={step.id} className="flex items-center gap-2">
                          <button 
                            onClick={() => updateGoalStep(goal.id, step.id, { completed: !step.completed })}
                            className={cn("transition-colors", step.completed ? "text-zinc-900" : "text-zinc-700 hover:text-zinc-900")}
                          >
                            {step.completed ? <CheckCircle2 className="w-3.5 h-3.5" /> : <Circle className="w-3.5 h-3.5" />}
                          </button>
                          <span className={cn("text-[10px] font-medium", step.completed ? "text-zinc-600 line-through" : "text-zinc-500")}>
                            {step.title}
                          </span>
                        </div>
                      ))}
                      {goal.type !== 'book' && goal.steps.length > 3 && (
                        <p className="text-[9px] text-zinc-600 italic pl-5">+ еще {goal.steps.length - 3} шагов</p>
                      )}
                      
                      <div className="pt-2 flex gap-2">
                        <input 
                          type="text"
                          placeholder={isBook ? "Введите кол-во страниц или заметку..." : isNumeric ? "Введите значение или заметку..." : "Добавить шаг..."}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter' && e.currentTarget.value.trim()) {
                              const val = e.currentTarget.value.trim();
                              if (isBook && /^\d+$/.test(val)) {
                                const pages = parseInt(val);
                                updateGoal(goal.id, { readPages: Math.min(goal.totalPages || Infinity, (goal.readPages || 0) + pages) });
                              } else if (isNumeric && /^\d+$/.test(val)) {
                                const amount = parseInt(val);
                                updateGoal(goal.id, { currentValue: Math.min(goal.targetValue || Infinity, (goal.currentValue || 0) + amount) });
                              } else if (goal.type !== 'book') {
                                addGoalStep(goal.id, { title: val, completed: false });
                              }
                              e.currentTarget.value = '';
                            }
                          }}
                          className="flex-1 bg-stone-50 border border-stone-200 rounded-lg px-2 py-1 text-[10px] text-zinc-900 focus:outline-none focus:border-zinc-600"
                        />
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          );
        })}
        {goals.length === 0 && (
          <div className="text-center py-6 text-zinc-600">
            <Target className="w-8 h-8 mx-auto mb-2 opacity-20" />
            <p className="text-xs">У вас пока нет активных целей.</p>
          </div>
        )}
      </div>
    </div>
  );
};
