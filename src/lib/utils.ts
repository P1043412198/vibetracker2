import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export interface ConversionResult {
  /** Converted amount. Falls back to the unconverted amount when a rate is missing. */
  value: number;
  /** True when every rate needed for the conversion was available. */
  ok: boolean;
  /** Currency codes whose rate was missing (empty when ok). */
  missing: string[];
}

const warnedMissingRates = new Set<string>();

/**
 * Convert [amount] from one currency to another using USD/BYN-anchored rates,
 * reporting whether the conversion was actually possible.
 *
 * Unlike a bare lookup, this never silently fabricates a 1:1 cross-rate: when a
 * rate is missing the caller gets `ok: false` and the list of missing codes, so
 * the UI can flag totals as approximate instead of distorting net worth.
 */
export function tryConvertCurrency(
  amount: number,
  from: string,
  to: string,
  rates: Record<string, number>
): ConversionResult {
  if (from === to) return { value: amount, ok: true, missing: [] };

  const missing: string[] = [];
  const fromRate = rates[from];
  const toRate = rates[to];
  if (fromRate == null) missing.push(from);
  if (toRate == null) missing.push(to);

  if (missing.length > 0) {
    // Best-effort fallback keeps the UI rendering, but the result is flagged.
    return { value: amount, ok: false, missing };
  }

  return { value: (amount * fromRate) / toRate, ok: true, missing: [] };
}

export function convertCurrency(
  amount: number,
  from: string,
  to: string,
  rates: Record<string, number>
): number {
  const result = tryConvertCurrency(amount, from, to, rates);
  if (!result.ok) {
    const key = result.missing.join(',');
    if (!warnedMissingRates.has(key)) {
      warnedMissingRates.add(key);
      console.warn(
        `convertCurrency: missing FX rate(s) for ${key}; using unconverted amount. ` +
          'Totals may be inaccurate until rates load.'
      );
    }
  }
  return result.value;
}
