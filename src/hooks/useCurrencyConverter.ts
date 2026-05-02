import { useStore } from '../store/useStore';
import { convertCurrency } from '../lib/utils';

export function useCurrencyConverter() {
  const { rates = {} } = useStore();
  
  return (amount: number, from: string, to: string) => {
    return convertCurrency(amount, from, to, rates);
  };
}
