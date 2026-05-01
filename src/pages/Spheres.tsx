import React, { useState } from 'react';
import { useStore } from '../store/useStore';
import { Plus, Target, Calendar, Trash2, X, ChevronRight, Pin, PinOff, GripVertical } from 'lucide-react';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'motion/react';
import { cn } from '../lib/utils';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  rectSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';

interface SortableSphereProps {
  sphere: any;
  onDelete: (id: string) => void;
  onTogglePin: (id: string, isPinned: boolean) => void;
  onClick: () => void;
}

const SortableSphere = ({ sphere, onDelete, onTogglePin, onClick }: SortableSphereProps) => {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: sphere.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    zIndex: isDragging ? 50 : 'auto',
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={cn(
        "bg-zinc-900 p-5 rounded-2xl shadow-sm border border-zinc-800 flex flex-col cursor-pointer hover:border-zinc-600 transition-colors group relative",
        isDragging && "opacity-50 border-white/20"
      )}
      onClick={onClick}
    >
      <div className="flex justify-between items-start mb-3">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-zinc-800 rounded-xl text-white">
            <Target className="w-5 h-5" />
          </div>
          <div
            {...attributes}
            {...listeners}
            className="p-1.5 text-zinc-600 hover:text-zinc-400 cursor-grab active:cursor-grabbing transition-colors"
            onClick={(e) => e.stopPropagation()}
          >
            <GripVertical className="w-4 h-4" />
          </div>
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={(e) => {
              e.stopPropagation();
              onTogglePin(sphere.id, !!sphere.isPinned);
            }}
            className={cn(
              "transition-colors p-1.5 rounded-lg",
              sphere.isPinned ? "text-emerald-500 bg-emerald-500/10" : "text-zinc-500 hover:text-zinc-300"
            )}
          >
            {sphere.isPinned ? <PinOff className="w-4 h-4" /> : <Pin className="w-4 h-4" />}
          </button>
          <button
            onClick={(e) => {
              e.stopPropagation();
              onDelete(sphere.id);
            }}
            className="text-zinc-500 hover:text-rose-400 transition-colors p-1.5"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>
      <h3 className="text-base font-semibold text-white mb-1 group-hover:text-zinc-300 transition-colors flex items-center gap-2">
        {sphere.title}
        {sphere.isPinned && <Pin className="w-3 h-3 text-emerald-500 fill-emerald-500" />}
      </h3>
      {sphere.description && <p className="text-zinc-400 text-xs mb-3 line-clamp-2">{sphere.description}</p>}
      
      {sphere.deadline && (
        <div className="flex items-center gap-1.5 text-xs text-zinc-500 mb-3">
          <Calendar className="w-3.5 h-3.5" />
          <span>Дедлайн: {format(new Date(sphere.deadline), 'd MMM yyyy', { locale: ru })}</span>
        </div>
      )}

      <div className="mt-auto pt-3 border-t border-zinc-800 flex items-center justify-between text-xs text-zinc-500">
        <span>Заметок: {sphere.notesList?.length || 0}</span>
        <div className="flex items-center gap-1 text-white font-medium">
          Открыть <ChevronRight className="w-3 h-3" />
        </div>
      </div>
    </div>
  );
};

export function Spheres() {
  const { spheres, addSphere, deleteSphere, updateSphere, reorderSpheres } = useStore();
  const navigate = useNavigate();
  const [isAdding, setIsAdding] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [deadline, setDeadline] = useState('');
  const [notes, setNotes] = useState('');

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8,
      },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;
    
    addSphere({
      title,
      description,
      deadline: deadline ? new Date(deadline).toISOString() : undefined,
      notes,
    });
    
    setIsAdding(false);
    setTitle('');
    setDescription('');
    setDeadline('');
    setNotes('');
  };

  const sortedSpheres = [...spheres].sort((a, b) => {
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;
    return (a.order ?? 0) - (b.order ?? 0);
  });

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    if (over && active.id !== over.id) {
      const oldIndex = sortedSpheres.findIndex((s) => s.id === active.id);
      const newIndex = sortedSpheres.findIndex((s) => s.id === over.id);
      const newOrder = arrayMove(sortedSpheres, oldIndex, newIndex);
      reorderSpheres(newOrder.map(s => s.id));
    }
  };

  const togglePin = (id: string, isPinned: boolean) => {
    updateSphere(id, { isPinned: !isPinned });
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-white">Сферы развития</h1>
          <p className="text-sm text-zinc-400 mt-1">Области и темы, в которых вы хотите разобраться и преуспеть.</p>
        </div>
        <button
          onClick={() => setIsAdding(true)}
          className="flex items-center gap-2 bg-white text-black px-3 py-1.5 rounded-xl hover:bg-zinc-200 transition-colors text-sm font-medium"
        >
          <Plus className="w-4 h-4" />
          <span className="hidden sm:inline">Добавить сферу</span>
        </button>
      </div>

      {isAdding && (
        <motion.div 
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-zinc-900 p-5 rounded-2xl shadow-sm border border-zinc-800"
        >
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-base font-semibold text-white">Новая сфера</h2>
            <button onClick={() => setIsAdding(false)} className="text-zinc-500 hover:text-zinc-300">
              <X className="w-4 h-4" />
            </button>
          </div>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-zinc-300 mb-1">Название</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full px-3 py-2 text-sm bg-zinc-950 border border-zinc-800 text-white rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500"
                placeholder="напр., Изучить React, Улучшить финансы"
                required
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-zinc-300 mb-1">Описание</label>
              <input
                type="text"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                className="w-full px-3 py-2 text-sm bg-zinc-950 border border-zinc-800 text-white rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500"
                placeholder="Краткое описание вашей цели"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-zinc-300 mb-1">Дедлайн (необязательно)</label>
              <input
                type="date"
                value={deadline}
                onChange={(e) => setDeadline(e.target.value)}
                className="w-full px-3 py-2 text-sm bg-zinc-950 border border-zinc-800 text-white rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500"
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsAdding(false)}
                className="px-3 py-1.5 text-xs text-zinc-400 hover:bg-zinc-800 rounded-xl font-medium transition-colors"
              >
                Отмена
              </button>
              <button
                type="submit"
                className="px-3 py-1.5 text-xs bg-white text-black rounded-xl hover:bg-zinc-200 font-medium transition-colors"
              >
                Сохранить сферу
              </button>
            </div>
          </form>
        </motion.div>
      )}

      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragEnd={handleDragEnd}
      >
        <SortableContext
          items={sortedSpheres.map(s => s.id)}
          strategy={rectSortingStrategy}
        >
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <AnimatePresence mode="popLayout">
              {sortedSpheres.map((sphere) => (
                <motion.div
                  key={sphere.id}
                  layout
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.9 }}
                  transition={{ duration: 0.2 }}
                >
                  <SortableSphere
                    sphere={sphere}
                    onDelete={deleteSphere}
                    onTogglePin={togglePin}
                    onClick={() => navigate(`/spheres/${sphere.id}`)}
                  />
                </motion.div>
              ))}
            </AnimatePresence>
            
            {spheres.length === 0 && !isAdding && (
              <div className="col-span-full py-12 text-center text-zinc-500 bg-zinc-900/50 rounded-2xl border border-dashed border-zinc-800">
                <Target className="w-10 h-10 mx-auto text-zinc-600 mb-3" />
                <p className="text-base font-medium text-zinc-300">Пока нет сфер</p>
                <p className="text-sm mt-1">Добавьте вашу первую область развития, чтобы начать.</p>
              </div>
            )}
          </div>
        </SortableContext>
      </DndContext>
    </div>
  );
}
