import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Dumbbell, LineChart, User, Plus, Folder, Play, ChevronRight, ChevronLeft, ChevronDown, Edit2, Trash2, X, Video, Settings, Save, Calendar, Activity, Camera, ImageIcon, Timer, Check, Move, Sparkles, Award, Flame, Zap, TrendingUp, PieChart as PieChartIcon, Loader2 } from 'lucide-react';
import { useStore } from '../store/useStore';
import { cn } from '../lib/utils';
import { WorkoutNode, WorkoutMetric, BodyMeasurement, PlannedWorkoutStatus, PlannedWorkout, MuscleGroup } from '../types';
import { LineChart as RechartsLineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts';
import { WorkoutTimer } from '../components/WorkoutTimer';
import { MuscleHeatmap } from '../components/MuscleHeatmap';
import { CameraTracker } from '../components/CameraTracker';
import { HistoryTab } from '../components/HistoryTab';
import { generateWorkout } from '../services/aiService';

export function Workouts() {
  const [activeTab, setActiveTab] = useState<'workouts' | 'calendar' | 'analytics' | 'profile' | 'history'>('workouts');

  return (
    <div className="space-y-6 pb-24">
      <header>
        <h1 className="text-xl font-bold text-zinc-900 mb-2">Занятия</h1>
        <p className="text-zinc-500">Тренировки, прогресс и измерения</p>
      </header>

      {/* Tabs */}
      <div className="grid grid-cols-5 gap-1 bg-white/60 p-1 rounded-xl">
        <button
          onClick={() => setActiveTab('workouts')}
          className={cn(
            "flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-2 py-2 rounded-lg text-[10px] sm:text-sm font-medium transition-all",
            activeTab === 'workouts' ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-800"
          )}
        >
          <Dumbbell className="w-4 h-4 sm:w-4 sm:h-4" />
          <span>Программы</span>
        </button>
        <button
          onClick={() => setActiveTab('calendar')}
          className={cn(
            "flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-2 py-2 rounded-lg text-[10px] sm:text-sm font-medium transition-all",
            activeTab === 'calendar' ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-800"
          )}
        >
          <Calendar className="w-4 h-4 sm:w-4 sm:h-4" />
          <span>Календарь</span>
        </button>
        <button
          onClick={() => setActiveTab('analytics')}
          className={cn(
            "flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-2 py-2 rounded-lg text-[10px] sm:text-sm font-medium transition-all",
            activeTab === 'analytics' ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-800"
          )}
        >
          <LineChart className="w-4 h-4 sm:w-4 sm:h-4" />
          <span>Аналитика</span>
        </button>
        <button
          onClick={() => setActiveTab('history')}
          className={cn(
            "flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-2 py-2 rounded-lg text-[10px] sm:text-sm font-medium transition-all",
            activeTab === 'history' ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-800"
          )}
        >
          <Timer className="w-4 h-4 sm:w-4 sm:h-4" />
          <span>История</span>
        </button>
        <button
          onClick={() => setActiveTab('profile')}
          className={cn(
            "flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-2 py-2 rounded-lg text-[10px] sm:text-sm font-medium transition-all",
            activeTab === 'profile' ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-800"
          )}
        >
          <User className="w-4 h-4 sm:w-4 sm:h-4" />
          <span>Профиль</span>
        </button>
      </div>

      <motion.div
        key={activeTab}
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.2 }}
      >
        {activeTab === 'workouts' && <WorkoutsTab />}
        {activeTab === 'calendar' && <CalendarTab />}
        {activeTab === 'analytics' && <AnalyticsTab />}
        {activeTab === 'history' && <HistoryTab />}
        {activeTab === 'profile' && <ProfileTab />}
      </motion.div>

      <WorkoutTimer />
    </div>
  );
}

function WorkoutsTab() {
  const { workoutNodes, addWorkoutNode, updateWorkoutNode, deleteWorkoutNode, exerciseLogs } = useStore();
  const [isAddingRoot, setIsAddingRoot] = useState(false);
  const [newRootName, setNewRootName] = useState('');
  const [selectedExercise, setSelectedExercise] = useState<WorkoutNode | null>(null);
  const [isGenerating, setIsGenerating] = useState(false);
  const [genParams, setGenParams] = useState({ duration: 60, focus: 'general', equipment: 'all' });
  const [showCamera, setShowCamera] = useState(false);

  const handleAddRoot = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newRootName.trim()) return;
    addWorkoutNode({
      parentId: null,
      name: newRootName.trim(),
      type: 'folder'
    });
    setNewRootName('');
    setIsAddingRoot(false);
  };

  const handleGenerateWorkout = async () => {
    setIsGenerating(true);
    try {
      const muscleGroups: MuscleGroup[] = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];
      const targetGroup = muscleGroups[Math.floor(Math.random() * muscleGroups.length)];
      
      const workout = await generateWorkout(
        process.env.GEMINI_API_KEY!,
        exerciseLogs,
        [targetGroup],
        genParams.duration,
        genParams.focus,
        genParams.equipment.split(',').map(e => e.trim())
      );

      if (workout) {
        // Create a folder for the generated workout
        const folderId = addWorkoutNode({
          parentId: null,
          name: workout.title || workout.name,
          type: 'folder',
          isTemplate: true
        });

        // Add exercises to the folder
        workout.exercises.forEach((ex: any) => {
          addWorkoutNode({
            parentId: folderId,
            name: ex.name,
            type: 'exercise',
            notes: ex.notes,
            metrics: ['weight', 'reps'],
            muscleGroup: targetGroup
          });
        });
      }
    } catch (error) {
      console.error(error);
    } finally {
      setIsGenerating(false);
    }
  };

  const rootNodes = workoutNodes.filter(n => n.parentId === null);

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-semibold text-zinc-900">Мои программы</h2>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowCamera(true)}
            className="p-2 bg-stone-100 text-zinc-900 rounded-lg hover:bg-stone-200 transition-colors"
            title="Тренировка с камерой"
          >
            <Camera className="w-5 h-5" />
          </button>
          <button
            onClick={handleGenerateWorkout}
            disabled={isGenerating}
            className="flex items-center gap-2 px-3 py-2 bg-indigo-500/10 border border-indigo-500/20 rounded-lg text-xs font-medium text-indigo-400 hover:bg-indigo-500/20 transition-all disabled:opacity-50"
          >
            {isGenerating ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <Sparkles className="w-4 h-4" />
            )}
            {isGenerating ? 'Генерируем...' : 'AI План'}
          </button>
          <button
            onClick={() => setIsAddingRoot(true)}
            className="p-2 bg-stone-100 text-zinc-900 rounded-lg hover:bg-stone-200 transition-colors"
          >
            <Plus className="w-5 h-5" />
          </button>
        </div>
      </div>

      {showCamera && <CameraTracker onClose={() => setShowCamera(false)} />}

      {isAddingRoot && (
        <form onSubmit={handleAddRoot} className="flex flex-col gap-2">
          <input
            type="text"
            value={newRootName}
            onChange={(e) => setNewRootName(e.target.value)}
            placeholder="Название категории (например, Зал)"
            className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-zinc-600"
            autoFocus
          />
          <div className="flex gap-2">
            <button type="submit" className="flex-1 px-4 py-2 bg-white text-black rounded-lg font-medium">
              Добавить
            </button>
            <button type="button" onClick={() => setIsAddingRoot(false)} className="flex-1 px-4 py-2 bg-stone-100 text-zinc-900 rounded-lg">
              Отмена
            </button>
          </div>
        </form>
      )}

      <div className="bg-white/60 p-4 rounded-xl border border-stone-200 space-y-3">
        <div className="grid grid-cols-3 gap-2">
          <input type="number" value={genParams.duration} onChange={e => setGenParams({...genParams, duration: parseInt(e.target.value)})} placeholder="Минуты" className="bg-stone-100 rounded px-2 py-1 text-xs text-zinc-900" />
          <input type="text" value={genParams.focus} onChange={e => setGenParams({...genParams, focus: e.target.value})} placeholder="Акцент" className="bg-stone-100 rounded px-2 py-1 text-xs text-zinc-900" />
          <input type="text" value={genParams.equipment} onChange={e => setGenParams({...genParams, equipment: e.target.value})} placeholder="Оборудование" className="bg-stone-100 rounded px-2 py-1 text-xs text-zinc-900" />
        </div>
      </div>

      <div className="space-y-2">
        {rootNodes.map(node => (
          <WorkoutNodeItem key={node.id} node={node} level={0} onSelectExercise={setSelectedExercise} />
        ))}
        {rootNodes.length === 0 && !isAddingRoot && (
          <p className="text-zinc-500 text-center py-8">Нет категорий. Создайте первую!</p>
        )}
      </div>

      <AnimatePresence>
        {selectedExercise && (
          <ExerciseModal exercise={selectedExercise} onClose={() => setSelectedExercise(null)} />
        )}
      </AnimatePresence>
    </div>
  );
}

interface WorkoutNodeItemProps {
  node: WorkoutNode;
  level: number;
  onSelectExercise: (node: WorkoutNode) => void;
  key?: string | number;
}

