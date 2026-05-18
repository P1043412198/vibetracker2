import { describe, expect, it } from 'vitest';
import {
  autoCategorize,
  parseAmount,
  parseBelarusbankCsv,
  parseDate,
  parseGenericCsv,
} from '../csvParsers';

describe('parseAmount', () => {
  it('handles thin spaces and comma decimal', () => {
    expect(parseAmount('1\u00A0234,56')).toBeCloseTo(1234.56, 2);
  });
  it('handles negative amounts', () => {
    expect(parseAmount('-25,00')).toBeCloseTo(-25, 2);
  });
  it('returns null for garbage', () => {
    expect(parseAmount('abc')).toBeNull();
  });
});

describe('parseDate', () => {
  it('parses dd.MM.yyyy', () => {
    expect(parseDate('15.04.2024')).toBe('2024-04-15');
  });
  it('parses yyyy-MM-dd', () => {
    expect(parseDate('2024-04-15')).toBe('2024-04-15');
  });
});

describe('parseGenericCsv', () => {
  it('parses a typical Belarusbank export', () => {
    const csv = [
      'Дата операции;Описание операции;Сумма в валюте счёта;Валюта',
      '15.04.2024;Евроопт МИНСК;-45,80;BYN',
      '16.04.2024;Зарплата;2500,00;BYN',
    ].join('\n');
    const r = parseBelarusbankCsv(csv);
    expect(r.errors).toEqual([]);
    expect(r.rows).toHaveLength(2);
    expect(r.rows[0]).toMatchObject({
      date: '2024-04-15',
      amount: 45.8,
      type: 'expense',
    });
    expect(r.rows[1]).toMatchObject({
      date: '2024-04-16',
      amount: 2500,
      type: 'income',
    });
  });

  it('reports an error when key columns are missing', () => {
    const csv = ['foo;bar;baz', 'a;b;c'].join('\n');
    const r = parseGenericCsv(csv);
    expect(r.errors.length).toBeGreaterThan(0);
    expect(r.rows).toHaveLength(0);
  });
});

describe('autoCategorize', () => {
  it('assigns Продукты for Евроопт', () => {
    const rows = autoCategorize([
      {
        date: '2024-01-01',
        amount: 50,
        type: 'expense',
        description: 'Евроопт #5',
      },
    ]);
    expect(rows[0].category).toBe('Продукты');
  });

  it('assigns Транспорт for Минсктранс', () => {
    const rows = autoCategorize([
      {
        date: '2024-01-01',
        amount: 1.2,
        type: 'expense',
        description: 'МИНСКТРАНСПРОЕЗД',
      },
    ]);
    expect(rows[0].category).toBe('Транспорт');
  });

  it('leaves unknown rows untouched', () => {
    const rows = autoCategorize([
      {
        date: '2024-01-01',
        amount: 10,
        type: 'expense',
        description: 'IKEA Riga',
      },
    ]);
    expect(rows[0].category).toBeUndefined();
  });
});
