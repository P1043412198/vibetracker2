/**
 * Шаблоны программ тренировок: PPL, Upper/Lower, 5x5, FullBody.
 * Используются на странице «Тренировки» для быстрого создания структуры.
 */
import type { MuscleGroup, WorkoutMetric } from '../types';

export interface WorkoutProgramExercise {
  name: string;
  muscleGroup: MuscleGroup;
  metrics?: WorkoutMetric[];
  notes?: string;
  /** Подсказка по подходам/повторениям, отображается в notes */
  scheme?: string;
}

export interface WorkoutProgramDay {
  name: string;
  exercises: WorkoutProgramExercise[];
}

export interface WorkoutProgramTemplate {
  id: string;
  title: string;
  blurb: string;
  level: 'beginner' | 'intermediate' | 'advanced';
  daysPerWeek: number;
  emoji: string;
  accent: 'emerald' | 'blue' | 'amber' | 'rose' | 'indigo' | 'violet';
  days: WorkoutProgramDay[];
}

const baseMetrics: WorkoutMetric[] = ['weight', 'reps'];

export const WORKOUT_PROGRAMS: WorkoutProgramTemplate[] = [
  {
    id: 'fullbody-3x',
    title: 'Full Body 3 раза в неделю',
    blurb: 'Идеально для новичков: всё тело за тренировку, 3 раза в неделю',
    level: 'beginner',
    daysPerWeek: 3,
    emoji: '🏃',
    accent: 'emerald',
    days: [
      {
        name: 'Тренировка A',
        exercises: [
          { name: 'Приседания со штангой', muscleGroup: 'legs', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Жим лёжа', muscleGroup: 'chest', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Тяга в наклоне', muscleGroup: 'back', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Армейский жим', muscleGroup: 'shoulders', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Планка', muscleGroup: 'core', metrics: ['time'], scheme: '3×30-60 сек' },
        ],
      },
      {
        name: 'Тренировка B',
        exercises: [
          { name: 'Становая тяга', muscleGroup: 'legs', metrics: baseMetrics, scheme: '3×6-8' },
          { name: 'Подтягивания', muscleGroup: 'back', metrics: baseMetrics, scheme: '3×макс' },
          { name: 'Жим гантелей сидя', muscleGroup: 'shoulders', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Отжимания на брусьях', muscleGroup: 'chest', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Скручивания на пресс', muscleGroup: 'core', metrics: ['reps'], scheme: '3×15-20' },
        ],
      },
    ],
  },
  {
    id: 'ppl-6x',
    title: 'Push / Pull / Legs (6 раз/нед)',
    blurb: 'Классика для опытных. По 2 цикла Push-Pull-Legs в неделю.',
    level: 'intermediate',
    daysPerWeek: 6,
    emoji: '🔥',
    accent: 'rose',
    days: [
      {
        name: 'Push (грудь, плечи, трицепс)',
        exercises: [
          { name: 'Жим лёжа', muscleGroup: 'chest', metrics: baseMetrics, scheme: '4×6-8' },
          { name: 'Жим гантелей наклонный', muscleGroup: 'chest', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Армейский жим', muscleGroup: 'shoulders', metrics: baseMetrics, scheme: '3×6-8' },
          { name: 'Махи гантелями в стороны', muscleGroup: 'shoulders', metrics: baseMetrics, scheme: '3×12-15' },
          { name: 'Французский жим', muscleGroup: 'arms', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Разгибания на блоке', muscleGroup: 'arms', metrics: baseMetrics, scheme: '3×12-15' },
        ],
      },
      {
        name: 'Pull (спина, бицепс)',
        exercises: [
          { name: 'Подтягивания', muscleGroup: 'back', metrics: baseMetrics, scheme: '4×макс' },
          { name: 'Тяга штанги в наклоне', muscleGroup: 'back', metrics: baseMetrics, scheme: '3×6-8' },
          { name: 'Тяга вертикального блока', muscleGroup: 'back', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Тяга к лицу', muscleGroup: 'back', metrics: baseMetrics, scheme: '3×12-15' },
          { name: 'Подъём штанги на бицепс', muscleGroup: 'arms', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Молотки с гантелями', muscleGroup: 'arms', metrics: baseMetrics, scheme: '3×10-12' },
        ],
      },
      {
        name: 'Legs (ноги, кор)',
        exercises: [
          { name: 'Приседания со штангой', muscleGroup: 'legs', metrics: baseMetrics, scheme: '4×6-8' },
          { name: 'Румынская тяга', muscleGroup: 'legs', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Жим ногами', muscleGroup: 'legs', metrics: baseMetrics, scheme: '3×10-12' },
          { name: 'Сгибания ног в тренажёре', muscleGroup: 'legs', metrics: baseMetrics, scheme: '3×12-15' },
          { name: 'Подъёмы на носки', muscleGroup: 'legs', metrics: baseMetrics, scheme: '4×15-20' },
          { name: 'Скручивания на блоке', muscleGroup: 'core', metrics: ['reps'], scheme: '3×15-20' },
        ],
      },
    ],
  },
  {
    id: 'upper-lower-4x',
    title: 'Upper / Lower (4 раза/нед)',
    blurb: 'Хороший баланс между объёмом и восстановлением',
    level: 'intermediate',
    daysPerWeek: 4,
    emoji: '⚖️',
    accent: 'blue',
    days: [
      {
        name: 'Upper A',
        exercises: [
          { name: 'Жим лёжа', muscleGroup: 'chest', metrics: baseMetrics, scheme: '4×6-8' },
          { name: 'Тяга штанги в наклоне', muscleGroup: 'back', metrics: baseMetrics, scheme: '4×6-8' },
          { name: 'Армейский жим', muscleGroup: 'shoulders', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Подтягивания', muscleGroup: 'back', metrics: baseMetrics, scheme: '3×макс' },
          { name: 'Подъём на бицепс', muscleGroup: 'arms', metrics: baseMetrics, scheme: '3×10-12' },
          { name: 'Разгибания на трицепс', muscleGroup: 'arms', metrics: baseMetrics, scheme: '3×10-12' },
        ],
      },
      {
        name: 'Lower A',
        exercises: [
          { name: 'Приседания со штангой', muscleGroup: 'legs', metrics: baseMetrics, scheme: '4×6-8' },
          { name: 'Румынская тяга', muscleGroup: 'legs', metrics: baseMetrics, scheme: '3×8-10' },
          { name: 'Выпады с гантелями', muscleGroup: 'legs', metrics: baseMetrics, scheme: '3×10-12' },
          { name: 'Подъёмы на носки', muscleGroup: 'legs', metrics: baseMetrics, scheme: '4×15-20' },
          { name: 'Планка', muscleGroup: 'core', metrics: ['time'], scheme: '3×60 сек' },
        ],
      },
      {
        name: 'Upper B',
        exercises: [
          { name: 'Жим гантелей наклонный', muscleGroup: 'chest', metrics: baseMetrics, scheme: '4×8-10' },
          { name: 'Тяга вертикального блока', muscleGroup: 'back', metrics: baseMetrics, scheme: '4×8-10' },
          { name: 'Махи гантелями', muscleGroup: 'shoulders', metrics: baseMetrics, scheme: '3×12-15' },
          { name: 'Тяга к лицу', muscleGroup: 'back', metrics: baseMetrics, scheme: '3×12-15' },
          { name: 'Молотки на бицепс', muscleGroup: 'arms', metrics: baseMetrics, scheme: '3×10-12' },
          { name: 'Отжимания на брусьях', muscleGroup: 'arms', metrics: baseMetrics, scheme: '3×8-10' },
        ],
      },
      {
        name: 'Lower B',
        exercises: [
          { name: 'Становая тяга', muscleGroup: 'legs', metrics: baseMetrics, scheme: '4×5-6' },
          { name: 'Жим ногами', muscleGroup: 'legs', metrics: baseMetrics, scheme: '4×10-12' },
          { name: 'Сгибания ног', muscleGroup: 'legs', metrics: baseMetrics, scheme: '3×12-15' },
          { name: 'Болгарские выпады', muscleGroup: 'legs', metrics: baseMetrics, scheme: '3×10-12' },
          { name: 'Скручивания', muscleGroup: 'core', metrics: ['reps'], scheme: '3×15-20' },
        ],
      },
    ],
  },
  {
    id: 'starting-5x5',
    title: 'StrongLifts 5x5',
    blurb: 'Классическая программа на силу для новичков. 3 раза в неделю.',
    level: 'beginner',
    daysPerWeek: 3,
    emoji: '🏆',
    accent: 'amber',
    days: [
      {
        name: 'Тренировка A',
        exercises: [
          { name: 'Приседания со штангой', muscleGroup: 'legs', metrics: baseMetrics, scheme: '5×5' },
          { name: 'Жим лёжа', muscleGroup: 'chest', metrics: baseMetrics, scheme: '5×5' },
          { name: 'Тяга штанги в наклоне', muscleGroup: 'back', metrics: baseMetrics, scheme: '5×5' },
        ],
      },
      {
        name: 'Тренировка B',
        exercises: [
          { name: 'Приседания со штангой', muscleGroup: 'legs', metrics: baseMetrics, scheme: '5×5' },
          { name: 'Армейский жим', muscleGroup: 'shoulders', metrics: baseMetrics, scheme: '5×5' },
          { name: 'Становая тяга', muscleGroup: 'legs', metrics: baseMetrics, scheme: '1×5' },
        ],
      },
    ],
  },
  {
    id: 'home-bodyweight',
    title: 'Дома без оборудования',
    blurb: 'Только своё тело. 4 раза в неделю, 30-40 минут.',
    level: 'beginner',
    daysPerWeek: 4,
    emoji: '🏠',
    accent: 'violet',
    days: [
      {
        name: 'Верх тела',
        exercises: [
          { name: 'Отжимания', muscleGroup: 'chest', metrics: ['reps'], scheme: '4×макс' },
          { name: 'Отжимания узким хватом', muscleGroup: 'arms', metrics: ['reps'], scheme: '3×макс' },
          { name: 'Подтягивания (или негативы)', muscleGroup: 'back', metrics: ['reps'], scheme: '4×макс' },
          { name: 'Pike push-up (на плечи)', muscleGroup: 'shoulders', metrics: ['reps'], scheme: '3×8-12' },
        ],
      },
      {
        name: 'Низ тела',
        exercises: [
          { name: 'Приседания', muscleGroup: 'legs', metrics: ['reps'], scheme: '4×15-25' },
          { name: 'Выпады', muscleGroup: 'legs', metrics: ['reps'], scheme: '3×12 на ногу' },
          { name: 'Болгарские выпады', muscleGroup: 'legs', metrics: ['reps'], scheme: '3×10 на ногу' },
          { name: 'Ягодичный мостик', muscleGroup: 'legs', metrics: ['reps'], scheme: '3×20' },
        ],
      },
      {
        name: 'Кор и пресс',
        exercises: [
          { name: 'Планка', muscleGroup: 'core', metrics: ['time'], scheme: '4×60 сек' },
          { name: 'Боковая планка', muscleGroup: 'core', metrics: ['time'], scheme: '3×30 сек' },
          { name: 'Скручивания', muscleGroup: 'core', metrics: ['reps'], scheme: '3×20' },
          { name: 'Альпинист', muscleGroup: 'core', metrics: ['time'], scheme: '3×30 сек' },
        ],
      },
      {
        name: 'Кардио',
        exercises: [
          { name: 'Бёрпи', muscleGroup: 'cardio', metrics: ['reps'], scheme: '5×10' },
          { name: 'Прыжки на скакалке', muscleGroup: 'cardio', metrics: ['time'], scheme: '5×60 сек' },
          { name: 'Прыжки звёздочкой', muscleGroup: 'cardio', metrics: ['reps'], scheme: '3×30' },
        ],
      },
    ],
  },
];
