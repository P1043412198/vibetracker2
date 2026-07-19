import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { convertCurrency, tryConvertCurrency } from '../utils';

// USD-anchored rates: value of 1 unit of currency expressed in the anchor.
const rates = { BYN: 1, USD: 3, EUR: 3.3 };

describe('tryConvertCurrency', () => {
  it('returns the amount unchanged for same-currency conversion', () => {
    const r = tryConvertCurrency(100, 'USD', 'USD', rates);
    expect(r).toEqual({ value: 100, ok: true, missing: [] });
  });

  it('cross-converts using the anchored rates', () => {
    const r = tryConvertCurrency(100, 'USD', 'BYN', rates);
    expect(r.ok).toBe(true);
    expect(r.value).toBeCloseTo(300, 6); // 100 * 3 / 1
  });

  it('flags a missing source rate instead of faking a 1:1 cross-rate', () => {
    const r = tryConvertCurrency(100, 'PLN', 'BYN', rates);
    expect(r.ok).toBe(false);
    expect(r.missing).toEqual(['PLN']);
    // Falls back to the unconverted amount so the UI keeps rendering.
    expect(r.value).toBe(100);
  });

  it('reports every missing code when both rates are absent', () => {
    const r = tryConvertCurrency(100, 'PLN', 'CZK', rates);
    expect(r.ok).toBe(false);
    expect(r.missing).toEqual(['PLN', 'CZK']);
  });

  it('treats a zero rate as present (not missing)', () => {
    const r = tryConvertCurrency(100, 'USD', 'BYN', { ...rates, BYN: 0 });
    // 0 is a real (if degenerate) rate, not an absent one.
    expect(r.missing).toEqual([]);
  });
});

describe('convertCurrency', () => {
  let warn: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
  });
  afterEach(() => {
    warn.mockRestore();
  });

  it('returns the converted value when all rates are present', () => {
    expect(convertCurrency(100, 'USD', 'BYN', rates)).toBeCloseTo(300, 6);
    expect(warn).not.toHaveBeenCalled();
  });

  it('warns once for a missing rate and returns the unconverted amount', () => {
    // A unique missing code so the module-level warn-once cache does not hide it.
    expect(convertCurrency(100, 'ZWL', 'BYN', rates)).toBe(100);
    expect(convertCurrency(50, 'ZWL', 'BYN', rates)).toBe(50);
    expect(warn).toHaveBeenCalledTimes(1);
  });
});
