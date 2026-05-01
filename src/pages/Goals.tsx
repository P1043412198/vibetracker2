import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Rocket, BookOpen, Brain, Target, Plus, Trash2, CheckCircle2, Circle, MoreVertical, Edit2, X, ChevronDown, ChevronUp, ImagePlus, Sparkles, Loader2, Pin, PinOff, RefreshCw, MessageSquare } from 'lucide-react';
import { v4 as uuidv4 } from 'uuid';
import { useStore } from '../store/useStore';
import { Goal, GoalType, GoalStatus, GoalStep, GoalStepStatus, GoalLog } from '../types';
import { cn } from '../lib/utils';
import { decomposeGoal } from '../services/aiService';
import { BookVisualization } from '../components/BookVisualization';

const TYPE_CONFIG = {
  goal: { icon: Target, label: 'Цели', color: 'text-blue-400', bg: 'bg-blue-400/10' },
  skill: { icon: Brain, label: 'Навыки', color: 'text-purple-400', bg: 'bg-purple-400/10' },
  book: { icon: BookOpen, label: 'Книги', color: 'text-emerald-400', bg: 'bg-emerald-400/10' },
  learning: { icon: Rocket, label: 'Обучение', color: 'text-orange-400', bg: 'bg-orange-400/10' },
};

