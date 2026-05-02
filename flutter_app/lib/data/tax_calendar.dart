/// Tax and financial calendar for Belarus 2026 (port of src/data/taxCalendar.ts).

enum TaxEventCategory { individual, ip, fszn, declaration, utility, reminder }

class TaxCalendarEvent {
  final String id;
  final String title;
  final TaxEventCategory category;
  final String due;
  final String description;
  final String audience; // 'all' | 'individuals' | 'ip' | 'employed'
  final int? month; // 1-12, null = every month
  final String emoji;

  const TaxCalendarEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.due,
    required this.description,
    required this.audience,
    required this.month,
    required this.emoji,
  });
}

const taxCalendar2026 = <TaxCalendarEvent>[
  TaxCalendarEvent(
    id: 'fszn-monthly', title: 'ФСЗН для ИП \u2014 авансовый платёж',
    category: TaxEventCategory.fszn,
    due: 'до 25-го числа каждого месяца',
    description: 'Индивидуальные предприниматели платят ежемесячный взнос в ФСЗН (35% от МЗП по умолчанию). За год \u2014 не менее 12 МЗП.',
    audience: 'ip', month: null, emoji: '\u{1F4BC}',
  ),
  TaxCalendarEvent(
    id: 'usn-quarterly', title: 'УСН \u2014 налог за квартал',
    category: TaxEventCategory.ip,
    due: 'до 22 апреля / 22 июля / 22 октября / 22 января',
    description: 'ИП на УСН платят налог по итогам каждого квартала. Декларация \u2014 до 20 числа после квартала, оплата \u2014 до 22-го.',
    audience: 'ip', month: null, emoji: '\u{1F4CA}',
  ),
  TaxCalendarEvent(
    id: 'declaration-jan', title: 'Подоходный налог \u2014 годовая декларация',
    category: TaxEventCategory.declaration,
    due: 'до 31 марта 2026',
    description: 'Физлица, получившие доходы из-за рубежа, от продажи второго объекта недвижимости/авто за 5 лет, подают декларацию о доходах за 2025 год.',
    audience: 'individuals', month: 3, emoji: '\u{1F4C4}',
  ),
  TaxCalendarEvent(
    id: 'declaration-pay', title: 'Доплата по декларации',
    category: TaxEventCategory.declaration,
    due: 'до 1 июня 2026',
    description: 'Если по итогам декларации насчитан налог к доплате \u2014 оплатить до 1 июня. Иначе пени и штраф (до 30 БВ).',
    audience: 'individuals', month: 6, emoji: '\u{1F4B8}',
  ),
  TaxCalendarEvent(
    id: 'property-tax', title: 'Налог на недвижимость / землю',
    category: TaxEventCategory.individual,
    due: 'до 15 ноября 2026',
    description: 'Физлица оплачивают налог на жильё и земельный налог по уведомлению из налоговой. Лучше проверить в личном кабинете на portal.nalog.gov.by.',
    audience: 'individuals', month: 11, emoji: '\u{1F3E0}',
  ),
  TaxCalendarEvent(
    id: 'transport-tax', title: 'Транспортный налог',
    category: TaxEventCategory.individual,
    due: 'до 15 ноября 2026',
    description: 'Введён вместо госпошлины за допуск ТС. Размер зависит от массы и года выпуска. Можно оплатить через ЕРИП или банк-приложение.',
    audience: 'individuals', month: 11, emoji: '\u{1F697}',
  ),
  TaxCalendarEvent(
    id: 'self-employed-quarter', title: 'НПД самозанятых \u2014 налог за месяц',
    category: TaxEventCategory.ip,
    due: 'до 22-го числа месяца, следующего за отчётным',
    description: 'Самозанятые на НПД (профдоход) платят 10% (для физлиц) или 20% (для юрлиц-клиентов). Расчёт \u2014 автоматический в приложении НПД.',
    audience: 'ip', month: null, emoji: '\u{1F464}',
  ),
  TaxCalendarEvent(
    id: 'social-deduction', title: 'Социальный вычет \u2014 лечение и образование',
    category: TaxEventCategory.individual,
    due: 'в течение года при удержании или до 31 марта 2026',
    description: 'Можно вернуть подоходный налог за платное лечение, обучение себя/детей, страхование жизни. Через бухгалтерию работодателя или декларацию.',
    audience: 'employed', month: 3, emoji: '\u{1FA7A}',
  ),
  TaxCalendarEvent(
    id: 'property-deduction', title: 'Имущественный вычет (ипотека)',
    category: TaxEventCategory.individual,
    due: 'в течение года при удержании',
    description: 'Если строите/покупаете единственное жильё \u2014 вычет на сумму расходов и процентов по ипотеке. Подавайте справки бухгалтеру.',
    audience: 'employed', month: null, emoji: '\u{1F3E1}',
  ),
  TaxCalendarEvent(
    id: 'standard-deduction', title: 'Стандартный вычет 174 руб',
    category: TaxEventCategory.individual,
    due: 'ежемесячно при удержании',
    description: 'Если з/п не превышает порог (1054 руб в 2026), работодатель вычитает 174 руб из налогооблагаемой базы. На каждого ребёнка \u2014 51 руб.',
    audience: 'employed', month: null, emoji: '\u{1F476}',
  ),
  TaxCalendarEvent(
    id: 'utility-payment', title: 'ЖКХ \u2014 оплата за прошлый месяц',
    category: TaxEventCategory.utility,
    due: 'до 25-го числа каждого месяца',
    description: 'Просрочка \u2192 пени 0.3% за каждый день. Лучше настроить автооплату через ЕРИП или интернет-банкинг.',
    audience: 'all', month: null, emoji: '\u{1F3E2}',
  ),
  TaxCalendarEvent(
    id: 'fszn-employer', title: 'ФСЗН за работников',
    category: TaxEventCategory.fszn,
    due: 'до 22-го числа следующего месяца',
    description: 'Работодатель платит 34% ФСЗН (28% пенсионных + 6% социальных) и 1% удерживает с работника. Самостоятельно платить не нужно \u2014 это делает бухгалтерия.',
    audience: 'employed', month: null, emoji: '\u{1F3DB}\u{FE0F}',
  ),
  TaxCalendarEvent(
    id: 'erip-subscriptions', title: 'ЕРИП \u2014 проверка автоплатежей',
    category: TaxEventCategory.reminder,
    due: 'раз в квартал',
    description: 'Проверьте список автоплатежей в банке: интернет, ТВ, мобильный, страхование, школа, кружки. Часто бывают забытые подписки.',
    audience: 'all', month: null, emoji: '\u{1F50D}',
  ),
  TaxCalendarEvent(
    id: 'budget-review', title: 'Ревизия бюджета',
    category: TaxEventCategory.reminder,
    due: 'до 5-го числа каждого месяца',
    description: 'Закройте предыдущий месяц: разнесите траты по категориям, сравните с планом, составьте план на текущий месяц.',
    audience: 'all', month: null, emoji: '\u{1F4CB}',
  ),
  TaxCalendarEvent(
    id: 'deposit-renew', title: 'Проверка депозитов',
    category: TaxEventCategory.reminder,
    due: 'за 7 дней до окончания срока',
    description: 'Не пропустите окончание депозита \u2014 после автопролонгации часто ставка ниже. Сравните с актуальными предложениями на myfin.by.',
    audience: 'all', month: null, emoji: '\u{1F3E6}',
  ),
];

const monthNames = [
  'Январь','Февраль','Март','Апрель','Май','Июнь',
  'Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь',
];