function WorkoutNodeItem({ node, level, onSelectExercise }: WorkoutNodeItemProps) {
  const [isMoving, setIsMoving] = useState(false);
  const { workoutNodes, addWorkoutNode, updateWorkoutNode, deleteWorkoutNode, moveWorkoutNode } = useStore();
  const [isExpanded, setIsExpanded] = useState(false);
  const [isAdding, setIsAdding] = useState<'folder' | 'exercise' | null>(null);
  const [newName, setNewName] = useState('');
  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState(node.name);
  
  const folders = workoutNodes.filter(n => n.type === 'folder' && n.id !== node.id);
  
  const handleMove = (newParentId: string | null) => {
    moveWorkoutNode(node.id, newParentId);
    setIsMoving(false);
  };

  const children = workoutNodes.filter(n => n.parentId === node.id);

  const handleAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newName.trim() || !isAdding) return;
    addWorkoutNode({
      parentId: node.id,
      name: newName.trim(),
      type: isAdding,
      metrics: isAdding === 'exercise' ? ['weight', 'reps'] : undefined
    });
    setNewName('');
    setIsAdding(null);
    setIsExpanded(true);
  };

  const handleEdit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!editName.trim()) return;
    updateWorkoutNode(node.id, { name: editName.trim() });
    setIsEditing(false);
  };

  return (
    <div className="space-y-1">
      <div 
        className={cn(
          "flex flex-col p-3 rounded-xl border transition-colors group",
          node.type === 'folder' ? "bg-white/60 border-stone-200" : "bg-stone-50 border-stone-200/70 hover:bg-white cursor-pointer"
        )}
        style={{ marginLeft: level > 0 ? `${level * 16}px` : 0 }}
        onClick={() => node.type === 'exercise' && onSelectExercise(node)}
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3 flex-1">
            {node.type === 'folder' && (
              <button 
                onClick={(e) => { e.stopPropagation(); setIsExpanded(!isExpanded); }} 
                className="text-zinc-500 hover:text-zinc-900"
              >
                {isExpanded ? <ChevronDown className="w-5 h-5" /> : <ChevronRight className="w-5 h-5" />}
              </button>
            )}
            {node.type === 'folder' ? <Folder className="w-5 h-5 text-zinc-500" /> : <Dumbbell className="w-5 h-5 text-zinc-500" />}
            
            {isEditing ? (
              <form onSubmit={handleEdit} className="flex-1 flex gap-2">
                <input
                  type="text"
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                  className="flex-1 bg-stone-100 border-none rounded px-2 py-1 text-zinc-900 text-sm focus:outline-none"
                  autoFocus
                  onBlur={handleEdit}
                />
              </form>
            ) : (
              <span className="text-zinc-800 font-medium">{node.name}</span>
            )}
          </div>

          <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity" onClick={e => e.stopPropagation()}>
            {node.type === 'folder' && (
              <>
                <button 
                  onClick={() => updateWorkoutNode(node.id, { isTemplate: !node.isTemplate })} 
                  className={cn(
                    "p-1.5 rounded-lg transition-colors",
                    node.isTemplate ? "text-emerald-400 bg-emerald-400/10" : "text-zinc-500 hover:text-zinc-900 hover:bg-stone-100"
                  )}
                  title={node.isTemplate ? "Убрать из шаблонов" : "Сделать шаблоном"}
                >
                  <Sparkles className={cn("w-4 h-4", node.isTemplate && "fill-current")} />
                </button>
                <button onClick={() => setIsAdding('folder')} className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg" title="Добавить папку">
                  <Folder className="w-4 h-4" />
                </button>
                <button onClick={() => setIsAdding('exercise')} className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg" title="Добавить упражнение">
                  <Dumbbell className="w-4 h-4" />
                </button>
              </>
            )}
            <button onClick={() => setIsMoving(!isMoving)} className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg" title="Переместить">
              <Move className="w-4 h-4" />
            </button>
            <button onClick={() => setIsEditing(true)} className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg">
              <Edit2 className="w-4 h-4" />
            </button>
            <button onClick={() => deleteWorkoutNode(node.id)} className="p-1.5 text-red-400 hover:text-red-300 hover:bg-red-400/10 rounded-lg">
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        </div>

        {isMoving && (
          <div className="px-4 py-2 bg-white/60 border-b border-stone-200 flex items-center gap-2" onClick={e => e.stopPropagation()}>
            <span className="text-xs text-zinc-500">Переместить в:</span>
            <select 
              className="bg-stone-100 border-stone-300 text-xs rounded px-2 py-1 outline-none text-zinc-900"
              value={node.parentId || ''}
              onChange={(e) => handleMove(e.target.value || null)}
            >
              <option value="">Корень</option>
              {folders.map(f => (
                <option key={f.id} value={f.id}>{f.name}</option>
              ))}
            </select>
            <button onClick={() => setIsMoving(false)} className="p-1 text-zinc-500 hover:text-zinc-900">
              <X className="w-3 h-3" />
            </button>
          </div>
        )}

        {/* Display notes and video for exercises */}
        {node.type === 'exercise' && (node.notes || node.videoUrl) && (
          <div className="mt-2 pl-8 space-y-2">
            {node.notes && (
              <p className="text-xs text-zinc-500 whitespace-pre-wrap">{node.notes}</p>
            )}
            {node.videoUrl && (
              <a 
                href={node.videoUrl} 
                target="_blank" 
                rel="noopener noreferrer"
                onClick={(e) => e.stopPropagation()}
                className="inline-flex items-center gap-1.5 text-xs text-indigo-400 hover:text-indigo-300 transition-colors"
              >
                <Video className="w-3.5 h-3.5" />
                Смотреть видео
              </a>
            )}
          </div>
        )}
      </div>

      {isAdding && (
        <div style={{ marginLeft: `${(level + 1) * 16}px` }} className="mt-2">
          <form onSubmit={handleAdd} className="flex flex-col gap-2">
            <input
              type="text"
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              placeholder={isAdding === 'folder' ? "Название папки" : "Название упражнения"}
              className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm focus:outline-none focus:border-zinc-600"
              autoFocus
            />
            <div className="flex gap-2">
              <button type="submit" className="flex-1 px-3 py-1.5 bg-white text-black rounded-lg text-sm font-medium">
                Добавить
              </button>
              <button type="button" onClick={() => setIsAdding(null)} className="flex-1 px-3 py-1.5 bg-stone-100 text-zinc-900 rounded-lg text-sm">
                Отмена
              </button>
            </div>
          </form>
        </div>
      )}

      {isExpanded && children.length > 0 && (
        <div className="mt-1 space-y-1">
          {children.map(child => (
            <WorkoutNodeItem key={child.id} node={child} level={level + 1} onSelectExercise={onSelectExercise} />
          ))}
        </div>
      )}
    </div>
  );
}

