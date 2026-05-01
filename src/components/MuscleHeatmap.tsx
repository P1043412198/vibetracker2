import React, { useState } from 'react';
import Model, { IExerciseData, IMuscleStats } from 'react-body-highlighter';
import { MuscleGroup } from '../types';
import { cn } from '../lib/utils';
import { RotateCcw, X, Plus, FolderPlus } from 'lucide-react';
import { useStore } from '../store/useStore';
import { motion, AnimatePresence } from 'motion/react';

const MUSCLE_INFO: Record<string, { name: string; description: string; action: string }> = {
  'trapezius': { name: 'Трапециевидная мышца', description: 'Плоская широкая мышца, занимающая поверхностное положение в задней области шеи и в верхнем отделе спины.', action: 'Поднимает, опускает и сводит лопатки, разгибает голову и шею.' },
  'upper-back': { name: 'Верхняя часть спины (Ромбовидные)', description: 'Группа мышц, расположенных под трапецией.', action: 'Сведение лопаток, поддержание осанки.' },
  'lower-back': { name: 'Поясница (Разгибатели спины)', description: 'Глубокие мышцы спины, проходящие вдоль позвоночника.', action: 'Разгибание позвоночника, поддержание вертикального положения тела.' },
  'chest': { name: 'Грудные мышцы', description: 'Крупные веерообразные мышцы, расположенные на передней поверхности грудной клетки.', action: 'Приведение, сгибание и внутренняя ротация плеча (руки).' },
  'biceps': { name: 'Бицепс (Двуглавая мышца плеча)', description: 'Крупная мышца на передней поверхности плеча.', action: 'Сгибание руки в локтевом суставе, супинация предплечья.' },
  'triceps': { name: 'Трицепс (Трехглавая мышца плеча)', description: 'Мышца, занимающая всю заднюю поверхность плеча.', action: 'Разгибание руки в локтевом суставе.' },
  'forearm': { name: 'Предплечье', description: 'Группа множества мелких мышц, отвечающих за движения кисти и пальцев.', action: 'Сгибание, разгибание кисти, хват.' },
  'back-deltoids': { name: 'Задняя дельта', description: 'Задний пучок дельтовидной мышцы плеча.', action: 'Разгибание и наружная ротация плеча, отведение руки назад.' },
  'front-deltoids': { name: 'Передняя и средняя дельта', description: 'Передний и средний пучки дельтовидной мышцы.', action: 'Сгибание и отведение руки в сторону и вверх.' },
  'abs': { name: 'Пресс (Прямая мышца живота)', description: 'Парная плоская длинная мышца передней брюшной стенки.', action: 'Сгибание позвоночника (скручивания), поддержание внутрибрюшного давления.' },
  'obliques': { name: 'Косые мышцы живота', description: 'Мышцы, расположенные по бокам брюшной полости.', action: 'Вращение и наклоны туловища в стороны.' },
  'adductor': { name: 'Приводящие мышцы бедра', description: 'Группа мышц на внутренней поверхности бедра.', action: 'Приведение бедра (сведение ног вместе).' },
  'abductors': { name: 'Отводящие мышцы (Ягодичные средние/малые)', description: 'Мышцы на наружной поверхности таза и бедра.', action: 'Отведение ноги в сторону.' },
  'hamstring': { name: 'Бицепс бедра (Задняя поверхность)', description: 'Группа мышц на задней поверхности бедра.', action: 'Сгибание ноги в коленном суставе, разгибание бедра.' },
  'quadriceps': { name: 'Квадрицепс (Передняя поверхность бедра)', description: 'Крупная четырехглавая мышца на передней поверхности бедра.', action: 'Разгибание ноги в коленном суставе.' },
  'calves': { name: 'Икроножные мышцы', description: 'Двуглавая мышца на задней поверхности голени.', action: 'Сгибание стопы (подъем на носки), участие в сгибании колена.' },
  'gluteal': { name: 'Ягодичные мышцы', description: 'Крупные мышцы, образующие ягодицы.', action: 'Разгибание и наружная ротация бедра, выпрямление туловища.' },
  'head': { name: 'Мышцы головы', description: 'Мимические и жевательные мышцы.', action: 'Движения челюсти, мимика.' },
  'neck': { name: 'Мышцы шеи', description: 'Группа мышц, удерживающих и двигающих голову.', action: 'Наклоны, повороты и вращение головы.' },
  'knees': { name: 'Коленные суставы (Связки)', description: 'Область коленного сустава.', action: 'Стабилизация колена.' },
  'left-soleus': { name: 'Камбаловидная мышца (левая)', description: 'Глубокая мышца голени.', action: 'Сгибание стопы.' },
  'right-soleus': { name: 'Камбаловидная мышца (правая)', description: 'Глубокая мышца голени.', action: 'Сгибание стопы.' },
};

interface MuscleHeatmapProps {
  data: Record<MuscleGroup, number>; // value from 0 to 1 (intensity)
}