function GoalLogsSection({ goalId }: { goalId: string }) {
  const { goalLogs = [], addGoalLog, deleteGoalLog } = useStore();
  const [newLogContent, setNewLogContent] = useState('');
  const [newLogDate, setNewLogDate] = useState(new Date().toISOString().split('T')[0]);

  const logs = goalLogs.filter(l => l.goalId === goalId).sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

  const handleAddLog = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newLogContent.trim()) return;
    addGoalLog({
      goalId,
      date: newLogDate,
      content: newLogContent.trim()
    });
    setNewLogContent('');
  };

  return (
    <div className="p-3 pt-0 mt-4 border-t border-zinc-800/50">
      <h4 className="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider mb-3 mt-3">Записи и действия</h4>
      
      <form onSubmit={handleAddLog} className="flex flex-col gap-2 mb-4">
        <div className="flex flex-wrap sm:flex-nowrap gap-2">
          <input
            type="date"
            value={newLogDate}
            onChange={(e) => setNewLogDate(e.target.value)}
            className="bg-zinc-900 border border-zinc-800 rounded-lg px-2 py-1.5 text-xs text-white focus:outline-none focus:border-indigo-500 w-[110px] shrink-0"
          />
          <input
            type="text"
            value={newLogContent}
            onChange={(e) => setNewLogContent(e.target.value)}
            placeholder="Что было сделано?"
            className="flex-1 min-w-[150px] bg-zinc-900 border border-zinc-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-indigo-500"
          />
          <button
            type="submit"
            disabled={!newLogContent.trim()}
            className="w-full sm:w-auto px-4 py-1.5 bg-indigo-500 text-white rounded-lg text-xs font-medium disabled:opacity-50 shrink-0"
          >
            Добавить
          </button>
        </div>
      </form>

      <div className="space-y-2">
        {logs.length === 0 ? (
          <p className="text-xs text-zinc-500 text-center py-2">Нет записей. Добавьте первое действие!</p>
        ) : (
          logs.map(log => (
            <div key={log.id} className="flex items-start gap-3 p-2 rounded-lg bg-zinc-900/50 border border-zinc-800/50 group">
              <div className="shrink-0 mt-0.5">
                <MessageSquare className="w-3.5 h-3.5 text-zinc-500" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex justify-between items-start">
                  <span className="text-[10px] text-indigo-400 font-medium">{new Date(log.date).toLocaleDateString('ru-RU')}</span>
                  <button
                    onClick={() => deleteGoalLog(log.id)}
                    className="opacity-0 group-hover:opacity-100 p-1 text-zinc-600 hover:text-red-400 transition-all"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
                <p className="text-xs text-zinc-300 mt-0.5 whitespace-pre-wrap">{log.content}</p>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export function Goals() {
  const { goals = [], addGoal, updateGoal, deleteGoal, addGoalStep, updateGoalStep, deleteGoalStep } = useStore();
  const [activeTab, setActiveTab] = useState<GoalType>('goal');
  const [isAdding, setIsAdding] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  // Form State
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [deadline, setDeadline] = useState('');
  const [author, setAuthor] = useState('');
  const [totalPages, setTotalPages] = useState('');
  const [readPages, setReadPages] = useState('');
  const [coverUrl, setCoverUrl] = useState('');
  const [showOnDashboard, setShowOnDashboard] = useState(false);

  const [viewMode, setViewMode] = useState<'list' | 'kanban'>('list');
  const [isDecomposing, setIsDecomposing] = useState(false);

  const filteredGoals = useMemo(() => {
    return goals
      .filter(g => g.type === activeTab)
      .sort((a, b) => {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
      });
  }, [goals, activeTab]);

  const resetForm = () => {
    setTitle('');
    setDescription('');
    setDeadline('');
    setAuthor('');
    setTotalPages('');
    setReadPages('');
    setCoverUrl('');
    setShowOnDashboard(false);
    setIsAdding(false);
    setEditingId(null);
  };

  const handleEdit = (goal: Goal) => {
    setEditingId(goal.id);
    setTitle(goal.title);
    setDescription(goal.description || '');
    setDeadline(goal.deadline || '');
    setAuthor(goal.author || '');
    setTotalPages(goal.totalPages?.toString() || '');
    setReadPages(goal.readPages?.toString() || '');
    setCoverUrl(goal.coverUrl || '');
    setShowOnDashboard(goal.showOnDashboard || false);
    setIsAdding(true);
  };

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const existingGoal = editingId ? goals.find(g => g.id === editingId) : null;

    const goalData = {
      title,
      description,
      type: activeTab,
      status: (existingGoal?.status || 'in_progress') as GoalStatus,
      deadline: deadline || undefined,
      author: author || undefined,
      totalPages: totalPages ? parseInt(totalPages) : undefined,
      readPages: readPages ? parseInt(readPages) : undefined,
      coverUrl: coverUrl || undefined,
      showOnDashboard,
      isPinned: existingGoal?.isPinned || false,
      steps: existingGoal?.steps || [],
    };

    if (editingId) {
      updateGoal(editingId, goalData);
    } else {
      addGoal(goalData);
    }
    resetForm();
  };

  const togglePin = (id: string, currentStatus: boolean) => {
    updateGoal(id, { isPinned: !currentStatus });
  };

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (event) => {
      setCoverUrl(event.target?.result as string);
    };
    reader.readAsDataURL(file);
  };

  const handleDecompose = async (goal: Goal, replace: boolean = false) => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.error('Gemini API key is missing');
      return;
    }
    setIsDecomposing(true);
    try {
      const steps = await decomposeGoal(apiKey, goal.title, goal.description || '');
      if (steps && Array.isArray(steps)) {
        if (replace) {
          // Clear existing steps first
          updateGoal(goal.id, { steps: [] });
        }
        steps.forEach(stepTitle => {
          addGoalStep(goal.id, { title: stepTitle, completed: false });
        });
      }
    } catch (error) {
      console.error(error);
    } finally {
      setIsDecomposing(false);
    }
  };

  const calculateProgress = (goal: Goal) => {
    if (goal.type === 'book' && goal.totalPages) {
      return Math.round(((goal.readPages || 0) / goal.totalPages) * 100);
    }
    if (goal.steps && goal.steps.length > 0) {
      const completed = goal.steps.filter(s => s.completed).length;
      return Math.round((completed / goal.steps.length) * 100);
    }
    return goal.progress || 0;
  };

  return (
    <div className="space-y-6">
      <header className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-white flex items-center gap-2">
          <Rocket className="w-6 h-6 text-orange-400" />
          Развитие
        </h1>
        {!isAdding && (
          <button
            onClick={() => setIsAdding(true)}
            className="flex items-center gap-2 px-4 py-2 bg-zinc-100 text-zinc-900 rounded-lg text-sm font-medium hover:bg-white transition-colors"
          >
            <Plus className="w-4 h-4" />
            <span className="hidden sm:inline">Добавить</span>
          </button>
        )}
      </header>

      {/* Tabs */}
      <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 flex-1 w-full">
          {(Object.keys(TYPE_CONFIG) as GoalType[]).map((type) => {
            const config = TYPE_CONFIG[type];
            const Icon = config.icon;
            const isActive = activeTab === type;
            return (
              <button
                key={type}
                onClick={() => {
                  setActiveTab(type);
                  resetForm();
                }}
                className={cn(
                  "flex items-center justify-center gap-2 px-3 py-2.5 rounded-xl text-sm font-medium transition-all",
                  isActive ? "bg-zinc-800 text-white shadow-sm" : "bg-zinc-900/50 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50 border border-zinc-800/50"
                )}
              >
                <Icon className={cn("w-4 h-4 shrink-0", isActive ? config.color : "")} />
                <span className="truncate">{config.label}</span>
              </button>
            );
          })}
        </div>

        <div className="flex bg-zinc-900/50 p-1 rounded-xl border border-zinc-800/50 self-end sm:self-auto">
          <button
            onClick={() => setViewMode('list')}
            className={cn(
              "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
              viewMode === 'list' ? "bg-zinc-800 text-white shadow-sm" : "text-zinc-400 hover:text-zinc-200"
            )}
          >
            Список
          </button>
          <button
            onClick={() => setViewMode('kanban')}
            className={cn(
              "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
              viewMode === 'kanban' ? "bg-zinc-800 text-white shadow-sm" : "text-zinc-400 hover:text-zinc-200"
            )}
          >
            Канбан
          </button>
        </div>
      </div>

      <AnimatePresence mode="wait">
        {isAdding ? (
          <motion.form
            key="form"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            onSubmit={handleSave}
            className="bg-zinc-900 p-4 sm:p-6 rounded-2xl border border-zinc-800 space-y-4"
          >
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-lg font-bold text-white">
                {editingId ? 'Редактировать' : 'Новая запись'}
              </h2>
              <button type="button" onClick={resetForm} className="text-zinc-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="text-xs text-zinc-400 mb-1 block">Название</label>
                <input
                  type="text"
                  value={title}
                  onChange={e => setTitle(e.target.value)}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-zinc-600"
                  placeholder={activeTab === 'book' ? 'Название книги' : 'Название цели/навыка'}
                  required
                />
              </div>

              {activeTab === 'book' && (
                <div>
                  <label className="text-xs text-zinc-400 mb-1 block">Автор</label>
                  <input
                    type="text"
                    value={author}
                    onChange={e => setAuthor(e.target.value)}
                    className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-zinc-600"
                    placeholder="Автор книги"
                  />
                </div>
              )}

              <div>
                <label className="text-xs text-zinc-400 mb-1 block">Описание</label>
                <textarea
                  value={description}
                  onChange={e => setDescription(e.target.value)}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-zinc-600 min-h-[80px]"
                  placeholder="Зачем вам это нужно? Что это даст?"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                {activeTab === 'book' ? (
                  <>
                    <div>
                      <label className="text-xs text-zinc-400 mb-1 block">Прочитано страниц</label>
                      <input
                        type="number"
                        value={readPages}
                        onChange={e => setReadPages(e.target.value)}
                        className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-zinc-600"
                        placeholder="0"
                        min="0"
                      />
                    </div>
                    <div>
                      <label className="text-xs text-zinc-400 mb-1 block">Всего страниц</label>
                      <input
                        type="number"
                        value={totalPages}
                        onChange={e => setTotalPages(e.target.value)}
                        className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-zinc-600"
                        placeholder="300"
                        min="1"
                      />
                    </div>
                  </>
                ) : (
                  <div>
                    <label className="text-xs text-zinc-400 mb-1 block">Дедлайн (необязательно)</label>
                    <input
                      type="date"
                      value={deadline}
                      onChange={e => setDeadline(e.target.value)}
                      className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-zinc-600"
                    />
                  </div>
                )}
              </div>

              {(activeTab === 'book' || activeTab === 'skill') && (
                <div>
                  <label className="text-xs text-zinc-400 mb-1 block">Обложка / Картинка</label>
                  {coverUrl ? (
                    <div className="relative inline-block">
                      <img src={coverUrl} alt="Cover" className="h-32 rounded-lg border border-zinc-800 object-cover" />
                      <button
                        type="button"
                        onClick={() => setCoverUrl('')}
                        className="absolute -top-2 -right-2 p-1 bg-red-500 rounded-full text-white hover:bg-red-600"
                      >
                        <X className="w-3 h-3" />
                      </button>
                    </div>
                  ) : (
                    <label className="flex flex-col items-center justify-center w-full h-32 border-2 border-zinc-800 border-dashed rounded-lg cursor-pointer hover:bg-zinc-800/50 transition-colors">
                      <div className="flex flex-col items-center justify-center pt-5 pb-6">
                        <ImagePlus className="w-8 h-8 text-zinc-500 mb-2" />
                        <p className="text-xs text-zinc-500">Нажмите для загрузки фото</p>
                      </div>
                      <input type="file" className="hidden" accept="image/*" onChange={handlePhotoUpload} />
                    </label>
                  )}
                </div>
              )}

              <button
                type="button"
                onClick={() => setShowOnDashboard(!showOnDashboard)}
                className={cn(
                  "w-full flex items-center justify-between p-3 rounded-xl border transition-all",
                  showOnDashboard 
                    ? "bg-indigo-500/10 border-indigo-500/50 text-indigo-400" 
                    : "bg-zinc-950 border-zinc-800 text-zinc-400 hover:bg-zinc-900 hover:text-zinc-300"
                )}
              >
                <span className="text-sm font-medium">Отображать на главной (Дашборд)</span>
                {showOnDashboard ? (
                  <CheckCircle2 className="w-5 h-5" />
                ) : (
                  <Circle className="w-5 h-5" />
                )}
              </button>
            </div>

            <div className="flex gap-3 pt-4">
              <button
                type="button"
                onClick={resetForm}
                className="flex-1 px-4 py-2 bg-zinc-800 text-white rounded-lg text-sm font-medium hover:bg-zinc-700 transition-colors"
              >
                Отмена
              </button>
              <button
                type="submit"
                className="flex-1 px-4 py-2 bg-zinc-100 text-zinc-900 rounded-lg text-sm font-medium hover:bg-white transition-colors"
              >
                Сохранить
              </button>
            </div>
          </motion.form>
        ) : viewMode === 'kanban' ? (
          <motion.div
            key="kanban"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="grid grid-cols-1 md:grid-cols-3 gap-6"
          >
            {(['not_started', 'in_progress', 'completed'] as GoalStatus[]).map((status) => {
              const statusGoals = filteredGoals.filter(g => g.status === status);
              const statusLabels = {
                not_started: 'К выполнению',
                in_progress: 'В процессе',
                completed: 'Завершено'
              };

              return (
                <div key={status} className="flex flex-col gap-4">
                  <div className="flex items-center justify-between px-2">
                    <div className="flex items-center gap-2">
                      <div className={cn("w-2 h-2 rounded-full", 
                        status === 'not_started' ? "bg-zinc-600" : 
                        status === 'in_progress' ? "bg-blue-500" : "bg-emerald-500"
                      )} />
                      <h3 className="text-sm font-bold text-white uppercase tracking-wider">{statusLabels[status]}</h3>
                      <span className="text-xs text-zinc-500 font-mono">({statusGoals.length})</span>
                    </div>
                  </div>

                  <div className="flex flex-col gap-3 min-h-[200px] p-2 rounded-2xl bg-zinc-900/30 border border-zinc-800/30">
                    {statusGoals.map((goal) => (
                      <div 
                        key={goal.id} 
                        className={cn(
                          "bg-zinc-900 p-4 rounded-xl border shadow-sm hover:border-zinc-700 transition-all group cursor-pointer",
                          goal.isPinned ? "border-indigo-500/50 ring-1 ring-indigo-500/20" : "border-zinc-800"
                        )}
                        onClick={() => setExpandedId(expandedId === goal.id ? null : goal.id)}
                      >
                        <div className="flex justify-between items-start mb-2">
                          <div className="flex items-center gap-2 min-w-0">
                            {goal.isPinned && <Pin className="w-3 h-3 text-indigo-400 shrink-0 fill-current" />}
                            <h4 className="text-sm font-bold text-white truncate pr-2">{goal.title}</h4>
                          </div>
                          <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                            <button 
                              onClick={(e) => { e.stopPropagation(); togglePin(goal.id, !!goal.isPinned); }} 
                              className={cn("p-1 transition-colors", goal.isPinned ? "text-indigo-400" : "text-zinc-500 hover:text-white")}
                            >
                              {goal.isPinned ? <PinOff className="w-3 h-3" /> : <Pin className="w-3 h-3" />}
                            </button>
                            <button 
                              onClick={(e) => { e.stopPropagation(); handleEdit(goal); }} 
                              className="p-1 text-zinc-500 hover:text-white"
                            >
                              <Edit2 className="w-3 h-3" />
                            </button>
                          </div>
                        </div>
                        
                        {goal.description && (
                          <p className="text-xs text-zinc-500 line-clamp-2 mb-3">{goal.description}</p>
                        )}

                        <div className="flex items-center justify-between mt-auto">
                          <div className="flex -space-x-2">
                            {goal.steps?.slice(0, 3).map((step) => (
                              <div 
                                key={step.id} 
                                className={cn(
                                  "w-5 h-5 rounded-full border-2 border-zinc-900 flex items-center justify-center",
                                  step.completed ? "bg-emerald-500" : "bg-zinc-800"
                                )}
                              >
                                {step.completed && <CheckCircle2 className="w-3 h-3 text-white" />}
                              </div>
                            ))}
                            {(goal.steps?.length || 0) > 3 && (
                              <div className="w-5 h-5 rounded-full border-2 border-zinc-900 bg-zinc-700 flex items-center justify-center text-[8px] text-white font-bold">
                                +{(goal.steps?.length || 0) - 3}
                              </div>
                            )}
                          </div>
                          
                          <select
                            value={goal.status}
                            onClick={e => e.stopPropagation()}
                            onChange={(e) => updateGoal(goal.id, { status: e.target.value as GoalStatus })}
                            className="bg-zinc-800 border-none text-[10px] text-zinc-400 rounded px-1.5 py-0.5 outline-none focus:ring-1 focus:ring-zinc-700"
                          >
                            <option value="not_started">К выполнению</option>
                            <option value="in_progress">В процессе</option>
                            <option value="completed">Завершено</option>
                          </select>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </motion.div>
        ) : (
          <motion.div
            key="list"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
          >
            {filteredGoals.length === 0 ? (
              <div className="col-span-full text-center py-12 bg-zinc-900/50 rounded-2xl border border-zinc-800/50">
                {(() => {
                  const Icon = TYPE_CONFIG[activeTab].icon;
                  return <Icon className="w-12 h-12 text-zinc-700 mx-auto mb-3" />;
                })()}
                <p className="text-zinc-400">Здесь пока ничего нет</p>
                <button
                  onClick={() => setIsAdding(true)}
                  className="mt-4 text-sm text-zinc-300 hover:text-white underline underline-offset-4"
                >
                  Добавить первую запись
                </button>
              </div>
            ) : (
              filteredGoals.map((goal) => {
                const progress = calculateProgress(goal);
                const isExpanded = expandedId === goal.id;

                return (
                  <div key={goal.id} className={cn(
                    "bg-zinc-900 rounded-2xl border overflow-hidden flex flex-col transition-all",
                    goal.isPinned ? "border-indigo-500/50 ring-1 ring-indigo-500/20" : "border-zinc-800"
                  )}>
                    <div className="p-4 flex-1">
                      <div className="flex gap-4">
                        {goal.type === 'book' && goal.totalPages ? (
                          <BookVisualization read={goal.readPages || 0} total={goal.totalPages} />
                        ) : goal.coverUrl ? (
                          <img src={goal.coverUrl} alt={goal.title} className="w-16 h-20 object-cover rounded-md border border-zinc-800 shrink-0" />
                        ) : null}
                        <div className="flex-1 min-w-0">
                          <div className="flex justify-between items-start">
                            <div className="flex items-center gap-2 min-w-0">
                              {goal.isPinned && <Pin className="w-3.5 h-3.5 text-indigo-400 shrink-0 fill-current" />}
                              <h3 className="text-base font-bold text-white truncate pr-2">{goal.title}</h3>
                            </div>
                            <div className="flex items-center gap-1 shrink-0">
                              <button 
                                onClick={() => togglePin(goal.id, !!goal.isPinned)} 
                                className={cn("p-1 transition-colors", goal.isPinned ? "text-indigo-400" : "text-zinc-500 hover:text-white")}
                                title={goal.isPinned ? "Открепить" : "Закрепить"}
                              >
                                {goal.isPinned ? <PinOff className="w-4 h-4" /> : <Pin className="w-4 h-4" />}
                              </button>
                              <button onClick={() => handleEdit(goal)} className="p-1 text-zinc-500 hover:text-white transition-colors">
                                <Edit2 className="w-4 h-4" />
                              </button>
                              <button onClick={() => deleteGoal(goal.id)} className="p-1 text-zinc-500 hover:text-red-400 transition-colors">
                                <Trash2 className="w-4 h-4" />
                              </button>
                            </div>
                          </div>
                          {goal.author && <p className="text-xs text-zinc-400 mt-0.5">{goal.author}</p>}
                          {goal.deadline && (
                            <p className="text-[10px] text-zinc-500 mt-1">Дедлайн: {new Date(goal.deadline).toLocaleDateString('ru-RU')}</p>
                          )}
                        </div>
                      </div>

                      {/* Progress Bar */}
                      <div className="mt-4">
                        <div className="flex justify-between text-xs mb-1.5">
                          <span className="text-zinc-400">Прогресс</span>
                          <span className="text-white font-medium">{progress}%</span>
                        </div>
                        <div className="h-2 bg-zinc-950 rounded-full overflow-hidden border border-zinc-800/50">
                          <div 
                            className={cn("h-full rounded-full transition-all duration-500", TYPE_CONFIG[goal.type].bg.replace('/10', ''))}
                            style={{ width: `${progress}%` }}
                          />
                        </div>
                        {goal.type === 'book' && goal.totalPages && (
                          <div className="text-[10px] text-zinc-500 mt-1 text-right">
                            {goal.readPages || 0} / {goal.totalPages} стр.
                          </div>
                        )}
                        <GoalProgressUpdate goal={goal} updateGoal={updateGoal} />
                      </div>
                    </div>

                    {/* Expandable Steps Section */}
                    {goal.type !== 'book' && (
                      <div className="border-t border-zinc-800/50 bg-zinc-950/30">
                        <button
                          onClick={() => setExpandedId(isExpanded ? null : goal.id)}
                          className="w-full flex items-center justify-between p-3 text-xs font-medium text-zinc-400 hover:text-zinc-200 transition-colors"
                        >
                          <span>Шаги ({goal.steps?.filter(s => s.completed).length || 0}/{goal.steps?.length || 0})</span>
                          {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                        </button>
                        
                        <AnimatePresence>
                          {isExpanded && (
                            <motion.div
                              initial={{ height: 0, opacity: 0 }}
                              animate={{ height: 'auto', opacity: 1 }}
                              exit={{ height: 0, opacity: 0 }}
                              className="overflow-hidden"
                            >
                              <div className="p-3 pt-0 space-y-2">
                                <div className="flex items-center justify-between mb-2">
                                  <h4 className="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider">Шаги</h4>
                                  <div className="flex items-center gap-1">
                                    <button
                                      onClick={() => handleDecompose(goal, false)}
                                      disabled={isDecomposing}
                                      className="flex items-center gap-1.5 px-2 py-1 bg-indigo-500/10 border border-indigo-500/20 rounded-lg text-[10px] font-medium text-indigo-400 hover:bg-indigo-500/20 transition-all disabled:opacity-50"
                                    >
                                      {isDecomposing ? (
                                        <Loader2 className="w-3 h-3 animate-spin" />
                                      ) : (
                                        <Sparkles className="w-3 h-3" />
                                      )}
                                      {isDecomposing ? 'Декомпозируем...' : (goal.steps && goal.steps.length > 0 ? 'Добавить (AI)' : 'Декомпозировать (AI)')}
                                    </button>
                                    {goal.steps && goal.steps.length > 0 && (
                                      <button
                                        onClick={() => {
                                          if (window.confirm('Вы уверены, что хотите заменить текущие шаги новыми от ИИ?')) {
                                            handleDecompose(goal, true);
                                          }
                                        }}
                                        disabled={isDecomposing}
                                        className="p-1 bg-zinc-800/50 border border-zinc-700/50 rounded-lg text-zinc-400 hover:text-white transition-all disabled:opacity-50"
                                        title="Перегенерировать план"
                                      >
                                        <RefreshCw className="w-3 h-3" />
                                      </button>
                                    )}
                                  </div>
                                </div>
                                {(!goal.steps || goal.steps.length === 0) && !isDecomposing && (
                                  <div className="text-center py-4 px-2 border border-dashed border-zinc-800 rounded-xl">
                                    <p className="text-[10px] text-zinc-500">У этой цели пока нет шагов. Используйте ИИ для декомпозиции или добавьте их вручную.</p>
                                  </div>
                                )}
                                {goal.steps?.map(step => (
                                  <div key={step.id} className="flex items-center gap-2 group">
                                    <button
                                      onClick={() => updateGoalStep(goal.id, step.id, { completed: !step.completed, status: !step.completed ? 'done' : 'todo' })}
                                      className="shrink-0 text-zinc-500 hover:text-white transition-colors"
                                    >
                                      {step.completed ? (
                                        <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                                      ) : (
                                        <Circle className="w-4 h-4" />
                                      )}
                                    </button>
                                    <span className={cn(
                                      "text-xs flex-1 transition-colors",
                                      step.completed ? "text-zinc-500 line-through" : "text-zinc-300"
                                    )}>
                                      {step.title}
                                    </span>
                                    
                                    <select
                                      value={step.status || (step.completed ? 'done' : 'todo')}
                                      onChange={(e) => {
                                        const newStatus = e.target.value as GoalStepStatus;
                                        updateGoalStep(goal.id, step.id, { 
                                          status: newStatus,
                                          completed: newStatus === 'done'
                                        });
                                      }}
                                      className="bg-transparent border-none text-[10px] text-zinc-500 outline-none focus:ring-0 cursor-pointer hover:text-zinc-300"
                                    >
                                      <option value="todo">To Do</option>
                                      <option value="in_progress">Doing</option>
                                      <option value="done">Done</option>
                                    </select>

                                    <button
                                      onClick={() => deleteGoalStep(goal.id, step.id)}
                                      className="opacity-0 group-hover:opacity-100 p-1 text-zinc-600 hover:text-red-400 transition-all"
                                    >
                                      <X className="w-3 h-3" />
                                    </button>
                                  </div>
                                ))}
                                
                                <form
                                  onSubmit={(e) => {
                                    e.preventDefault();
                                    const input = e.currentTarget.elements.namedItem('stepTitle') as HTMLInputElement;
                                    if (input.value.trim()) {
                                      addGoalStep(goal.id, { title: input.value.trim(), completed: false });
                                      input.value = '';
                                    }
                                  }}
                                  className="flex items-center gap-2 mt-2"
                                >
                                  <Plus className="w-4 h-4 text-zinc-600 shrink-0" />
                                  <input
                                    name="stepTitle"
                                    type="text"
                                    placeholder="Добавить шаг..."
                                    className="flex-1 bg-transparent border-none text-xs text-white focus:outline-none placeholder:text-zinc-600"
                                  />
                                </form>
                                
                                <GoalLogsSection goalId={goal.id} />
                              </div>
                            </motion.div>
                          )}
                        </AnimatePresence>
                      </div>
                    )}

                    {/* Expandable Book History Section */}
                    {goal.type === 'book' && (
                      <div className="border-t border-zinc-800/50 bg-zinc-950/30">
                        <button
                          onClick={() => setExpandedId(isExpanded ? null : goal.id)}
                          className="w-full flex items-center justify-between p-3 text-xs font-medium text-zinc-400 hover:text-zinc-200 transition-colors"
                        >
                          <span>История чтения и записи ({goal.progressHistory?.length || 0})</span>
                          {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                        </button>
                        
                        <AnimatePresence>
                          {isExpanded && (
                            <motion.div
                              initial={{ height: 0, opacity: 0 }}
                              animate={{ height: 'auto', opacity: 1 }}
                              exit={{ height: 0, opacity: 0 }}
                              className="overflow-hidden"
                            >
                              <div className="p-3 pt-0 space-y-2 max-h-40 overflow-y-auto">
                                {goal.progressHistory?.slice().reverse().map(entry => (
                                  <div key={entry.id} className="flex justify-between items-center bg-zinc-900 p-2 rounded-lg border border-zinc-800">
                                    <span className="text-xs text-zinc-400">
                                      {new Date(entry.date).toLocaleDateString()} {new Date(entry.date).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
                                    </span>
                                    <span className="text-xs font-medium text-white">{entry.note || `+${entry.value} стр.`}</span>
                                  </div>
                                ))}
                              </div>
                              <GoalLogsSection goalId={goal.id} />
                            </motion.div>
                          )}
                        </AnimatePresence>
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export function GoalProgressUpdate({ goal, updateGoal }: { goal: Goal, updateGoal: (id: string, updates: Partial<Goal>) => void }) {
  const [inputValue, setInputValue] = useState('');

  if (goal.type !== 'book' && goal.steps && goal.steps.length > 0) return null;

  const isBook = goal.type === 'book';

  const handleAdd = () => {
    const val = parseInt(inputValue);
    if (!isNaN(val) && val > 0) {
      if (isBook) {
        const newReadPages = Math.min((goal.readPages || 0) + val, goal.totalPages || Infinity);
        const historyEntry = {
          id: uuidv4(),
          date: new Date().toISOString(),
          value: val,
          note: `+${val} стр.`
        };
        updateGoal(goal.id, { 
          readPages: newReadPages,
          progressHistory: [...(goal.progressHistory || []), historyEntry]
        });
      } else {
        updateGoal(goal.id, { progress: Math.min((goal.progress || 0) + val, 100) });
      }
      setInputValue('');
    }
  };

  const handleSet = () => {
    const val = parseInt(inputValue);
    if (!isNaN(val) && val >= 0) {
      if (isBook) {
        const newReadPages = Math.min(val, goal.totalPages || Infinity);
        const diff = newReadPages - (goal.readPages || 0);
        if (diff !== 0) {
          const historyEntry = {
            id: uuidv4(),
            date: new Date().toISOString(),
            value: diff,
            note: `Установлено: ${newReadPages} стр.`
          };
          updateGoal(goal.id, { 
            readPages: newReadPages,
            progressHistory: [...(goal.progressHistory || []), historyEntry]
          });
        }
      } else {
        updateGoal(goal.id, { progress: Math.min(val, 100) });
      }
      setInputValue('');
    }
  };

  return (
    <div className="flex items-center gap-2 mt-3">
      <input 
        type="number" 
        value={inputValue}
        onChange={e => setInputValue(e.target.value)}
        placeholder={isBook ? "Стр." : "%"}
        className="w-16 bg-zinc-950 border border-zinc-800 rounded-lg px-2 py-1.5 text-xs text-white focus:outline-none focus:border-indigo-500"
      />
      <button onClick={handleAdd} className="px-2 py-1.5 bg-zinc-800 text-zinc-300 text-xs rounded-lg hover:bg-zinc-700 transition-colors">
        + {isBook ? 'Прочел' : 'Добавить'}
      </button>
      <button onClick={handleSet} className="px-2 py-1.5 bg-zinc-800 text-zinc-300 text-xs rounded-lg hover:bg-zinc-700 transition-colors">
        = {isBook ? 'Я на стр.' : 'Установить'}
      </button>
    </div>
  );
}
