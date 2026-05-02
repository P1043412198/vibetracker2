import { useCallback } from 'react';
import { useStore } from '../store/useStore';
import { convertCurrency } from '../lib/utils';

export function useCurrencyConverter() {
  const rates = useStore(s => s.rates) ?? {};

  return useCallback(
    (amount: number, from: string, to: string) =>
      convertCurrency(amount, from, to, rates),
    [rates],
  );
}
