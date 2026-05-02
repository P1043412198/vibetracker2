/**
 * Шаблоны атомных привычек по областям жизни.
 * Используются на странице «Привычки» для быстрого добавления.
 */
import type { HabitFrequency, HabitType } from '../types';

export interface HabitTemplate {
  title: string;
  type: HabitType;
  icon: string;
  description?: string;
  targetValue?: number;
  unit?: string;
  frequency?: HabitFrequency;
}

export interface HabitTemplateCategory {
  id: string;
  title: string;
  emoji: string;
  blurb: string;
  accent: 'emerald' | 'blue' | 'amber' | 'rose' | 'indigo' | 'violet';
  templates: HabitTemplate[];
}

export const HABIT_TEMPLATES: HabitTemplateCategory[] = [
  {
    id: 'health',
    title: 'Здоровье и тело',
    emoji: '💪',
    blurb: 'Базовые ежедневные ритуалы для энергии',
    accent: 'emerald',
    templates: [
      { title: 'Стакан воды утром', type: 'good', icon: '💧', frequency: { type: 'daily' } },
      { title: 'Выпить 2 л воды', type: 'good', icon: '🚰', targetValue: 2000, unit: 'мл', frequency: { type: 'daily' } },
      { title: '10 000 шагов', type: 'good', icon: '🚶', targetValue: 10000, unit: 'шагов', frequency: { type: 'daily' } },
      { title: 'Зарядка 10 минут', type: 'good', icon: '🤸', targetValue: 10, unit: 'мин', frequency: { type: 'daily' } },
      { title: 'Растяжка перед сном', type: 'good', icon: '🧘', frequency: { type: 'daily' } },
      { title: 'Лечь до 23:00', type: 'good', icon: '🌙', frequency: { type: 'daily' } },
      { title: 'Не есть после 19:00', type: 'good', icon: '🍽️', frequency: { type: 'daily' } },
      { title: 'Витамин D', type: 'good', icon: '☀️', frequency: { type: 'daily' } },
    ],
  },
  {
    id: 'fitness',
    title: 'Спорт и движение',
    emoji: '🏋️',
    blurb: 'Регулярные тренировки и активность',
    accent: 'blue',
    templates: [
      { title: 'Силовая 3 раза в неделю', type: 'good', icon: '🏋️', frequency: { type: 'times_per_week', count: 3 } },
      { title: 'Кардио 2 раза в неделю', type: 'good', icon: '🏃', frequency: { type: 'times_per_week', count: 2 } },
      { title: 'Прогулка после ужина', type: 'good', icon: '🚶‍♂️', frequency: { type: 'daily' } },
      { title: 'Подтягивания 5 раз', type: 'good', icon: '🤸‍♂️', targetValue: 5, unit: 'раз', frequency: { type: 'daily' } },
      { title: 'Отжимания 20 раз', type: 'good', icon: '💥', targetValue: 20, unit: 'раз', frequency: { type: 'daily' } },
      { title: 'Не пропускать тренировку', type: 'good', icon: '⏱️', frequency: { type: 'specific_days', days: [1, 3, 5] } },
    ],
  },
  {
    id: 'mind',
    title: 'Фокус и ум',
    emoji: '🧠',
    blurb: 'Привычки для мышления и продуктивности',
    accent: 'indigo',
    templates: [
      { title: 'Чтение 20 минут', type: 'good', icon: '📖', targetValue: 20, unit: 'мин', frequency: { type: 'daily' } },
      { title: 'Медитация 5 минут', type: 'good', icon: '🧘', targetValue: 5, unit: 'мин', frequency: { type: 'daily' } },
      { title: 'Дневник 3 строчки', type: 'good', icon: '📝', frequency: { type: 'daily' } },
      { title: 'Помодоро ×4', type: 'good', icon: '🍅', targetValue: 4, unit: 'сессий', frequency: { type: 'daily' } },
      { title: 'Никаких соцсетей до 12:00', type: 'good', icon: '📵', frequency: { type: 'daily' } },
      { title: 'Изучать иностранный 15 мин', type: 'good', icon: '🇬🇧', targetValue: 15, unit: 'мин', frequency: { type: 'daily' } },
    ],
  },
  {
    id: 'finance',
    title: 'Финансы',
    emoji: '💰',
    blurb: 'Денежные привычки финграмотного человека',
    accent: 'amber',
    templates: [
      { title: 'Записать траты дня', type: 'good', icon: '✍️', frequency: { type: 'daily' } },
      { title: 'Отложить 10% с дохода', type: 'good', icon: '🐖', frequency: { type: 'specific_days', days: [1, 15] } },
      { title: 'Просмотреть бюджет', type: 'good', icon: '📊', frequency: { type: 'specific_days', days: [0] } },
      { title: 'Оплатить ЖКХ вовремя', type: 'good', icon: '🏠', frequency: { type: 'specific_days', days: [25] } },
      { title: 'Не тратить на спонтанные покупки', type: 'good', icon: '🛑', frequency: { type: 'daily' } },
      { title: 'Прочитать 1 статью про деньги', type: 'good', icon: '📰', frequency: { type: 'daily' } },
    ],
  },
  {
    id: 'relations',
    title: 'Отношения',
    emoji: '❤️',
    blurb: 'Близкие, семья, друзья',
    accent: 'rose',
    templates: [
      { title: 'Позвонить родителям', type: 'good', icon: '📞', frequency: { type: 'times_per_week', count: 2 } },
      { title: 'Качественное время с близким', type: 'good', icon: '🤝', frequency: { type: 'daily' } },
      { title: 'Поблагодарить кого-то', type: 'good', icon: '🙏', frequency: { type: 'daily' } },
      { title: 'Без телефона за ужином', type: 'good', icon: '🍽️', frequency: { type: 'daily' } },
      { title: 'Написать другу «как дела»', type: 'good', icon: '💬', frequency: { type: 'times_per_week', count: 2 } },
    ],
  },
  {
    id: 'bad',
    title: 'Избавиться от плохих',
    emoji: '🚫',
    blurb: 'Минусы, которые хочется убрать из жизни',
    accent: 'rose',
    templates: [
      { title: 'Не курить', type: 'bad', icon: '🚬', frequency: { type: 'daily' } },
      { title: 'Не пить алкоголь', type: 'bad', icon: '🍺', frequency: { type: 'daily' } },
      { title: 'Не есть сладкое', type: 'bad', icon: '🍰', frequency: { type: 'daily' } },
      { title: 'Не залипать в TikTok', type: 'bad', icon: '📱', frequency: { type: 'daily' } },
      { title: 'Не доедать «по инерции»', type: 'bad', icon: '🍔', frequency: { type: 'daily' } },
      { title: 'Не говорить «я не могу»', type: 'bad', icon: '🗣️', frequency: { type: 'daily' } },
    ],
  },
  {
    id: 'home',
    title: 'Быт и порядок',
    emoji: '🏠',
    blurb: 'Дом, чистота, порядок',
    accent: 'violet',
    templates: [
      { title: 'Заправить кровать', type: 'good', icon: '🛏️', frequency: { type: 'daily' } },
      { title: 'Помыть посуду сразу', type: 'good', icon: '🧽', frequency: { type: 'daily' } },
      { title: 'Уборка 15 минут', type: 'good', icon: '🧹', targetValue: 15, unit: 'мин', frequency: { type: 'daily' } },
      { title: 'Подготовить одежду на завтра', type: 'good', icon: '👔', frequency: { type: 'daily' } },
      { title: 'Полить цветы', type: 'good', icon: '🪴', frequency: { type: 'specific_days', days: [1, 4] } },
    ],
  },
];
