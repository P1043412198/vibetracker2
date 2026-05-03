/**
 * Lightweight string dictionary. We are not pulling in `i18next` yet —
 * the app is currently mono-lingual (ru) and the goal is to (a) start
 * extracting hard-coded strings into one place, (b) be ready to flip the
 * locale once the dictionary is full.
 *
 * Usage:
 *   const t = useT();
 *   t('tools.title');             // "Инструменты"
 *   t('tools.title', { name: 'X' }); // simple {name} interpolation
 */
import { useStore } from '../store/useStore';

export type Locale = 'ru' | 'be' | 'en';

type Dict = Record<string, string>;

const ru: Dict = {
  'tools.title': 'Инструменты',
  'tools.subtitle': 'Калькуляторы и финансовая грамотность',
  'tools.tab.calculators': 'Калькуляторы',
  'tools.tab.glossary': 'Глоссарий',
  'tools.tab.courses': 'Мини-курсы',
  'tools.tab.templates': 'Шаблоны',
  'tools.calc.compound': 'Сложный процент',
  'tools.calc.deposit': 'Депозит (РБ)',
  'tools.calc.credit': 'Кредит',
  'tools.calc.early': 'Досрочное погашение',
  'tools.calc.salary': 'Зарплата на руки',
  'tools.calc.safety': 'Подушка безопасности',
  'tools.calc.stress': 'Валютный стресс-тест',
  'tools.calc.usn': 'ИП на УСН',
  'tools.calc.npd': 'НПД (самозанятые)',
  'tools.calc.vacation': 'Отпускные',
  'tools.calc.car': 'Авто vs каршеринг',
  'common.amount': 'Сумма',
  'common.currency': 'Валюта',
  'common.rate': 'Ставка',
  'common.term': 'Срок',
  'common.years': 'лет',
  'common.months': 'мес.',
  'common.result': 'Результат',
  'common.calculate': 'Рассчитать',
  'common.back': 'Назад',
  'common.add': 'Добавить',
  'common.cancel': 'Отмена',
  'common.save': 'Сохранить',
  'common.delete': 'Удалить',
  'common.edit': 'Изменить',
  'common.next': 'Далее',
  'common.done': 'Готово',
  'finance.netWorth': 'Чистая стоимость',
  'finance.byCurrency': 'По валютам',
  'finance.cashflow': 'Денежный поток',
  'finance.expensesCalendar': 'Календарь трат',
  'finance.flow': 'Доходы → Расходы',
  'finance.treemap': 'Карта расходов',
  'habits.yearHeatmap': 'Год активности',
  'habits.streakChains': 'Серии',
  'habits.habitClock': 'Время отметок',
  'habits.sphereRadar': 'По сферам',
  'tasks.velocity': 'Скорость',
  'tasks.burndown': 'Прогорание',
  'tasks.closeHeatmap': 'Часы закрытия',
  'goals.gantt': 'Календарь целей',
  'goals.burndown': 'Прогорание шагов',
  'goals.bookProgress': 'Прогресс по книге',
};

const be: Dict = {
  ...ru,
  'tools.title': 'Інструменты',
  'tools.subtitle': 'Калькулятары і фінансавая граматнасць',
  'tools.tab.calculators': 'Калькулятары',
  'tools.tab.glossary': 'Гласарый',
  'tools.tab.courses': 'Міні-курсы',
  'tools.tab.templates': 'Шаблоны',
  'common.amount': 'Сума',
  'common.currency': 'Валюта',
  'common.rate': 'Стаўка',
  'common.term': 'Тэрмін',
  'common.years': 'гадоў',
  'common.months': 'мес.',
  'common.calculate': 'Разлічыць',
  'common.back': 'Назад',
  'common.cancel': 'Адмена',
  'common.save': 'Захаваць',
};

const en: Dict = {
  ...ru,
  'tools.title': 'Tools',
  'tools.subtitle': 'Calculators and financial literacy',
  'tools.tab.calculators': 'Calculators',
  'tools.tab.glossary': 'Glossary',
  'tools.tab.courses': 'Mini-courses',
  'tools.tab.templates': 'Templates',
  'tools.calc.compound': 'Compound interest',
  'tools.calc.deposit': 'Deposit (Belarus)',
  'tools.calc.credit': 'Loan',
  'tools.calc.early': 'Early repayment',
  'tools.calc.salary': 'Net salary',
  'tools.calc.safety': 'Emergency fund',
  'tools.calc.stress': 'FX stress test',
  'tools.calc.usn': 'Self-employed (USN)',
  'tools.calc.npd': 'Professional income tax',
  'tools.calc.vacation': 'Vacation pay',
  'tools.calc.car': 'Car vs car-sharing',
  'common.amount': 'Amount',
  'common.currency': 'Currency',
  'common.rate': 'Rate',
  'common.term': 'Term',
  'common.years': 'years',
  'common.months': 'months',
  'common.result': 'Result',
  'common.calculate': 'Calculate',
  'common.back': 'Back',
  'common.add': 'Add',
  'common.cancel': 'Cancel',
  'common.save': 'Save',
  'common.delete': 'Delete',
  'common.edit': 'Edit',
  'common.next': 'Next',
  'common.done': 'Done',
};

const DICTS: Record<Locale, Dict> = { ru, be, en };

export function translate(
  locale: Locale,
  key: string,
  vars?: Record<string, string | number>
): string {
  const dict = DICTS[locale] ?? ru;
  let raw = dict[key] ?? ru[key] ?? key;
  if (vars) {
    for (const [k, v] of Object.entries(vars)) {
      raw = raw.replace(new RegExp(`\\{${k}\\}`, 'g'), String(v));
    }
  }
  return raw;
}

export function useT() {
  const locale = useStore((s) => s.locale ?? 'ru');
  return (key: string, vars?: Record<string, string | number>) =>
    translate(locale as Locale, key, vars);
}