export function MuscleHeatmap({ data }: MuscleHeatmapProps) {
  const [isFront, setIsFront] = useState(true);
  const [selectedMuscle, setSelectedMuscle] = useState<string | null>(null);
  const { addWorkoutNode, workoutNodes } = useStore();

  // Map 0-1 intensity to 1-5 frequency
  const getFrequency = (intensity: number) => {
    if (intensity === 0) return 0;
    return Math.max(1, Math.ceil(intensity * 5));
  };

  const exerciseData: IExerciseData[] = [
    { name: 'Chest', muscles: ['chest'] as any, frequency: getFrequency(data.chest || 0) },
    { name: 'Back', muscles: ['upper-back', 'lower-back', 'trapezius'] as any, frequency: getFrequency(data.back || 0) },
    { name: 'Legs', muscles: ['quadriceps', 'hamstring', 'calves', 'gluteal', 'adductor', 'abductors'] as any, frequency: getFrequency(data.legs || 0) },
    { name: 'Shoulders', muscles: ['front-deltoids', 'back-deltoids'] as any, frequency: getFrequency(data.shoulders || 0) },
    { name: 'Arms', muscles: ['biceps', 'triceps', 'forearm'] as any, frequency: getFrequency(data.arms || 0) },
    { name: 'Core', muscles: ['abs', 'obliques'] as any, frequency: getFrequency(data.core || 0) },
  ].filter(ex => ex.frequency > 0);

  const colors = ['#064e3b', '#059669', '#10b981', '#34d399', '#6ee7b7'];

  const handleMuscleClick = (stats: IMuscleStats) => {
    setSelectedMuscle(stats.muscle);
  };

  const handleCreateWorkout = () => {
    if (!selectedMuscle) return;
    const info = MUSCLE_INFO[selectedMuscle];
    const name = info ? `Тренировка: ${info.name}` : `Тренировка: ${selectedMuscle}`;
    addWorkoutNode({
      parentId: null,
      name,
      type: 'folder'
    });
    setSelectedMuscle(null);
    alert(`Создана новая категория тренировок: "${name}". Перейдите во вкладку "Упражнения", чтобы добавить в нее упражнения.`);
  };

  const handleCreateExercise = () => {
    if (!selectedMuscle) return;
    const info = MUSCLE_INFO[selectedMuscle];
    const name = info ? `Упражнение на ${info.name.toLowerCase()}` : `Упражнение: ${selectedMuscle}`;
    
    // Create a root folder for unassigned exercises if it doesn't exist
    let rootId = workoutNodes.find(n => n.name === 'Мои упражнения' && n.type === 'folder')?.id;
    if (!rootId) {
      addWorkoutNode({
        parentId: null,
        name: 'Мои упражнения',
        type: 'folder'
      });
      // We need to find the newly created folder, but since addWorkoutNode is synchronous in zustand,
      // we can just get it from the store after a slight delay or rely on the user to move it.
      // For simplicity, we'll just add it to the root if we can't find it immediately.
    }
    
    // Re-fetch to get the ID if we just created it (zustand state update might not be immediate in this closure)
    const currentNodes = useStore.getState().workoutNodes;
    rootId = currentNodes.find(n => n.name === 'Мои упражнения' && n.type === 'folder')?.id || null;

    addWorkoutNode({
      parentId: rootId,
      name,
      type: 'exercise',
      metrics: ['weight', 'reps']
    });
    setSelectedMuscle(null);
    alert(`Создано новое упражнение: "${name}". Ищите его во вкладке "Упражнения".`);
  };

  const muscleInfo = selectedMuscle ? MUSCLE_INFO[selectedMuscle] : null;

  return (
    <div className="relative w-full max-w-[250px] mx-auto flex flex-col items-center">
      <button 
        onClick={() => setIsFront(!isFront)}
        className="absolute top-0 right-0 p-2 bg-zinc-800 text-zinc-400 hover:text-white rounded-full transition-colors z-10"
        title="Повернуть"
      >
        <RotateCcw className="w-4 h-4" />
      </button>
      <div className="w-full aspect-[1/2] flex justify-center items-center cursor-pointer">
        <Model
          data={exerciseData}
          style={{ width: '100%', height: '100%' }}
          highlightedColors={colors}
          bodyColor="#27272a"
          type={isFront ? 'anterior' : 'posterior'}
          onClick={handleMuscleClick as any}
        />
      </div>

      <AnimatePresence>
        {selectedMuscle && (
          <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/80">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="bg-zinc-900 rounded-2xl p-6 w-full max-w-md border border-zinc-800 shadow-xl"
            >
              <div className="flex justify-between items-start mb-4">
                <h3 className="text-xl font-bold text-white">
                  {muscleInfo?.name || selectedMuscle}
                </h3>
                <button
                  onClick={() => setSelectedMuscle(null)}
                  className="p-2 text-zinc-400 hover:text-white rounded-lg hover:bg-zinc-800 transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {muscleInfo ? (
                <div className="space-y-4 mb-6">
                  <div>
                    <h4 className="text-sm font-medium text-zinc-400 mb-1">Описание</h4>
                    <p className="text-zinc-200 text-sm leading-relaxed">{muscleInfo.description}</p>
                  </div>
                  <div>
                    <h4 className="text-sm font-medium text-zinc-400 mb-1">Функции</h4>
                    <p className="text-zinc-200 text-sm leading-relaxed">{muscleInfo.action}</p>
                  </div>
                </div>
              ) : (
                <p className="text-zinc-400 text-sm mb-6">Информация о данной мышце отсутствует.</p>
              )}

              <div className="flex flex-col gap-3">
                <button
                  onClick={handleCreateWorkout}
                  className="w-full flex items-center justify-center gap-2 bg-indigo-500 hover:bg-indigo-600 text-white py-3 rounded-xl font-medium transition-colors"
                >
                  <FolderPlus className="w-5 h-5" />
                  Создать программу тренировок
                </button>
                <button
                  onClick={handleCreateExercise}
                  className="w-full flex items-center justify-center gap-2 bg-zinc-800 hover:bg-zinc-700 text-white py-3 rounded-xl font-medium transition-colors"
                >
                  <Plus className="w-5 h-5" />
                  Добавить упражнение
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
