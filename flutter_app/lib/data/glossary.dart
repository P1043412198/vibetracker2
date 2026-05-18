/// Financial glossary — Belarus context (port of src/data/glossary.ts).

enum GlossaryGroup { personal, belarus, invest, tax, credit }

class GlossaryEntry {
  final String term;
  final String definition;
  final String? example;
  final GlossaryGroup group;

  const GlossaryEntry({
    required this.term,
    required this.definition,
    this.example,
    required this.group,
  });
}

const glossary = <GlossaryEntry>[
  // Personal finance
  GlossaryEntry(
    term: 'Актив', group: GlossaryGroup.personal,
    definition: 'То, что приносит деньги или растёт в стоимости: счёт, депозит, акции, доходная недвижимость.',
    example: 'Депозит на 10 000 BYN под 10% \u2014 актив, потому что приносит проценты.',
  ),
  GlossaryEntry(
    term: 'Пассив', group: GlossaryGroup.personal,
    definition: 'То, что забирает деньги: кредиты, рассрочки, вещи, требующие обслуживания.',
    example: 'Кредит на машину \u2014 пассив: каждый месяц вы за него платите.',
  ),
  GlossaryEntry(
    term: 'Чистая стоимость (Net Worth)', group: GlossaryGroup.personal,
    definition: 'Активы минус пассивы. Главный показатель финансового здоровья.',
    example: 'Если у вас 30 000 BYN на счетах и кредит 12 000 BYN, чистая стоимость = 18 000 BYN.',
  ),
  GlossaryEntry(
    term: 'Подушка безопасности', group: GlossaryGroup.personal,
    definition: 'Запас денег на 3\u201312 месяцев расходов на отдельном счёте \u00ABне трогать\u00BB. Спасает от форс-мажоров.',
    example: 'При расходах 1500 BYN/мес базовая подушка \u2014 9000 BYN (6 месяцев).',
  ),
  GlossaryEntry(
    term: 'Правило 50/30/20', group: GlossaryGroup.personal,
    definition: 'Делите доход на 50% потребностей, 30% желаний, 20% накоплений и долгов. Хорошая стартовая разбивка.',
  ),
  GlossaryEntry(
    term: 'Личная инфляция', group: GlossaryGroup.personal,
    definition: 'Рост цен именно на ваш набор товаров \u2014 почти всегда отличается от официальной инфляции Белстата.',
  ),

  // Belarus
  GlossaryEntry(
    term: 'НБРБ', group: GlossaryGroup.belarus,
    definition: 'Национальный банк Республики Беларусь. Устанавливает курсы валют и ставку рефинансирования.',
  ),
  GlossaryEntry(
    term: 'Ставка рефинансирования', group: GlossaryGroup.belarus,
    definition: 'Базовая ставка НБРБ. От неё \u00ABотталкиваются\u00BB процентные ставки по кредитам и депозитам.',
  ),
  GlossaryEntry(
    term: 'ЕРИП', group: GlossaryGroup.belarus,
    definition: 'Единое расчётное и информационное пространство. Платежи за коммуналку, связь, налоги, образование.',
  ),
  GlossaryEntry(
    term: 'Гарантийный фонд', group: GlossaryGroup.belarus,
    definition: 'Государство гарантирует возврат вкладов физлиц в любой валюте в случае проблем у банка (закон \u2116369-З).',
  ),
  GlossaryEntry(
    term: 'Базовая величина', group: GlossaryGroup.belarus,
    definition: 'Условная единица для штрафов, госпошлин, льгот. Меняется постановлением Совмина.',
  ),
  GlossaryEntry(
    term: 'Карта рассрочки', group: GlossaryGroup.belarus,
    definition: 'Карта, по которой можно купить что-то и заплатить частями без процентов в магазинах-партнёрах. Самые популярные: Халва (МТБанк), Магнит (Беларусбанк), Карта покупок (Белгазпромбанк).',
  ),

  // Investments
  GlossaryEntry(
    term: 'Диверсификация', group: GlossaryGroup.invest,
    definition: 'Распределение денег между разными активами и валютами, чтобы один провал не утопил весь капитал.',
  ),
  GlossaryEntry(
    term: 'Сложный процент', group: GlossaryGroup.invest,
    definition: 'Когда проценты начисляются и на основной капитал, и на ранее накопленные проценты. Эффект экспоненциального роста.',
  ),
  GlossaryEntry(
    term: 'FIRE', group: GlossaryGroup.invest,
    definition: 'Financial Independence, Retire Early \u2014 стратегия накопить капитал, доход с которого покрывает все расходы.',
  ),
  GlossaryEntry(
    term: 'Правило 4%', group: GlossaryGroup.invest,
    definition: 'Если снимать \u2264 4% от инвестиционного портфеля в год, он с большой вероятностью продержится 30+ лет.',
  ),

  // Tax
  GlossaryEntry(
    term: 'Подоходный налог (РБ)', group: GlossaryGroup.tax,
    definition: 'Стандартная ставка для физлиц \u2014 13%. Применяется к зарплате, аренде, процентам по краткосрочным вкладам.',
  ),
  GlossaryEntry(
    term: 'ФСЗН', group: GlossaryGroup.tax,
    definition: 'Фонд социальной защиты населения. С работника удерживается 1% зарплаты, остальное платит работодатель.',
  ),
  GlossaryEntry(
    term: 'УСН (ИП)', group: GlossaryGroup.tax,
    definition: 'Упрощённая система налогообложения: 5% с выручки без НДС или 3% с НДС. Подходит большинству ИП.',
  ),
  GlossaryEntry(
    term: 'НПД', group: GlossaryGroup.tax,
    definition: 'Налог на профессиональный доход для самозанятых: 10% при работе с физлицами/иностранными организациями, 20% \u2014 при превышении 60 000 BYN/год.',
  ),

  // Credit
  GlossaryEntry(
    term: 'Аннуитетный платёж', group: GlossaryGroup.credit,
    definition: 'Одинаковый платёж каждый месяц. Сначала больше идёт на проценты, потом \u2014 на тело. Удобно планировать.',
  ),
  GlossaryEntry(
    term: 'Дифференцированный платёж', group: GlossaryGroup.credit,
    definition: 'Платёж уменьшается со временем, переплата меньше, но первые месяцы тяжелее.',
  ),
  GlossaryEntry(
    term: 'Эффективная ставка', group: GlossaryGroup.credit,
    definition: 'Реальная стоимость кредита с учётом всех комиссий, страховок и графика \u2014 обычно выше \u00ABноминальной\u00BB в рекламе.',
  ),
  GlossaryEntry(
    term: 'Snowball', group: GlossaryGroup.credit,
    definition: 'Стратегия закрытия долгов: сначала самый маленький \u2014 для мотивации. Эмоционально приятно.',
  ),
  GlossaryEntry(
    term: 'Avalanche', group: GlossaryGroup.credit,
    definition: 'Стратегия закрытия долгов: сначала самый дорогой по проценту \u2014 экономнее по деньгам.',
  ),
];
