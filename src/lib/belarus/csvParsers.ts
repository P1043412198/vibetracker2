/**
 * Простые парсеры CSV-выписок белорусских банков.
 *
 * Поддерживаемые форматы (упрощённо, эвристики):
 *  - Беларусбанк (M-Banking «История операций» CSV)
 *  - Приорбанк (Prior Online → CSV)
 *  - Альфа-Банк РБ (выгрузка из ЛК)
 *  - Универсальный CSV (Дата, Сумма, Описание)
 *
 * Возвращаем стандартизованный массив `ParsedTxn`, который вызывающий код
 * скармливает в `addTransaction()`. Сложные правила автокатегоризации
 * вынесены в отдельный шаг (`autoCategorize`).
 */

import type { TransactionType } from '../../types';

export interface ParsedTxn {
  /** ISO YYYY-MM-DD */
  date: string;
  amount: number;
  type: TransactionType;
  description: string;
  category?: string;
  rawCurrency?: string;
}

export interface ParseResult {
  bank: string;
  rows: ParsedTxn[];
  errors: string[];
}

/** Безопасное приведение «1 234,56» / «1234.56» / «-1 234,56» к числу. */
export function parseAmount(raw: string): number | null {
  if (!raw) return null;
  const cleaned = raw
    .replace(/\u00A0|\s/g, '')
    .replace(/^([+\-−])(.+)$/u, '$1$2')
    .replace(',', '.')
    .replace(/[^\d.\-]/g, '');
  if (!/\d/.test(cleaned)) return null;
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : null;
}

/** Дата может быть в формате dd.MM.yyyy либо yyyy-MM-dd либо dd/MM/yyyy. */
export function parseDate(raw: string): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  let m = /^(\d{2})\.(\d{2})\.(\d{4})/.exec(trimmed);
  if (m) return `${m[3]}-${m[2]}-${m[1]}`;
  m = /^(\d{4})-(\d{2})-(\d{2})/.exec(trimmed);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  m = /^(\d{2})\/(\d{2})\/(\d{4})/.exec(trimmed);
  if (m) return `${m[3]}-${m[2]}-${m[1]}`;
  return null;
}

/** Минимальный CSV-сплиттер с поддержкой кавычек. */
export function splitCsvRow(line: string, sep: string): string[] {
  const result: string[] = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      inQuotes = !inQuotes;
      continue;
    }
    if (ch === sep && !inQuotes) {
      result.push(cur);
      cur = '';
    } else {
      cur += ch;
    }
  }
  result.push(cur);
  return result.map((s) => s.trim());
}

function detectSeparator(line: string): string {
  const candidates = [';', '\t', ','];
  let bestSep = ',';
  let bestCount = 0;
  for (const c of candidates) {
    const cnt = line.split(c).length;
    if (cnt > bestCount) {
      bestSep = c;
      bestCount = cnt;
    }
  }
  return bestSep;
}

/** Найти индекс первой колонки, заголовок которой матчит regex. */
function colIndex(headers: string[], rx: RegExp): number {
  return headers.findIndex((h) => rx.test(h));
}

/** Универсальный парсер: ищет колонки «Дата», «Сумма», «Описание/Назначение». */
export function parseGenericCsv(text: string, bankLabel = 'Универсальный'): ParseResult {
  const errors: string[] = [];
  const lines = text.split(/\r?\n/).filter((l) => l.trim());
  if (lines.length === 0) return { bank: bankLabel, rows: [], errors: ['Пустой файл'] };

  const sep = detectSeparator(lines[0]);
  const headers = splitCsvRow(lines[0], sep).map((h) => h.replace(/^\uFEFF/, ''));
  const idxDate = colIndex(headers, /^(дата|date)/i);
  const idxAmount =
    colIndex(headers, /(сумма|amount|операция|сума)/i);
  const idxDesc = colIndex(headers, /(описание|назначение|description|операц)/i);
  const idxCurrency = colIndex(headers, /(валюта|currency)/i);

  if (idxDate < 0 || idxAmount < 0) {
    return {
      bank: bankLabel,
      rows: [],
      errors: ['Не нашёл колонки «Дата» и/или «Сумма»'],
    };
  }

  const rows: ParsedTxn[] = [];
  for (let i = 1; i < lines.length; i++) {
    const cells = splitCsvRow(lines[i], sep);
    const date = parseDate(cells[idxDate]);
    const amount = parseAmount(cells[idxAmount]);
    if (!date || amount === null) {
      errors.push(`Строка ${i + 1}: пропущена (не удалось разобрать дату/сумму)`);
      continue;
    }
    const description = idxDesc >= 0 ? cells[idxDesc] ?? '' : '';
    rows.push({
      date,
      amount: Math.abs(amount),
      type: amount < 0 ? 'expense' : 'income',
      description,
      rawCurrency: idxCurrency >= 0 ? cells[idxCurrency] : undefined,
    });
  }
  return { bank: bankLabel, rows, errors };
}

/** Беларусбанк (M-Banking): «Дата операции;Описание операции;Сумма в валюте счета;Валюта». */
export function parseBelarusbankCsv(text: string): ParseResult {
  return parseGenericCsv(text, 'Беларусбанк');
}

/** Приорбанк: «Date;Description;Amount;Currency». */
export function parsePriorbankCsv(text: string): ParseResult {
  return parseGenericCsv(text, 'Приорбанк');
}

/** Альфа-Банк РБ: «Дата операции;Дата проведения;Описание;Сумма;Валюта». */
export function parseAlfaBYCsv(text: string): ParseResult {
  return parseGenericCsv(text, 'Альфа-Банк (РБ)');
}

/** МТБанк (Халва): «Дата;Описание;Сумма; Тип». */
export function parseMtbankCsv(text: string): ParseResult {
  return parseGenericCsv(text, 'МТБанк');
}

/* ------------------------------------------------------------------ */
/*                Простая автокатегоризация по описанию                */
/* ------------------------------------------------------------------ */

const RULES: { test: RegExp; category: string }[] = [
  { test: /(евроопт|сосед(и)?|gippo|santa|санта|green|корона|виталюр|свет(офор)?|доброном)/i, category: 'Продукты' },
  { test: /(едоставк|edostavk|едо|перекрест)/i, category: 'Продукты' },
  { test: /(аптек|планета здоровья|apteka|tabletka)/i, category: 'Здоровье' },
  { test: /(минсктран|метропол|метро|трамвай|троллейбус)/i, category: 'Транспорт' },
  { test: /(белорусснефть|а-100|gazprom|газпромнефть|petrol)/i, category: 'Авто' },
  { test: /(yandex.taxi|maxim|onTaxi|takxi|такси|hello)/i, category: 'Транспорт' },
  { test: /(ozon|wildberries|kufar|21vek|oz\.by|aliexpress)/i, category: 'Покупки' },
  { test: /(жкх|gov|teplo|водоканал|belarusenergo|беларусьэнерго|gaz)/i, category: 'Коммуналка' },
  { test: /(mts|a1|life|beltelecom|cosmos)/i, category: 'Связь' },
  { test: /(restoran|pub|cafe|кофе|coffee|bistro|burger|ресторан)/i, category: 'Кафе' },
  { test: /(salary|зарпла|оклад|premium|премия)/i, category: 'Зарплата' },
];

export function autoCategorize(rows: ParsedTxn[]): ParsedTxn[] {
  return rows.map((r) => {
    if (r.category) return r;
    for (const rule of RULES) {
      if (rule.test.test(r.description)) {
        return { ...r, category: rule.category };
      }
    }
    return r;
  });
}
