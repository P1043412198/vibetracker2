/**
 * Formatting helpers tuned for Belarus locale (ru-BY style):
 *  - currency: "1 234,56 Br" with non-breaking thin spaces
 *  - dates:    dd.MM.yyyy, week starts on Monday
 *  - phone:    +375 XX XXX-XX-XX
 *
 * All helpers are pure and locale-agnostic where possible so they
 * can be reused for non-BYN currencies without surprises.
 */
import type { Currency } from '../types';

const CURRENCY_SYMBOLS: Record<string, string> = {
  BYN: 'Br',
  USD: '$',
  EUR: '€',
  RUB: '₽',
  PLN: 'zł',
  USDT: 'USDT',
};

const NBSP = '\u00A0';

/**
 * Format amount as Belarusian-style number: "1 234 567,89".
 * Uses non-breaking spaces as thousands separator and a comma as the
 * decimal separator. Always emits at most `fractionDigits` (default 2).
 */
export function formatNumberBY(value: number, fractionDigits = 2): string {
  if (!Number.isFinite(value)) return '—';
  const rounded =
    Math.round(value * 10 ** fractionDigits) / 10 ** fractionDigits;
  const [intPart, fracPart = ''] = Math.abs(rounded).toString().split('.');
  const intWithSeparators = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, NBSP);
  const sign = rounded < 0 ? '−' : '';
  if (fractionDigits === 0) return sign + intWithSeparators;
  const padded = fracPart.padEnd(fractionDigits, '0').slice(0, fractionDigits);
  return `${sign}${intWithSeparators},${padded}`;
}

export function formatCurrency(
  value: number,
  currency: Currency = 'BYN',
  fractionDigits = 2
): string {
  const symbol = CURRENCY_SYMBOLS[currency] ?? currency;
  return `${formatNumberBY(value, fractionDigits)}${NBSP}${symbol}`;
}

export function formatPercent(value: number, fractionDigits = 1): string {
  return `${formatNumberBY(value, fractionDigits)}${NBSP}%`;
}

export function formatCompactBY(value: number): string {
  const abs = Math.abs(value);
  if (abs >= 1_000_000)
    return `${formatNumberBY(value / 1_000_000, 1)}${NBSP}млн`;
  if (abs >= 1_000) return `${formatNumberBY(value / 1_000, 1)}${NBSP}тыс.`;
  return formatNumberBY(value, 0);
}

/** Format a Date or ISO date as dd.MM.yyyy. */
export function formatDateBY(value: Date | string): string {
  const d = typeof value === 'string' ? new Date(value) : value;
  if (Number.isNaN(d.getTime())) return '—';
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const yyyy = d.getFullYear();
  return `${dd}.${mm}.${yyyy}`;
}

export function formatMonthBY(value: Date | string): string {
  const d = typeof value === 'string' ? new Date(value) : value;
  if (Number.isNaN(d.getTime())) return '—';
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  return `${mm}.${d.getFullYear()}`;
}

/**
 * Format a Belarusian phone number into +375 XX XXX-XX-XX.
 * Accepts any string with digits — non-digits are stripped.
 * Falls back to the original string when the digit count is wrong.
 */
export function formatPhoneBY(raw: string): string {
  const digits = raw.replace(/\D+/g, '');
  // Accept "375XXXXXXXXX" or "80XXXXXXXXX" (legacy format).
  let core = digits;
  if (core.startsWith('80')) core = '375' + core.slice(2);
  if (!core.startsWith('375')) core = '375' + core;
  if (core.length !== 12) return raw;
  const [, op, p1, p2, p3] =
    /^375(\d{2})(\d{3})(\d{2})(\d{2})$/.exec(core) ?? [];
  if (!op) return raw;
  return `+375${NBSP}${op}${NBSP}${p1}-${p2}-${p3}`;
}
