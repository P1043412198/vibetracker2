/**
 * Налоговый и финансовый календарь Республики Беларусь.
 * Для физлиц, ИП и наёмных работников. 2026 год.
 */

export type TaxEventCategory =
  | 'individual'    // Физлица
  | 'ip'            // ИП (УСН/общая)
  | 'fszn'          // ФСЗН
  | 'declaration'   // Декларации
  | 'utility'       // Коммунальные/обязательные платежи
  | 'reminder';     // Регулярные напоминания

export interface TaxCalendarEvent {
  id: string;
  title: string;
  category: TaxEventCategory;
  /** «25.04», «до 31 марта», «ежемесячно до 22-го» и т.п. */
  due: string;
  description: string;
  /** Кому актуально */
  audience: 'all' | 'individuals' | 'ip' | 'employed';
  /** Месяц для сортировки/фильтрации (1-12), null — повторяется каждый месяц */
  month: number | null;
  /** Иконка-эмодзи */
  emoji: string;
}

export const TAX_CALENDAR_2026: TaxCalendarEvent[] = [
  // Январь
  {
    id: 'fszn-monthly',
    title: 'ФСЗН для ИП — авансовый платёж',
    category: 'fszn',
    due: 'до 25-го числа каждого месяца',
    description:
      'Индивидуальные предприниматели платят ежемесячный взнос в ФСЗН (35% от МЗП по умолчанию). За год — не менее 12 МЗП.',
    audience: 'ip',
    month: null,
    emoji: '💼',
  },
  {
    id: 'usn-quarterly',
    title: 'УСН — налог за квартал',
    category: 'ip',
    due: 'до 22 апреля / 22 июля / 22 октября / 22 января',
    description:
      'ИП на УСН платят налог по итогам каждого квартала. Декларация — до 20 числа после квартала, оплата — до 22-го.',
    audience: 'ip',
    month: null,
    emoji: '📊',
  },
  {
    id: 'declaration-jan',
    title: 'Подоходный налог — годовая декларация',
    category: 'declaration',
    due: 'до 31 марта 2026',
    description:
      'Физлица, получившие доходы из-за рубежа, от продажи второго объекта недвижимости/авто за 5 лет, подают декларацию о доходах за 2025 год.',
    audience: 'individuals',
    month: 3,
    emoji: '📄',
  },
  {
    id: 'declaration-pay',
    title: 'Доплата по декларации',
    category: 'declaration',
    due: 'до 1 июня 2026',
    description:
      'Если по итогам декларации насчитан налог к доплате — оплатить до 1 июня. Иначе пени и штраф (до 30 БВ).',
    audience: 'individuals',
    month: 6,
    emoji: '💸',
  },
  {
    id: 'property-tax',
    title: 'Налог на недвижимость / землю',
    category: 'individual',
    due: 'до 15 ноября 2026',
    description:
      'Физлица оплачивают налог на жильё и земельный налог по уведомлению из налоговой. Лучше проверить в личном кабинете на portal.nalog.gov.by.',
    audience: 'individuals',
    month: 11,
    emoji: '🏠',
  },
  {
    id: 'transport-tax',
    title: 'Транспортный налог',
    category: 'individual',
    due: 'до 15 ноября 2026',
    description:
      'Введён вместо госпошлины за допуск ТС. Размер зависит от массы и года выпуска. Можно оплатить через ЕРИП или банк-приложение.',
    audience: 'individuals',
    month: 11,
    emoji: '🚗',
  },
  {
    id: 'self-employed-quarter',
    title: 'НПД самозанятых — налог за месяц',
    category: 'ip',
    due: 'до 22-го числа месяца, следующего за отчётным',
    description:
      'Самозанятые на НПД (профдоход) платят 10% (для физлиц) или 20% (для юрлиц-клиентов). Расчёт — автоматический в приложении НПД.',
    audience: 'ip',
    month: null,
    emoji: '👤',
  },
  {
    id: 'social-deduction',
    title: 'Социальный вычет — лечение и образование',
    category: 'individual',
    due: 'в течение года при удержании или до 31 марта 2026',
    description:
      'Можно вернуть подоходный налог за платное лечение, обучение себя/детей, страхование жизни. Через бухгалтерию работодателя или декларацию.',
    audience: 'employed',
    month: 3,
    emoji: '🩺',
  },
  {
    id: 'property-deduction',
    title: 'Имущественный вычет (ипотека)',
    category: 'individual',
    due: 'в течение года при удержании',
    description:
      'Если строите/покупаете единственное жильё — вычет на сумму расходов и процентов по ипотеке. Подавайте справки бухгалтеру.',
    audience: 'employed',
    month: null,
    emoji: '🏡',
  },
  {
    id: 'standard-deduction',
    title: 'Стандартный вычет 174 руб',
    category: 'individual',
    due: 'ежемесячно при удержании',
    description:
      'Если з/п не превышает порог (1054 руб в 2026), работодатель вычитает 174 руб из налогооблагаемой базы. На каждого ребёнка — 51 руб.',
    audience: 'employed',
    month: null,
    emoji: '👶',
  },
  {
    id: 'utility-payment',
    title: 'ЖКХ — оплата за прошлый месяц',
    category: 'utility',
    due: 'до 25-го числа каждого месяца',
    description:
      'Просрочка → пени 0.3% за каждый день. Лучше настроить автооплату через ЕРИП или интернет-банкинг.',
    audience: 'all',
    month: null,
    emoji: '🏢',
  },
  {
    id: 'fszn-employer',
    title: 'ФСЗН за работников',
    category: 'fszn',
    due: 'до 22-го числа следующего месяца',
    description:
      'Работодатель платит 34% ФСЗН (28% пенсионных + 6% социальных) и 1% удерживает с работника. Самостоятельно платить не нужно — это делает бухгалтерия.',
    audience: 'employed',
    month: null,
    emoji: '🏛️',
  },
  {
    id: 'erip-subscriptions',
    title: 'ЕРИП — проверка автоплатежей',
    category: 'reminder',
    due: 'раз в квартал',
    description:
      'Проверьте список автоплатежей в банке: интернет, ТВ, мобильный, страхование, школа, кружки. Часто бывают забытые подписки.',
    audience: 'all',
    month: null,
    emoji: '🔍',
  },
  {
    id: 'budget-review',
    title: 'Ревизия бюджета',
    category: 'reminder',
    due: 'до 5-го числа каждого месяца',
    description:
      'Закройте предыдущий месяц: разнесите траты по категориям, сравните с планом, составьте план на текущий месяц.',
    audience: 'all',
    month: null,
    emoji: '📋',
  },
  {
    id: 'deposit-renew',
    title: 'Проверка депозитов',
    category: 'reminder',
    due: 'за 7 дней до окончания срока',
    description:
      'Не пропустите окончание депозита — после автопролонгации часто ставка ниже. Сравните с актуальными предложениями на myfin.by.',
    audience: 'all',
    month: null,
    emoji: '🏦',
  },
];

/**
 * Удобный массив для UI: события на ближайшие 90 дней.
 */
export function getUpcomingEvents(daysAhead = 90): TaxCalendarEvent[] {
  const now = new Date();
  const currentMonth = now.getMonth() + 1;
  return TAX_CALENDAR_2026.filter((e) => {
    if (e.month === null) return true; // Регулярные показываем всегда
    const monthDiff = (e.month - currentMonth + 12) % 12;
    return monthDiff <= Math.ceil(daysAhead / 30);
  });
}