function ExerciseModal({ exercise, onClose }: { exercise: WorkoutNode, onClose: () => void }) {
  const { updateWorkoutNode, logExercise, exerciseLogs } = useStore();
  const [isEditing, setIsEditing] = useState(false);
  const [notes, setNotes] = useState(exercise.notes || '');
  const [videoUrl, setVideoUrl] = useState(exercise.videoUrl || '');
  const [restTime, setRestTime] = useState(exercise.restTime?.toString() || '');
  const [muscleGroup, setMuscleGroup] = useState<MuscleGroup | ''>(exercise.muscleGroup || '');
  const [metrics, setMetrics] = useState<WorkoutMetric[]>(exercise.metrics || ['weight', 'reps']);
  
  const logs = exerciseLogs.filter(l => l.exerciseId === exercise.id).sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  const lastLog = logs[0];

  const [logValues, setLogValues] = useState<Partial<Record<WorkoutMetric, number>>>(lastLog?.metrics || {});
  const [logRestTime, setLogRestTime] = useState<string>(exercise.restTime?.toString() || '');

  const availableMetrics: { id: WorkoutMetric, label: string }[] = [
    { id: 'weight', label: 'Вес (кг)' },
    { id: 'reps', label: 'Повторения' },
    { id: 'distance', label: 'Дистанция (км)' },
    { id: 'time', label: 'Время (мин)' },
    { id: 'speed', label: 'Скорость (км/ч)' },
    { id: 'calories', label: 'Калории (ккал)' },
  ];

  const availableMuscleGroups: { id: MuscleGroup, label: string }[] = [
    { id: 'chest', label: 'Грудь' },
    { id: 'back', label: 'Спина' },
    { id: 'legs', label: 'Ноги' },
    { id: 'shoulders', label: 'Плечи' },
    { id: 'arms', label: 'Руки' },
    { id: 'core', label: 'Пресс / Кор' },
    { id: 'cardio', label: 'Кардио' },
  ];

  const handleSaveSettings = () => {
    updateWorkoutNode(exercise.id, { 
      notes, 
      videoUrl, 
      metrics,
      restTime: restTime ? parseInt(restTime, 10) : undefined,
      muscleGroup: muscleGroup || undefined
    });
    setLogRestTime(restTime);
    setIsEditing(false);
  };

  const handleLog = () => {
    if (Object.keys(logValues).length === 0) return;
    logExercise({
      exerciseId: exercise.id,
      date: new Date().toISOString().split('T')[0],
      metrics: logValues,
      restTime: logRestTime ? parseInt(logRestTime, 10) : undefined
    });
    
    // Start rest timer if configured
    if (logRestTime) {
      useStore.getState().startTimer(parseInt(logRestTime, 10));
    }
  };

  // Group logs by date
  const groupedLogs = logs.reduce((acc, log) => {
    if (!acc[log.date]) {
      acc[log.date] = [];
    }
    acc[log.date].push(log);
    return acc;
  }, {} as Record<string, typeof logs>);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-white/80 backdrop-blur-sm">
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.95 }}
        className="bg-white border border-stone-200 rounded-2xl w-full max-w-2xl max-h-[90dvh] overflow-hidden flex flex-col"
      >
        <div className="p-4 border-b border-stone-200 flex justify-between items-center shrink-0">
          <h3 className="text-xl font-bold text-zinc-900 flex items-center gap-2">
            <Dumbbell className="w-5 h-5 text-zinc-500" />
            {exercise.name}
          </h3>
          <div className="flex items-center gap-2">
            <button onClick={() => setIsEditing(!isEditing)} className="p-2 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg transition-colors">
              <Settings className="w-5 h-5" />
            </button>
            <button onClick={onClose} className="p-2 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg transition-colors">
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-4 pb-24 space-y-6">
          {isEditing ? (
            <div className="space-y-4 bg-stone-50 p-4 rounded-xl border border-stone-200">
              <h4 className="font-medium text-zinc-900">Настройки упражнения</h4>
              
              <div className="space-y-2">
                <label className="text-sm text-zinc-500">Заметки / Описание</label>
                <textarea
                  value={notes}
                  onChange={e => setNotes(e.target.value)}
                  className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm min-h-[80px]"
                  placeholder="Опишите технику или важные детали..."
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm text-zinc-500">Ссылка на видео (YouTube)</label>
                <div className="flex items-center gap-2">
                  <Video className="w-4 h-4 text-zinc-500" />
                  <input
                    type="text"
                    value={videoUrl}
                    onChange={e => setVideoUrl(e.target.value)}
                    className="flex-1 bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                    placeholder="https://youtube.com/..."
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-sm text-zinc-500">Время отдыха (в секундах)</label>
                <div className="flex items-center gap-2">
                  <Timer className="w-4 h-4 text-zinc-500" />
                  <input
                    type="number"
                    value={restTime}
                    onChange={e => setRestTime(e.target.value)}
                    className="flex-1 bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                    placeholder="Например: 90"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-sm text-zinc-500">Группа мышц</label>
                <select
                  value={muscleGroup}
                  onChange={e => setMuscleGroup(e.target.value as MuscleGroup | '')}
                  className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm focus:outline-none focus:border-zinc-600"
                >
                  <option value="">Не выбрано</option>
                  {availableMuscleGroups.map(mg => (
                    <option key={mg.id} value={mg.id}>{mg.label}</option>
                  ))}
                </select>
              </div>

              <div className="space-y-2">
                <label className="text-sm text-zinc-500">Отслеживаемые показатели</label>
                <div className="flex flex-wrap gap-2">
                  {availableMetrics.map(m => (
                    <button
                      key={m.id}
                      onClick={() => {
                        if (metrics.includes(m.id)) {
                          setMetrics(metrics.filter(id => id !== m.id));
                        } else {
                          setMetrics([...metrics, m.id]);
                        }
                      }}
                      className={cn(
                        "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors border",
                        metrics.includes(m.id) 
                          ? "bg-white text-black border-white" 
                          : "bg-white text-zinc-500 border-stone-200 hover:border-zinc-600"
                      )}
                    >
                      {m.label}
                    </button>
                  ))}
                </div>
              </div>

              <button onClick={handleSaveSettings} className="w-full py-2 bg-white text-black rounded-lg font-medium flex items-center justify-center gap-2">
                <Save className="w-4 h-4" />
                Сохранить настройки
              </button>
            </div>
          ) : (
            <>
              {(exercise.notes || exercise.videoUrl || exercise.restTime) && (
                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200 space-y-4">
                  {exercise.notes && (
                    <div className="text-sm text-zinc-700 whitespace-pre-wrap">{exercise.notes}</div>
                  )}
                  <div className="flex flex-wrap items-center gap-4">
                    {exercise.videoUrl && (
                      <a href={exercise.videoUrl} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-2 text-sm text-blue-400 hover:text-blue-300">
                        <Play className="w-4 h-4" />
                        Смотреть видео
                      </a>
                    )}
                    {exercise.restTime && (
                      <div className="inline-flex items-center gap-2 text-sm text-zinc-500">
                        <Timer className="w-4 h-4" />
                        Отдых: {exercise.restTime} сек
                      </div>
                    )}
                  </div>
                </div>
              )}

              <div className="bg-stone-50 p-4 rounded-xl border border-stone-200 space-y-4">
                <h4 className="font-medium text-zinc-900">Добавить подход / запись</h4>
                <div className="flex flex-wrap gap-3 items-end">
                  {metrics.map(metricId => {
                    const metricDef = availableMetrics.find(m => m.id === metricId);
                    if (!metricDef) return null;
                    return (
                      <div key={metricId} className="space-y-1 flex-1 min-w-[120px]">
                        <label className="text-xs text-zinc-500">{metricDef.label}</label>
                        <input
                          type="number"
                          value={logValues[metricId] || ''}
                          onChange={e => setLogValues({ ...logValues, [metricId]: parseFloat(e.target.value) })}
                          className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                          placeholder="0"
                        />
                      </div>
                    );
                  })}
                  <div className="space-y-1 flex-1 min-w-[120px]">
                    <label className="text-xs text-zinc-500">Отдых (сек)</label>
                    <input
                      type="number"
                      value={logRestTime}
                      onChange={e => setLogRestTime(e.target.value)}
                      className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                      placeholder="0"
                    />
                  </div>
                  <button onClick={handleLog} className="px-4 py-2 bg-white text-black rounded-lg font-medium h-[38px]">
                    Записать
                  </button>
                </div>
              </div>

              <div className="space-y-3">
                <h4 className="font-medium text-zinc-900">История</h4>
                {Object.keys(groupedLogs).length === 0 ? (
                  <p className="text-sm text-zinc-500">Пока нет записей. Добавьте первую!</p>
                ) : (
                  <div className="space-y-4">
                    {Object.entries(groupedLogs).map(([date, dayLogs]) => (
                      <div key={date} className="bg-white/60 rounded-xl border border-stone-200/70 overflow-hidden">
                        <div className="bg-white px-4 py-2 border-b border-stone-200/70 flex items-center gap-2">
                          <Calendar className="w-4 h-4 text-zinc-500" />
                          <span className="text-sm font-medium text-zinc-800">
                            {new Date(date).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' })}
                          </span>
                        </div>
                        <div className="divide-y divide-stone-200/50">
                          {dayLogs.map((log, index) => (
                            <div key={log.id} className="p-3 flex justify-between items-center hover:bg-stone-100/20 transition-colors">
                              <span className="text-xs text-zinc-500 font-medium w-6">#{dayLogs.length - index}</span>
                              <div className="flex gap-4 flex-1 justify-end items-center">
                                {Object.entries(log.metrics).map(([key, val]) => {
                                  const label = availableMetrics.find(m => m.id === key)?.label.split(' ')[0] || key;
                                  return (
                                    <div key={key} className="text-sm flex items-baseline gap-1.5">
                                      <span className="text-zinc-900 font-medium">{val}</span>
                                      <span className="text-zinc-500 text-xs">{label}</span>
                                    </div>
                                  );
                                })}
                                {log.restTime && (
                                  <div className="text-sm flex items-baseline gap-1.5">
                                    <span className="text-zinc-900 font-medium">{log.restTime}</span>
                                    <span className="text-zinc-500 text-xs">сек отдых</span>
                                  </div>
                                )}
                                <button
                                  onClick={() => useStore.getState().deleteExerciseLog(log.id)}
                                  className="p-1 text-zinc-500 hover:text-red-400 transition-colors ml-2"
                                >
                                  <X className="w-4 h-4" />
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </>
          )}
        </div>
      </motion.div>
    </div>
  );
}

function CalendarModal({ 
  date, 
  onClose 
}: { 
  date: string; 
  onClose: () => void;
}) {
  const { plannedWorkouts = [], togglePlannedWorkout, updatePlannedWorkout, workoutNodes = [], exerciseLogs = [] } = useStore();
  const existing = plannedWorkouts.find(p => p.date === date);
  
  const [status, setStatus] = useState<PlannedWorkoutStatus | null>(existing?.status || null);
  const [programId, setProgramId] = useState<string>(existing?.programId || '');
  const [label, setLabel] = useState<string>(existing?.label || '');

  const folders = workoutNodes.filter(n => n.type === 'folder');
  const templates = folders.filter(f => f.isTemplate);
  
  const logsForDate = exerciseLogs.filter(l => l.date === date);
  const uniqueExerciseIds = Array.from(new Set(logsForDate.map(l => l.exerciseId)));
  const loggedExercises = uniqueExerciseIds.map(id => workoutNodes.find(n => n.id === id)).filter(Boolean) as WorkoutNode[];

  const handleSave = () => {
    if (status === null) {
      togglePlannedWorkout(date, null);
    } else {
      if (!existing) {
        togglePlannedWorkout(date, status);
        if (programId || label) {
          updatePlannedWorkout(date, { programId, label });
        }
      } else {
        updatePlannedWorkout(date, { status, programId, label });
      }
    }
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-zinc-900/30 backdrop-blur-sm">
      <div className="bg-white border border-stone-200 rounded-2xl p-6 w-full max-w-md space-y-6">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold text-zinc-900">Тренировка на {date}</h3>
          <button onClick={onClose} className="text-zinc-500 hover:text-zinc-900">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-zinc-500 mb-1">Статус</label>
            <div className="grid grid-cols-4 gap-2">
              <button
                onClick={() => setStatus(null)}
                className={cn("p-2 rounded-lg text-sm border transition-colors", status === null ? "bg-stone-100 border-stone-300 text-zinc-900" : "border-stone-200/70 text-zinc-500 hover:bg-stone-100/60")}
              >
                Нет
              </button>
              <button
                onClick={() => setStatus('planned')}
                className={cn("p-2 rounded-lg text-sm border transition-colors", status === 'planned' ? "bg-blue-500/20 border-blue-500/50 text-blue-400" : "border-stone-200/70 text-zinc-500 hover:bg-stone-100/60")}
              >
                План
              </button>
              <button
                onClick={() => setStatus('completed')}
                className={cn("p-2 rounded-lg text-sm border transition-colors", status === 'completed' ? "bg-emerald-500/20 border-emerald-500/50 text-emerald-400" : "border-stone-200/70 text-zinc-500 hover:bg-stone-100/60")}
              >
                Готово
              </button>
              <button
                onClick={() => setStatus('missed')}
                className={cn("p-2 rounded-lg text-sm border transition-colors", status === 'missed' ? "bg-red-500/20 border-red-500/50 text-red-400" : "border-stone-200/70 text-zinc-500 hover:bg-stone-100/60")}
              >
                Пропуск
              </button>
            </div>
          </div>

          {status !== null && (
            <>
              {templates.length > 0 && (
                <div>
                  <label className="block text-sm font-medium text-zinc-500 mb-2">Шаблоны</label>
                  <div className="flex flex-wrap gap-2">
                    {templates.map(t => (
                      <button
                        key={t.id}
                        onClick={() => {
                          setProgramId(t.id);
                          setLabel(t.name);
                        }}
                        className={cn(
                          "px-3 py-1.5 rounded-lg text-xs font-medium border transition-colors flex items-center gap-1.5",
                          programId === t.id 
                            ? "bg-emerald-500/20 border-emerald-500/50 text-emerald-400" 
                            : "bg-stone-50 border-stone-200 text-zinc-500 hover:border-stone-300"
                        )}
                      >
                        <Sparkles className="w-3 h-3" />
                        {t.name}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-zinc-500 mb-1">Программа / Папка</label>
                <select
                  value={programId}
                  onChange={(e) => setProgramId(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-xl px-4 py-3 text-zinc-900 focus:outline-none focus:border-emerald-500/50"
                >
                  <option value="">Без программы</option>
                  {folders.map(f => (
                    <option key={f.id} value={f.id}>{f.name}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-zinc-500 mb-1">Подпись (например, "День ног")</label>
                <input
                  type="text"
                  value={label}
                  onChange={(e) => setLabel(e.target.value)}
                  placeholder="Введите подпись..."
                  className="w-full bg-stone-50 border border-stone-200 rounded-xl px-4 py-3 text-zinc-900 placeholder:text-zinc-400 focus:outline-none focus:border-emerald-500/50"
                />
              </div>
            </>
          )}

          {loggedExercises.length > 0 && (
            <div>
              <label className="block text-sm font-medium text-zinc-500 mb-2">Выполненные упражнения</label>
              <div className="space-y-2 max-h-40 overflow-y-auto pr-2">
                {loggedExercises.map(ex => {
                  const exLogs = logsForDate.filter(l => l.exerciseId === ex.id);
                  return (
                    <div key={ex.id} className="bg-stone-50 border border-stone-200 rounded-lg p-3 flex justify-between items-center">
                      <span className="text-sm text-zinc-900 font-medium">{ex.name}</span>
                      <span className="text-xs text-zinc-500">{exLogs.length} {exLogs.length === 1 ? 'подход' : exLogs.length > 1 && exLogs.length < 5 ? 'подхода' : 'подходов'}</span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        <div className="flex gap-3">
          {existing && date !== new Date().toISOString().split('T')[0] && (
            <button
              onClick={() => {
                const today = new Date().toISOString().split('T')[0];
                const todayExisting = plannedWorkouts.find(p => p.date === today);
                if (!todayExisting) {
                  togglePlannedWorkout(today, 'planned');
                }
                updatePlannedWorkout(today, { 
                  programId: existing.programId, 
                  label: existing.label,
                  status: 'planned'
                });
                onClose();
              }}
              className="flex-1 bg-blue-500 hover:bg-blue-600 text-zinc-900 font-medium py-3 rounded-xl transition-colors"
            >
              Копировать на сегодня
            </button>
          )}
          <button
            onClick={handleSave}
            className="flex-1 bg-emerald-500 hover:bg-emerald-600 text-zinc-900 font-medium py-3 rounded-xl transition-colors"
          >
            Сохранить
          </button>
        </div>
      </div>
    </div>
  );
}

function CalendarTab() {
  const { plannedWorkouts = [], togglePlannedWorkout, workoutNodes = [] } = useStore();
  const [currentDate, setCurrentDate] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState<string | null>(null);

  const getDaysInMonth = (date: Date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const firstDayOfMonth = new Date(year, month, 1).getDay();
    
    // Adjust for Monday as first day of week
    const startingDay = firstDayOfMonth === 0 ? 6 : firstDayOfMonth - 1;
    
    return { daysInMonth, startingDay };
  };

  const { daysInMonth, startingDay } = getDaysInMonth(currentDate);

  const prevMonth = () => {
    setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1));
  };

  const nextMonth = () => {
    setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1));
  };

  const monthNames = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
  ];

  const weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  const handleDayClick = (day: number) => {
    const dateStr = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    setSelectedDate(dateStr);
  };

  return (
    <div className="space-y-6">
      <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold text-zinc-900 capitalize">
            {monthNames[currentDate.getMonth()]} {currentDate.getFullYear()}
          </h2>
          <div className="flex items-center gap-2">
            <button onClick={prevMonth} className="p-2 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg transition-colors">
              <ChevronLeft className="w-5 h-5" />
            </button>
            <button onClick={nextMonth} className="p-2 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg transition-colors">
              <ChevronRight className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="grid grid-cols-7 gap-2 mb-2">
          {weekDays.map(day => (
            <div key={day} className="text-center text-xs font-medium text-zinc-500 py-1">
              {day}
            </div>
          ))}
        </div>

        <div className="grid grid-cols-7 gap-2">
          {Array.from({ length: startingDay }).map((_, i) => (
            <div key={`empty-${i}`} className="aspect-square" />
          ))}
          
          {Array.from({ length: daysInMonth }).map((_, i) => {
            const day = i + 1;
            const dateStr = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            const planned = plannedWorkouts.find(p => p.date === dateStr);
            const program = planned?.programId ? workoutNodes.find(n => n.id === planned.programId) : null;
            const displayLabel = planned?.label || program?.name;
            
            const isToday = new Date().toISOString().split('T')[0] === dateStr;

            return (
              <button
                key={day}
                onClick={() => handleDayClick(day)}
                className={cn(
                  "min-h-[60px] sm:min-h-[80px] p-1 rounded-xl flex flex-col items-center relative transition-all border",
                  isToday ? "border-zinc-500 bg-stone-100/60" : "border-stone-200/70 bg-stone-50 hover:bg-white",
                  planned?.status === 'planned' && "border-blue-500/50 bg-blue-500/10",
                  planned?.status === 'completed' && "border-emerald-500/50 bg-emerald-500/10",
                  planned?.status === 'missed' && "border-red-500/50 bg-red-500/10"
                )}
              >
                <span className={cn(
                  "text-sm font-medium mt-1",
                  isToday ? "text-zinc-900" : "text-zinc-500",
                  planned?.status === 'planned' && "text-blue-400",
                  planned?.status === 'completed' && "text-emerald-400",
                  planned?.status === 'missed' && "text-red-400"
                )}>
                  {day}
                </span>
                
                {displayLabel && (
                  <span className="text-[10px] leading-tight text-center mt-1 px-1 text-zinc-700 line-clamp-2">
                    {displayLabel}
                  </span>
                )}

                {planned?.status === 'completed' && (
                  <Check className="w-3 h-3 text-emerald-500 absolute bottom-1.5" />
                )}
                {planned?.status === 'missed' && (
                  <X className="w-3 h-3 text-red-500 absolute bottom-1.5" />
                )}
                {planned?.status === 'planned' && !displayLabel && (
                  <div className="w-1.5 h-1.5 rounded-full bg-blue-500 absolute bottom-2" />
                )}
              </button>
            );
          })}
        </div>
        
        <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div className="flex items-center gap-2 text-xs text-zinc-500">
            <div className="w-3 h-3 rounded bg-stone-50 border border-stone-200/70" />
            Нет планов
          </div>
          <div className="flex items-center gap-2 text-xs text-zinc-500">
            <div className="w-3 h-3 rounded bg-blue-500/10 border border-blue-500/50" />
            Запланировано
          </div>
          <div className="flex items-center gap-2 text-xs text-zinc-500">
            <div className="w-3 h-3 rounded bg-emerald-500/10 border border-emerald-500/50" />
            Выполнено
          </div>
          <div className="flex items-center gap-2 text-xs text-zinc-500">
            <div className="w-3 h-3 rounded bg-red-500/10 border border-red-500/50" />
            Пропущено
          </div>
        </div>
      </div>

      {selectedDate && (
        <CalendarModal 
          date={selectedDate} 
          onClose={() => setSelectedDate(null)} 
        />
      )}
    </div>
  );
}

function AnalyticsTab() {
  const [subTab, setSubTab] = useState<'general' | 'exercise' | 'body'>('general');

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap gap-2 pb-2">
        <button onClick={() => setSubTab('general')} className={cn("flex-1 sm:flex-none px-4 py-2 rounded-xl text-sm font-medium whitespace-nowrap text-center transition-colors", subTab === 'general' ? "bg-stone-100 text-zinc-900" : "bg-white/60 text-zinc-500 hover:text-zinc-800")}>Общая</button>
        <button onClick={() => setSubTab('exercise')} className={cn("flex-1 sm:flex-none px-4 py-2 rounded-xl text-sm font-medium whitespace-nowrap text-center transition-colors", subTab === 'exercise' ? "bg-stone-100 text-zinc-900" : "bg-white/60 text-zinc-500 hover:text-zinc-800")}>По упражнениям</button>
        <button onClick={() => setSubTab('body')} className={cn("flex-1 sm:flex-none px-4 py-2 rounded-xl text-sm font-medium whitespace-nowrap text-center transition-colors", subTab === 'body' ? "bg-stone-100 text-zinc-900" : "bg-white/60 text-zinc-500 hover:text-zinc-800")}>Тело/Замеры</button>
      </div>
      
      {subTab === 'general' && <GeneralAnalytics />}
      {subTab === 'exercise' && <ExerciseAnalytics />}
      {subTab === 'body' && <BodyAnalytics />}
    </div>
  );
}

function GeneralAnalytics() {
  const { exerciseLogs, workoutNodes } = useStore();

  // Calculate exercises logged per day for the last 30 days
  const today = new Date();
  const last30Days = Array.from({ length: 30 }).map((_, i) => {
    const d = new Date(today);
    d.setDate(d.getDate() - (29 - i));
    return d.toISOString().split('T')[0];
  });

  const data = last30Days.map(date => {
    const logsForDay = exerciseLogs.filter(log => log.date === date);
    const count = logsForDay.length;
    
    // Calculate total volume (weight * reps)
    const volume = logsForDay.reduce((sum, log) => {
      if (log.metrics.weight && log.metrics.reps) {
        return sum + (log.metrics.weight * log.metrics.reps);
      }
      return sum;
    }, 0);

    // Calculate total time (if available)
    const time = logsForDay.reduce((sum, log) => {
      if (log.metrics.time) {
        return sum + log.metrics.time;
      }
      return sum;
    }, 0);

    return {
      date: new Date(date).toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' }),
      count,
      volume,
      time: Math.round(time / 60) // convert to minutes
    };
  });

  // Calculate top exercises
  const exerciseCounts = exerciseLogs.reduce((acc, log) => {
    acc[log.exerciseId] = (acc[log.exerciseId] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const topExercises = Object.entries(exerciseCounts)
    .map(([id, count]) => {
      const node = workoutNodes.find(n => n.id === id);
      return {
        name: node?.name || 'Неизвестно',
        count
      };
    })
    .sort((a, b) => b.count - a.count)
    .slice(0, 5);

  const personalRecords = useMemo(() => {
    const records: Record<string, { name: string, maxWeight: number, max1RM: number }> = {};
    
    exerciseLogs.forEach(log => {
      const weight = log.metrics.weight || 0;
      const reps = log.metrics.reps || 0;
      const oneRepMax = weight > 0 && reps > 0 ? Math.round(weight * (1 + reps / 30)) : 0;
      
      if (!records[log.exerciseId] || weight > records[log.exerciseId].maxWeight) {
        const node = workoutNodes.find(n => n.id === log.exerciseId);
        if (node) {
          records[log.exerciseId] = {
            name: node.name,
            maxWeight: weight,
            max1RM: oneRepMax
          };
        }
      } else if (oneRepMax > records[log.exerciseId].max1RM) {
        records[log.exerciseId].max1RM = oneRepMax;
      }
    });

    return Object.values(records)
      .sort((a, b) => b.maxWeight - a.maxWeight)
      .slice(0, 5);
  }, [exerciseLogs, workoutNodes]);

  const totalVolume = data.reduce((sum, d) => sum + d.volume, 0);
  const totalWorkouts = new Set(exerciseLogs.map(l => l.date)).size;

  // Calculate muscle heatmap data for the last 7 days
  const last7DaysDate = new Date();
  last7DaysDate.setDate(last7DaysDate.getDate() - 7);
  const recentLogs = exerciseLogs.filter(log => new Date(log.date) >= last7DaysDate);
  
  const muscleVolume: Record<MuscleGroup, number> = {
    chest: 0, back: 0, legs: 0, shoulders: 0, arms: 0, core: 0, cardio: 0
  };
  
  let maxMuscleVolume = 0;

  recentLogs.forEach(log => {
    const exercise = workoutNodes.find(n => n.id === log.exerciseId);
    if (exercise && exercise.muscleGroup) {
      const weight = log.metrics.weight || 0;
      const reps = log.metrics.reps || 0;
      const volume = weight > 0 && reps > 0 ? weight * reps : (log.metrics.time || 10); // fallback for cardio
      
      muscleVolume[exercise.muscleGroup] += volume;
      if (muscleVolume[exercise.muscleGroup] > maxMuscleVolume) {
        maxMuscleVolume = muscleVolume[exercise.muscleGroup];
      }
    }
  });

  // Normalize to 0-1
  const heatmapData: Record<MuscleGroup, number> = {
    chest: maxMuscleVolume > 0 ? muscleVolume.chest / maxMuscleVolume : 0,
    back: maxMuscleVolume > 0 ? muscleVolume.back / maxMuscleVolume : 0,
    legs: maxMuscleVolume > 0 ? muscleVolume.legs / maxMuscleVolume : 0,
    shoulders: maxMuscleVolume > 0 ? muscleVolume.shoulders / maxMuscleVolume : 0,
    arms: maxMuscleVolume > 0 ? muscleVolume.arms / maxMuscleVolume : 0,
    core: maxMuscleVolume > 0 ? muscleVolume.core / maxMuscleVolume : 0,
    cardio: maxMuscleVolume > 0 ? muscleVolume.cardio / maxMuscleVolume : 0,
  };

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
          <p className="text-[9px] text-zinc-500 uppercase font-bold mb-1">Всего тренировок</p>
          <p className="text-xl font-bold text-zinc-900">{totalWorkouts}</p>
        </div>
        <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
          <p className="text-[9px] text-zinc-500 uppercase font-bold mb-1">Общий объем</p>
          <p className="text-xl font-bold text-zinc-900">{Math.round(totalVolume / 1000)} т</p>
        </div>
      </div>

      <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
        <h2 className="text-base font-semibold text-zinc-900 mb-4 flex items-center gap-2">
          <Award className="w-5 h-5 text-yellow-400" />
          Личные рекорды
        </h2>
        <div className="space-y-4">
          {personalRecords.length > 0 ? personalRecords.map((pr, idx) => (
            <div key={idx} className="flex items-center justify-between">
              <div>
                <p className="text-sm font-bold text-zinc-900">{pr.name}</p>
                <p className="text-[9px] text-zinc-500 uppercase">Прогноз 1RM: {pr.max1RM} кг</p>
              </div>
              <div className="text-right">
                <p className="text-base font-bold text-emerald-400">{pr.maxWeight} кг</p>
              </div>
            </div>
          )) : (
            <p className="text-xs text-zinc-500">Нет рекордов</p>
          )}
        </div>
      </div>

      <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
        <h2 className="text-base font-semibold text-zinc-900 mb-4 flex items-center gap-2">
          <Activity className="w-5 h-5 text-rose-400" />
          Тепловая карта мышц (7 дней)
        </h2>
        <div className="flex justify-center">
          <MuscleHeatmap data={heatmapData} />
        </div>
        <div className="mt-4 flex flex-wrap justify-center gap-2">
          {Object.entries(heatmapData).filter(([_, val]) => val > 0).sort((a, b) => b[1] - a[1]).map(([muscle, val]) => {
            const labels: Record<string, string> = {
              chest: 'Грудь', back: 'Спина', legs: 'Ноги', shoulders: 'Плечи', arms: 'Руки', core: 'Пресс', cardio: 'Кардио'
            };
            return (
              <div key={muscle} className="flex items-center gap-1.5 bg-white px-2 py-1 rounded-lg border border-stone-200">
                <div className="w-2 h-2 rounded-full" style={{ 
                  backgroundColor: val > 0.8 ? '#34d399' : val > 0.5 ? '#10b981' : val > 0.2 ? '#059669' : '#064e3b' 
                }} />
                <span className="text-xs text-zinc-500">{labels[muscle]}</span>
              </div>
            );
          })}
        </div>
      </div>

      <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
        <h2 className="text-base font-semibold text-zinc-900 mb-4 flex items-center gap-2">
          <Activity className="w-5 h-5 text-emerald-400" />
          Активность (подходы)
        </h2>
        <div className="h-[200px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id="colorCount" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10b981" stopOpacity={0.3}/>
                  <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
              <XAxis dataKey="date" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} minTickGap={20} />
              <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} allowDecimals={false} />
              <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#10b981' }} />
              <Area type="monotone" dataKey="count" name="Подходов" stroke="#10b981" strokeWidth={2} fillOpacity={1} fill="url(#colorCount)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
        <h2 className="text-base font-semibold text-zinc-900 mb-4 flex items-center gap-2">
          <Dumbbell className="w-5 h-5 text-blue-400" />
          Объем (Тоннаж)
        </h2>
        <div className="h-[200px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id="colorVolume" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                  <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
              <XAxis dataKey="date" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} minTickGap={20} />
              <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
              <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#3b82f6' }} />
              <Area type="monotone" dataKey="volume" name="Кг" stroke="#3b82f6" strokeWidth={2} fillOpacity={1} fill="url(#colorVolume)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
        <h2 className="text-base font-semibold text-zinc-900 mb-4 flex items-center gap-2">
          <Timer className="w-5 h-5 text-orange-400" />
          Время подходов (мин)
        </h2>
        <div className="h-[200px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id="colorTime" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#f97316" stopOpacity={0.3}/>
                  <stop offset="95%" stopColor="#f97316" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
              <XAxis dataKey="date" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} minTickGap={20} />
              <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
              <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#f97316' }} />
              <Area type="monotone" dataKey="time" name="Мин" stroke="#f97316" strokeWidth={2} fillOpacity={1} fill="url(#colorTime)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {topExercises.length > 0 && (
        <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
          <h2 className="text-base font-semibold text-zinc-900 mb-4 flex items-center gap-2">
            <LineChart className="w-5 h-5 text-purple-400" />
            Частые упражнения
          </h2>
          <div className="space-y-3">
            {topExercises.map((ex, i) => (
              <div key={i} className="flex items-center justify-between">
                <span className="text-sm text-zinc-700 truncate pr-4">{ex.name}</span>
                <div className="flex items-center gap-3">
                  <div className="w-32 h-2 bg-stone-100 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-purple-500 rounded-full" 
                      style={{ width: `${(ex.count / topExercises[0].count) * 100}%` }}
                    />
                  </div>
                  <span className="text-xs text-zinc-500 w-8 text-right">{ex.count}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function ExerciseAnalytics() {
  const { exerciseLogs, workoutNodes } = useStore();
  const exercises = workoutNodes.filter(n => n.type === 'exercise');
  const [selectedId, setSelectedId] = useState<string>(exercises[0]?.id || '');

  if (exercises.length === 0) {
    return <p className="text-zinc-500 text-center py-8">Нет упражнений для анализа.</p>;
  }

  const selectedExercise = exercises.find(e => e.id === selectedId);
  const logs = exerciseLogs.filter(l => l.exerciseId === selectedId).sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

  // Group by date to get max weight, total volume, total reps per day, max 1RM, total distance, total time
  const dailyStats = logs.reduce((acc, log) => {
    if (!acc[log.date]) {
      acc[log.date] = { date: log.date, maxWeight: 0, volume: 0, reps: 0, maxOneRepMax: 0, distance: 0, time: 0 };
    }
    const weight = log.metrics.weight || 0;
    const reps = log.metrics.reps || 0;
    const distance = log.metrics.distance || 0;
    const time = log.metrics.time || 0;
    
    if (weight > acc[log.date].maxWeight) {
      acc[log.date].maxWeight = weight;
    }
    
    // Epley formula for 1RM: w * (1 + r/30)
    const oneRepMax = weight > 0 && reps > 0 ? Math.round(weight * (1 + reps / 30)) : 0;
    if (oneRepMax > acc[log.date].maxOneRepMax) {
      acc[log.date].maxOneRepMax = oneRepMax;
    }

    acc[log.date].volume += weight * reps;
    acc[log.date].reps += reps;
    acc[log.date].distance += distance;
    acc[log.date].time += time;
    
    return acc;
  }, {} as Record<string, { date: string, maxWeight: number, volume: number, reps: number, maxOneRepMax: number, distance: number, time: number }>);

  const data = Object.values(dailyStats).map(d => ({
    ...d,
    dateFormatted: new Date(d.date).toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' })
  }));

  const hasWeight = data.some(d => d.maxWeight > 0);
  const hasDistance = data.some(d => d.distance > 0);
  const hasTime = data.some(d => d.time > 0);

  return (
    <div className="space-y-6">
      <select
        value={selectedId}
        onChange={e => setSelectedId(e.target.value)}
        className="w-full bg-stone-50 border border-stone-200 rounded-xl px-4 py-3 text-zinc-900 focus:outline-none focus:border-emerald-500/50"
      >
        {exercises.map(ex => (
          <option key={ex.id} value={ex.id}>{ex.name}</option>
        ))}
      </select>

      {hasWeight && (
        <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
          <h3 className="text-sm font-semibold text-zinc-500 mb-4">Прогресс веса</h3>
          <div className="h-[200px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <RechartsLineChart data={data}>
                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} />
                <Line type="monotone" dataKey="maxWeight" name="Вес" stroke="#10b981" strokeWidth={2} dot={{ r: 4 }} />
                <Line type="monotone" dataKey="maxOneRepMax" name="1RM" stroke="#f59e0b" strokeWidth={2} dot={{ r: 4 }} />
              </RechartsLineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {data.length === 0 ? (
        <p className="text-zinc-500 text-center py-8">Нет записей для этого упражнения.</p>
      ) : (
        <>
          {hasWeight && (
            <>
              <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
                <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
                  <Dumbbell className="w-5 h-5 text-blue-400" />
                  Максимальный вес (кг)
                </h2>
                <div className="h-[200px] w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                      <defs>
                        <linearGradient id="colorMaxWeight" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                          <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                      <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                      <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                      <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#3b82f6' }} />
                      <Area type="monotone" dataKey="maxWeight" name="Кг" stroke="#3b82f6" strokeWidth={2} fillOpacity={1} fill="url(#colorMaxWeight)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>

              <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
                <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
                  <Activity className="w-5 h-5 text-rose-400" />
                  Прогноз 1RM (кг)
                </h2>
                <div className="h-[200px] w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                      <defs>
                        <linearGradient id="colorOneRepMax" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#fb7185" stopOpacity={0.3}/>
                          <stop offset="95%" stopColor="#fb7185" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                      <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                      <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                      <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#fb7185' }} />
                      <Area type="monotone" dataKey="maxOneRepMax" name="Кг" stroke="#fb7185" strokeWidth={2} fillOpacity={1} fill="url(#colorOneRepMax)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>

              <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
                <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
                  <Activity className="w-5 h-5 text-emerald-400" />
                  Объем (Тоннаж)
                </h2>
                <div className="h-[200px] w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                      <defs>
                        <linearGradient id="colorVol" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#10b981" stopOpacity={0.3}/>
                          <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                      <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                      <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                      <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#10b981' }} />
                      <Area type="monotone" dataKey="volume" name="Кг" stroke="#10b981" strokeWidth={2} fillOpacity={1} fill="url(#colorVol)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>

              <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
                <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
                  <LineChart className="w-5 h-5 text-purple-400" />
                  Повторения
                </h2>
                <div className="h-[200px] w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                      <defs>
                        <linearGradient id="colorReps" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#a855f7" stopOpacity={0.3}/>
                          <stop offset="95%" stopColor="#a855f7" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                      <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                      <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                      <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#a855f7' }} />
                      <Area type="monotone" dataKey="reps" name="Повторений" stroke="#a855f7" strokeWidth={2} fillOpacity={1} fill="url(#colorReps)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </>
          )}

          {hasDistance && (
            <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
              <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
                <Activity className="w-5 h-5 text-cyan-400" />
                Дистанция (км)
              </h2>
              <div className="h-[200px] w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                    <defs>
                      <linearGradient id="colorDistance" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#22d3ee" stopOpacity={0.3}/>
                        <stop offset="95%" stopColor="#22d3ee" stopOpacity={0}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                    <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                    <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                    <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#22d3ee' }} />
                    <Area type="monotone" dataKey="distance" name="Км" stroke="#22d3ee" strokeWidth={2} fillOpacity={1} fill="url(#colorDistance)" />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}

          {hasTime && (
            <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
              <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
                <Timer className="w-5 h-5 text-orange-400" />
                Время (мин)
              </h2>
              <div className="h-[200px] w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                    <defs>
                      <linearGradient id="colorTimeEx" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#f97316" stopOpacity={0.3}/>
                        <stop offset="95%" stopColor="#f97316" stopOpacity={0}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                    <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                    <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                    <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#f97316' }} />
                    <Area type="monotone" dataKey="time" name="Мин" stroke="#f97316" strokeWidth={2} fillOpacity={1} fill="url(#colorTimeEx)" />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function DailyActivityTracker() {
  const { dailyActivities = [], logDailyActivity, deleteDailyActivity } = useStore();
  const [isAdding, setIsAdding] = useState(false);
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [steps, setSteps] = useState('');
  const [calories, setCalories] = useState('');

  const handleLog = (e: React.FormEvent) => {
    e.preventDefault();
    if (!steps && !calories) return;
    logDailyActivity({
      date,
      steps: steps ? parseInt(steps, 10) : 0,
      calories: calories ? parseInt(calories, 10) : 0
    });
    setIsAdding(false);
    setSteps('');
    setCalories('');
  };

  const sorted = [...dailyActivities].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  const today = sorted.find(a => a.date === new Date().toISOString().split('T')[0]);

  return (
    <div className="space-y-4">
      <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-zinc-900 flex items-center gap-2">
            <Flame className="w-5 h-5 text-orange-400" />
            Активность
          </h3>
          <button
            onClick={() => setIsAdding(!isAdding)}
            className="p-1.5 bg-stone-100 text-zinc-500 rounded-lg hover:text-zinc-900 transition-colors"
          >
            {isAdding ? <X className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
          </button>
        </div>

        {isAdding ? (
          <form onSubmit={handleLog} className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Дата</label>
                <input
                  type="date"
                  value={date}
                  onChange={e => setDate(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Шаги</label>
                <input
                  type="number"
                  value={steps}
                  onChange={e => setSteps(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0"
                />
              </div>
              <div className="space-y-1 col-span-2">
                <label className="text-xs text-zinc-500">Калории (ккал)</label>
                <input
                  type="number"
                  value={calories}
                  onChange={e => setCalories(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0"
                />
              </div>
            </div>
            <button type="submit" className="w-full py-2 bg-white text-black rounded-lg font-medium text-sm">
              Сохранить активность
            </button>
          </form>
        ) : (
          <div className="grid grid-cols-2 gap-4">
            <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70 text-center">
              <div className="text-xs text-zinc-500 mb-1">Шаги сегодня</div>
              <div className="text-xl font-bold text-zinc-900">{today?.steps || 0}</div>
              <div className="text-[10px] text-zinc-600">цель: 10,000</div>
            </div>
            <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70 text-center">
              <div className="text-xs text-zinc-500 mb-1">Калории сегодня</div>
              <div className="text-xl font-bold text-zinc-900">{today?.calories || 0}</div>
              <div className="text-[10px] text-zinc-600">цель: 2,500</div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function BodyAnalytics() {
  const { bodyMeasurements } = useStore();
  
  const sorted = [...(bodyMeasurements || [])].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
  
  const data = sorted.map(m => {
    const { height, neck, gender, weight } = m;
    const { waist, hips } = m.measurements || {};
    let bodyFat = null;
    if (height && neck && gender && waist) {
      if (gender === 'male') {
        bodyFat = 495 / (1.0324 - 0.19077 * Math.log10(waist - neck) + 0.15456 * Math.log10(height)) - 450;
      } else if (hips) {
        bodyFat = 495 / (1.29579 - 0.35004 * Math.log10(waist + hips - neck) + 0.22100 * Math.log10(height)) - 450;
      }
    }
    
    const bmi = height ? (weight / Math.pow(height / 100, 2)) : null;

    return {
      dateFormatted: new Date(m.date).toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' }),
      weight: m.weight,
      bodyFat: bodyFat ? parseFloat(bodyFat.toFixed(1)) : null,
      bmi: bmi ? parseFloat(bmi.toFixed(1)) : null,
    };
  });

  const { dailyActivities = [] } = useStore();
  const activityData = [...dailyActivities]
    .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
    .map(a => ({
      dateFormatted: new Date(a.date).toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' }),
      steps: a.steps,
      calories: a.calories,
    }));

  if (data.length === 0 && activityData.length === 0) {
    return <p className="text-zinc-500 text-center py-8">Нет записей для анализа.</p>;
  }

  return (
    <div className="space-y-6">
      {activityData.length > 0 && (
        <>
          <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
            <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
              <Flame className="w-5 h-5 text-orange-400" />
              Шаги
            </h2>
            <div className="h-[200px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={activityData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorSteps" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#f97316" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#f97316" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                  <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                  <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                  <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#f97316' }} />
                  <Area type="monotone" dataKey="steps" name="Шаги" stroke="#f97316" strokeWidth={2} fillOpacity={1} fill="url(#colorSteps)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
            <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
              <Zap className="w-5 h-5 text-yellow-400" />
              Калории
            </h2>
            <div className="h-[200px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={activityData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorCalories" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#eab308" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#eab308" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                  <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                  <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                  <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#eab308' }} />
                  <Area type="monotone" dataKey="calories" name="Ккал" stroke="#eab308" strokeWidth={2} fillOpacity={1} fill="url(#colorCalories)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        </>
      )}

      {data.length > 0 && (
        <>
          <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
            <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
              <User className="w-5 h-5 text-blue-400" />
              Динамика веса (кг)
            </h2>
            <div className="h-[200px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorWeight" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                  <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                  <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} domain={['dataMin - 2', 'dataMax + 2']} />
                  <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#3b82f6' }} />
                  <Area type="monotone" dataKey="weight" name="Вес" stroke="#3b82f6" strokeWidth={2} fillOpacity={1} fill="url(#colorWeight)" connectNulls />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
            <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
              <TrendingUp className="w-5 h-5 text-emerald-400" />
              Процент жира (%)
            </h2>
            <div className="h-[200px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorFat" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10b981" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                  <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                  <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                  <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} itemStyle={{ color: '#10b981' }} />
                  <Area type="monotone" dataKey="bodyFat" name="% Жира" stroke="#10b981" strokeWidth={2} fillOpacity={1} fill="url(#colorFat)" connectNulls />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
            <h2 className="text-lg font-semibold text-zinc-900 mb-4 flex items-center gap-2">
              <Activity className="w-5 h-5 text-purple-400" />
              Объемы (см)
            </h2>
            <div className="h-[250px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <RechartsLineChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                  <XAxis dataKey="dateFormatted" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                  <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                  <Tooltip contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }} />
                  <Line type="monotone" dataKey="chest" name="Грудь" stroke="#8b5cf6" strokeWidth={2} dot={{ r: 3 }} connectNulls />
                  <Line type="monotone" dataKey="waist" name="Талия" stroke="#ec4899" strokeWidth={2} dot={{ r: 3 }} connectNulls />
                  <Line type="monotone" dataKey="hips" name="Бедра" stroke="#10b981" strokeWidth={2} dot={{ r: 3 }} connectNulls />
                  <Line type="monotone" dataKey="biceps" name="Бицепс" stroke="#f59e0b" strokeWidth={2} dot={{ r: 3 }} connectNulls />
                  <Line type="monotone" dataKey="thighs" name="Бедро" stroke="#3b82f6" strokeWidth={2} dot={{ r: 3 }} connectNulls />
                </RechartsLineChart>
              </ResponsiveContainer>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function ProfileTab() {
  const { bodyMeasurements, addBodyMeasurement, deleteBodyMeasurement } = useStore();
  const [isAdding, setIsAdding] = useState(false);
  
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [weight, setWeight] = useState('');
  const [height, setHeight] = useState('');
  const [neck, setNeck] = useState('');
  const [gender, setGender] = useState<'male' | 'female'>('male');
  const [chest, setChest] = useState('');
  const [waist, setWaist] = useState('');
  const [hips, setHips] = useState('');
  const [biceps, setBiceps] = useState('');
  const [thighs, setThighs] = useState('');
  const [calves, setCalves] = useState('');
  const [photos, setPhotos] = useState<string[]>([]);
  const fileInputRef = React.useRef<HTMLInputElement>(null);

  const calculateBodyFat = (m: BodyMeasurement) => {
    if (!m.weight || !m.height || !m.measurements?.waist || !m.neck || !m.gender) return null;
    
    const { height, neck, gender } = m;
    const { waist, hips } = m.measurements;

    if (gender === 'male') {
      // US Navy formula for men
      return 495 / (1.0324 - 0.19077 * Math.log10(waist - neck) + 0.15456 * Math.log10(height)) - 450;
    } else {
      // US Navy formula for women
      if (!hips) return null;
      return 495 / (1.29579 - 0.35004 * Math.log10(waist + hips - neck) + 0.22100 * Math.log10(height)) - 450;
    }
  };

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files) return;

    Array.from(files).forEach((file: File) => {
      const reader = new FileReader();
      reader.onloadend = () => {
        setPhotos(prev => [...prev, reader.result as string]);
      };
      reader.readAsDataURL(file);
    });
  };

  const removePhoto = (index: number) => {
    setPhotos(prev => prev.filter((_, i) => i !== index));
  };

  const handleAdd = (e: React.FormEvent) => {
    e.preventDefault();
    
    const measurements: Record<string, number> = {};
    if (chest) measurements.chest = parseFloat(chest);
    if (waist) measurements.waist = parseFloat(waist);
    if (hips) measurements.hips = parseFloat(hips);
    if (biceps) measurements.biceps = parseFloat(biceps);
    if (thighs) measurements.thighs = parseFloat(thighs);
    if (calves) measurements.calves = parseFloat(calves);

    addBodyMeasurement({
      date,
      weight: weight ? parseFloat(weight) : undefined,
      height: height ? parseFloat(height) : undefined,
      neck: neck ? parseFloat(neck) : undefined,
      gender,
      measurements: Object.keys(measurements).length > 0 ? measurements : undefined,
      photos: photos.length > 0 ? photos : undefined
    });

    setIsAdding(false);
    setWeight('');
    setHeight('');
    setNeck('');
    setChest('');
    setWaist('');
    setHips('');
    setBiceps('');
    setThighs('');
    setCalves('');
    setPhotos([]);
  };

  const sortedMeasurements = [...bodyMeasurements].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

  return (
    <div className="space-y-6">
      <DailyActivityTracker />

      <div className="flex justify-between items-center">
        <h2 className="text-xl font-semibold text-zinc-900">Измерения тела</h2>
        <button
          onClick={() => setIsAdding(!isAdding)}
          className="p-2 bg-stone-100 text-zinc-900 rounded-lg hover:bg-stone-200 transition-colors"
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
            onSubmit={handleAdd}
            className="bg-white/60 p-4 rounded-2xl border border-stone-200/70 space-y-4 overflow-hidden"
          >
            <div className="space-y-1">
              <label className="text-xs text-zinc-500">Дата</label>
              <input
                type="date"
                value={date}
                onChange={e => setDate(e.target.value)}
                className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                required
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Пол</label>
                <select
                  value={gender}
                  onChange={e => setGender(e.target.value as 'male' | 'female')}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                >
                  <option value="male">Мужской</option>
                  <option value="female">Женский</option>
                </select>
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Вес (кг)</label>
                <input
                  type="number"
                  step="0.1"
                  value={weight}
                  onChange={e => setWeight(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0.0"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Рост (см)</label>
                <input
                  type="number"
                  step="0.1"
                  value={height}
                  onChange={e => setHeight(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0.0"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Шея (см)</label>
                <input
                  type="number"
                  step="0.1"
                  value={neck}
                  onChange={e => setNeck(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0.0"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Грудь (см)</label>
                <input
                  type="number"
                  step="0.1"
                  value={chest}
                  onChange={e => setChest(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0.0"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Талия (см)</label>
                <input
                  type="number"
                  step="0.1"
                  value={waist}
                  onChange={e => setWaist(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0.0"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Бедра (см)</label>
                <input
                  type="number"
                  step="0.1"
                  value={hips}
                  onChange={e => setHips(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0.0"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Бицепс (см)</label>
                <input
                  type="number"
                  step="0.1"
                  value={biceps}
                  onChange={e => setBiceps(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0.0"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Бедро (см)</label>
                <input
                  type="number"
                  step="0.1"
                  value={thighs}
                  onChange={e => setThighs(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0.0"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Икры (см)</label>
                <input
                  type="number"
                  step="0.1"
                  value={calves}
                  onChange={e => setCalves(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 text-sm"
                  placeholder="0.0"
                />
              </div>
            </div>

            <div className="space-y-2 pt-2 border-t border-stone-200/70">
              <label className="text-xs text-zinc-500">Фотографии прогресса</label>
              
              {photos.length > 0 && (
                <div className="grid grid-cols-3 gap-2 mb-2">
                  {photos.map((photo, i) => (
                    <div key={i} className="relative aspect-square rounded-lg overflow-hidden border border-stone-200 group">
                      <img src={photo} alt={`Progress ${i}`} className="w-full h-full object-cover" />
                      <button
                        type="button"
                        onClick={() => removePhoto(i)}
                        className="absolute top-1 right-1 p-1 bg-zinc-900/30 text-zinc-900 rounded-full opacity-0 group-hover:opacity-100 transition-opacity hover:bg-red-500/80"
                      >
                        <X className="w-3 h-3" />
                      </button>
                    </div>
                  ))}
                </div>
              )}

              <input
                type="file"
                ref={fileInputRef}
                onChange={handlePhotoUpload}
                accept="image/*"
                multiple
                className="hidden"
              />
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                className="w-full py-2 bg-stone-50 border border-stone-200 text-zinc-700 rounded-lg text-sm flex items-center justify-center gap-2 hover:bg-white transition-colors"
              >
                <Camera className="w-4 h-4" />
                Добавить фото
              </button>
            </div>

            <button type="submit" className="w-full py-2 bg-white text-black rounded-lg font-medium mt-4">
              Сохранить
            </button>
          </motion.form>
        )}
      </AnimatePresence>

      <div className="space-y-3">
        {sortedMeasurements.length === 0 ? (
          <p className="text-zinc-500 text-center py-8">Нет записей. Добавьте первые измерения!</p>
        ) : (
          sortedMeasurements.map(m => (
            <div key={m.id} className="bg-white/60 p-4 rounded-2xl border border-stone-200/70 space-y-3">
              <div className="flex justify-between items-center border-b border-stone-200/70 pb-2">
                <div className="flex items-center gap-2 text-zinc-700 font-medium">
                  <Calendar className="w-4 h-4 text-zinc-500" />
                  {new Date(m.date).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' })}
                </div>
                <button onClick={() => deleteBodyMeasurement(m.id)} className="p-1.5 text-red-400 hover:text-red-300 hover:bg-red-400/10 rounded-lg transition-colors">
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
              
              <div className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                {m.weight && (
                  <div className="flex justify-between">
                    <span className="text-zinc-500">Вес:</span>
                    <span className="text-zinc-900 font-medium">{m.weight} кг</span>
                  </div>
                )}
                {m.height && (
                  <div className="flex justify-between">
                    <span className="text-zinc-500">Рост:</span>
                    <span className="text-zinc-900 font-medium">{m.height} см</span>
                  </div>
                )}
                {m.neck && (
                  <div className="flex justify-between">
                    <span className="text-zinc-500">Шея:</span>
                    <span className="text-zinc-900 font-medium">{m.neck} см</span>
                  </div>
                )}
                {calculateBodyFat(m) !== null && (
                  <div className="flex justify-between col-span-2 py-1 px-2 bg-indigo-500/10 rounded border border-indigo-500/20">
                    <span className="text-indigo-400 font-medium">% Жира (ВМС США):</span>
                    <span className="text-indigo-300 font-bold">{calculateBodyFat(m)!.toFixed(1)}%</span>
                  </div>
                )}
                {m.measurements?.chest && (
                  <div className="flex justify-between">
                    <span className="text-zinc-500">Грудь:</span>
                    <span className="text-zinc-900 font-medium">{m.measurements.chest} см</span>
                  </div>
                )}
                {m.measurements?.waist && (
                  <div className="flex justify-between">
                    <span className="text-zinc-500">Талия:</span>
                    <span className="text-zinc-900 font-medium">{m.measurements.waist} см</span>
                  </div>
                )}
                {m.measurements?.hips && (
                  <div className="flex justify-between">
                    <span className="text-zinc-500">Бедра:</span>
                    <span className="text-zinc-900 font-medium">{m.measurements.hips} см</span>
                  </div>
                )}
                {m.measurements?.biceps && (
                  <div className="flex justify-between">
                    <span className="text-zinc-500">Бицепс:</span>
                    <span className="text-zinc-900 font-medium">{m.measurements.biceps} см</span>
                  </div>
                )}
                {m.measurements?.thighs && (
                  <div className="flex justify-between">
                    <span className="text-zinc-500">Бедро:</span>
                    <span className="text-zinc-900 font-medium">{m.measurements.thighs} см</span>
                  </div>
                )}
                {m.measurements?.calves && (
                  <div className="flex justify-between">
                    <span className="text-zinc-500">Икры:</span>
                    <span className="text-zinc-900 font-medium">{m.measurements.calves} см</span>
                  </div>
                )}
              </div>

              {m.photos && m.photos.length > 0 && (
                <div className="pt-3 mt-3 border-t border-stone-200/70">
                  <div className="flex items-center gap-2 text-xs text-zinc-500 mb-2">
                    <ImageIcon className="w-3.5 h-3.5" />
                    Фотографии ({m.photos.length})
                  </div>
                  <div className="flex gap-2 overflow-x-auto pb-2 snap-x">
                    {m.photos.map((photo, i) => (
                      <img 
                        key={i} 
                        src={photo} 
                        alt={`Progress ${i}`} 
                        className="h-24 w-24 object-cover rounded-lg border border-stone-200 flex-shrink-0 snap-start"
                      />
                    ))}
                  </div>
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  );
}
