/**
 * Справочник банков и карт рассрочки Беларуси. Используется в:
 *  - подсказках при создании счёта;
 *  - автоопределении банка при импорте CSV-выписки;
 *  - модуле «Депозиты РБ» для информационного сравнения ставок.
 */

export type BYBankKind = 'bank' | 'installment';

export interface BYBank {
  id: string;
  name: string;
  kind: BYBankKind;
  url?: string;
  /** Подсказки/имена для эвристического определения банка по содержимому CSV. */
  csvHints?: string[];
}

export const BY_BANKS: BYBank[] = [
  {
    id: 'belarusbank',
    name: 'Беларусбанк',
    kind: 'bank',
    url: 'https://belarusbank.by',
    csvHints: ['Беларусбанк', 'belarusbank', 'M-Banking'],
  },
  {
    id: 'priorbank',
    name: 'Приорбанк',
    kind: 'bank',
    url: 'https://priorbank.by',
    csvHints: ['Приорбанк', 'priorbank', 'Prior'],
  },
  {
    id: 'alfabank-by',
    name: 'Альфа-Банк (Беларусь)',
    kind: 'bank',
    url: 'https://alfabank.by',
    csvHints: ['Альфа-Банк', 'alfabank', 'Alfa-Bank'],
  },
  {
    id: 'bsb',
    name: 'БСБ Банк',
    kind: 'bank',
    url: 'https://bsb.by',
    csvHints: ['БСБ', 'bsb'],
  },
  {
    id: 'belagroprombank',
    name: 'Белагропромбанк',
    kind: 'bank',
    url: 'https://belapb.by',
    csvHints: ['Белагропромбанк', 'belapb'],
  },
  {
    id: 'belinvestbank',
    name: 'Белинвестбанк',
    kind: 'bank',
    url: 'https://belinvestbank.by',
    csvHints: ['Белинвестбанк', 'belinvestbank'],
  },
  {
    id: 'mtb',
    name: 'МТБанк',
    kind: 'bank',
    url: 'https://mtbank.by',
    csvHints: ['МТБанк', 'mtbank', 'Халва', 'Halva'],
  },
  {
    id: 'tehnobank',
    name: 'Технобанк',
    kind: 'bank',
    url: 'https://tb.by',
    csvHints: ['Технобанк', 'tb.by'],
  },
  {
    id: 'bnb',
    name: 'БНБ-Банк',
    kind: 'bank',
    url: 'https://bnb.by',
    csvHints: ['БНБ', 'bnb-bank'],
  },
  {
    id: 'belgazprombank',
    name: 'Белгазпромбанк',
    kind: 'bank',
    url: 'https://belgazprombank.by',
    csvHints: ['Белгазпромбанк', 'belgazprombank', 'Карта покупок'],
  },

  // Карты рассрочки
  {
    id: 'halva',
    name: 'Халва (МТБанк)',
    kind: 'installment',
    url: 'https://mtbank.by/personal/cards/halva',
  },
  {
    id: 'magnit',
    name: 'Магнит (Беларусбанк)',
    kind: 'installment',
    url: 'https://belarusbank.by',
  },
  {
    id: 'karta-pokupok',
    name: 'Карта покупок (Белгазпромбанк)',
    kind: 'installment',
    url: 'https://belgazprombank.by',
  },
];

/** Простая эвристика угадывания банка по тексту/заголовку CSV. */
export function detectBankFromCsv(text: string): BYBank | null {
  const lower = text.toLowerCase();
  for (const bank of BY_BANKS) {
    if (!bank.csvHints) continue;
    if (bank.csvHints.some((h) => lower.includes(h.toLowerCase()))) {
      return bank;
    }
  }
  return null;
}
