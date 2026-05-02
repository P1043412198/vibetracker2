/**
 * Государственные и общереспубликанские праздничные дни Беларуси.
 *
 * Источник: ст. 72 ТК Республики Беларусь, постановления Совмина
 * о переносе рабочих дней публикуются ежегодно. Здесь — статический
 * фоллбэк; для актуальных переносов оставляем хук — `holidayOverrides`.
 */

export interface BYHoliday {
  /** ISO date (YYYY-MM-DD) */
  date: string;
  name: string;
  /** Переход с рабочего на выходной (1) или наоборот (-1). */
  shift?: 1 | -1;
}

const FIXED = [
  { md: '01-01', name: 'Новы год' },
  { md: '01-02', name: 'Працяг навагодніх' },
  { md: '01-07', name: 'Раство Хрыстова (праваслаўнае)' },
  { md: '03-08', name: 'Дзень жанчын' },
  { md: '05-01', name: 'Свята працы' },
  { md: '05-09', name: 'Дзень Перамогі' },
  { md: '07-03', name: 'Дзень Незалежнасці РБ' },
  { md: '11-07', name: 'Дзень Кастрычніцкай рэвалюцыі' },
  { md: '12-25', name: 'Раство Хрыстова (каталіцкае)' },
];

/**
 * Расчёт православной Пасхи (упрощённый алгоритм Гаусса) — используется
 * для вычисления Радуницы (вторник после Фоминой недели = Пасха + 9 дней).
 */
function orthodoxEaster(year: number): Date {
  const a = year % 19;
  const b = year % 4;
  const c = year % 7;
  const k = Math.floor(year / 100);
  const p = Math.floor((13 + 8 * k) / 25);
  const q = Math.floor(k / 4);
  const M = (15 - p + k - q) % 30;
  const N = (4 + k - q) % 7;
  const d = (19 * a + M) % 30;
  const e = (2 * b + 4 * c + 6 * d + N) % 7;
  // Юлианская дата
  const julianDay = 22 + d + e;
  const julian =
    julianDay <= 31
      ? new Date(Date.UTC(year, 2, julianDay))
      : new Date(Date.UTC(year, 3, julianDay - 31));
  // Перевод юлианского дня в григорианский: + (julian to gregorian offset)
  const offsetDays = Math.floor(year / 100) - Math.floor(year / 400) - 2;
  julian.setUTCDate(julian.getUTCDate() + offsetDays);
  return julian;
}

function pad(n: number) {
  return String(n).padStart(2, '0');
}

function toIso(d: Date): string {
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

export function getBYHolidays(year: number): BYHoliday[] {
  const list: BYHoliday[] = FIXED.map((h) => ({
    date: `${year}-${h.md}`,
    name: h.name,
  }));
  // Радуница — официальный нерабочий день в РБ.
  const easter = orthodoxEaster(year);
  const radonitsa = new Date(easter);
  radonitsa.setUTCDate(easter.getUTCDate() + 9);
  list.push({
    date: toIso(radonitsa),
    name: 'Радаўніца',
  });
  return list.sort((a, b) => a.date.localeCompare(b.date));
}

export function isBYHoliday(iso: string): BYHoliday | null {
  const year = Number(iso.slice(0, 4));
  if (!Number.isFinite(year)) return null;
  return getBYHolidays(year).find((h) => h.date === iso) ?? null;
}
