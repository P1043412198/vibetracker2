/**
 * Готовые шаблоны регулярных платежей через ЕРИП — для быстрого добавления
 * в `regularPayments`. Категория сопоставлена с категориями расходов
 * приложения, чтобы автоматически попадать в бюджет.
 */

export interface EripTemplate {
  id: string;
  name: string;
  defaultDueDay: number;
  category: string;
  group: 'utilities' | 'telecom' | 'education' | 'transport' | 'gov' | 'other';
  hint?: string;
}

export const ERIP_TEMPLATES: EripTemplate[] = [
  // Коммуналка
  {
    id: 'erip-belarusenergo',
    name: 'Беларусьэнерго (электроэнергия)',
    defaultDueDay: 25,
    category: 'Коммуналка',
    group: 'utilities',
    hint: 'Платежи по показаниям счётчика; обычно до 25 числа',
  },
  {
    id: 'erip-belgaz',
    name: 'Беларусгаз (газ)',
    defaultDueDay: 25,
    category: 'Коммуналка',
    group: 'utilities',
  },
  {
    id: 'erip-vodokanal',
    name: 'Минскводоканал (вода)',
    defaultDueDay: 25,
    category: 'Коммуналка',
    group: 'utilities',
  },
  {
    id: 'erip-zhkx',
    name: 'ЖКХ (квартплата)',
    defaultDueDay: 25,
    category: 'Коммуналка',
    group: 'utilities',
  },
  {
    id: 'erip-teploset',
    name: 'Теплосеть',
    defaultDueDay: 25,
    category: 'Коммуналка',
    group: 'utilities',
  },

  // Связь
  {
    id: 'erip-mts',
    name: 'МТС',
    defaultDueDay: 1,
    category: 'Связь',
    group: 'telecom',
  },
  {
    id: 'erip-a1',
    name: 'А1',
    defaultDueDay: 1,
    category: 'Связь',
    group: 'telecom',
  },
  {
    id: 'erip-life',
    name: 'life:)',
    defaultDueDay: 1,
    category: 'Связь',
    group: 'telecom',
  },
  {
    id: 'erip-beltelecom',
    name: 'Белтелеком (интернет)',
    defaultDueDay: 25,
    category: 'Связь',
    group: 'telecom',
  },
  {
    id: 'erip-cosmos',
    name: 'Cosmos TV',
    defaultDueDay: 5,
    category: 'Связь',
    group: 'telecom',
  },

  // Транспорт
  {
    id: 'erip-minsktrans',
    name: 'Минсктранс (проездной)',
    defaultDueDay: 1,
    category: 'Транспорт',
    group: 'transport',
  },
  {
    id: 'erip-bzhd',
    name: 'БЖД (электричка / поездки)',
    defaultDueDay: 1,
    category: 'Транспорт',
    group: 'transport',
  },

  // Образование
  {
    id: 'erip-school',
    name: 'Школа (питание / охрана)',
    defaultDueDay: 1,
    category: 'Образование',
    group: 'education',
  },
  {
    id: 'erip-kindergarten',
    name: 'Детский сад',
    defaultDueDay: 1,
    category: 'Образование',
    group: 'education',
  },
  {
    id: 'erip-music',
    name: 'Кружки / музыкальная школа',
    defaultDueDay: 5,
    category: 'Образование',
    group: 'education',
  },

  // Госуслуги
  {
    id: 'erip-tax',
    name: 'Налоги (ИП / профдоход)',
    defaultDueDay: 22,
    category: 'Налоги',
    group: 'gov',
    hint: 'Сроки уплаты — см. налоговый календарь МНС',
  },
  {
    id: 'erip-fszn',
    name: 'ФСЗН (фикс. взнос)',
    defaultDueDay: 1,
    category: 'Налоги',
    group: 'gov',
  },
];
