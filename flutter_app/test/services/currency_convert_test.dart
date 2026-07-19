import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/state/currency_state.dart';
import 'package:vibesight_tracker/finance/by_tax.dart';

void main() {
  // USD-anchored rates: value of 1 unit of currency expressed in the anchor.
  const rates = <String, num>{'BYN': 1, 'USD': 3, 'EUR': 3.3};

  group('tryConvertCurrency (bug #2)', () {
    test('same currency returns the amount unchanged', () {
      final r = tryConvertCurrency(amount: 100, from: 'USD', to: 'USD', rates: rates);
      expect(r.ok, isTrue);
      expect(r.value, 100);
      expect(r.missing, isEmpty);
    });

    test('cross-converts using the anchored rates', () {
      final r = tryConvertCurrency(amount: 100, from: 'USD', to: 'BYN', rates: rates);
      expect(r.ok, isTrue);
      expect(r.value, closeTo(300, 1e-6)); // 100 * 3 / 1
    });

    test('flags a missing rate instead of faking a 1:1 cross-rate', () {
      final r = tryConvertCurrency(amount: 100, from: 'PLN', to: 'BYN', rates: rates);
      expect(r.ok, isFalse);
      expect(r.missing, ['PLN']);
      expect(r.value, 100); // unconverted fallback keeps the UI rendering
    });

    test('reports every missing code when both rates are absent', () {
      final r = tryConvertCurrency(amount: 100, from: 'PLN', to: 'CZK', rates: rates);
      expect(r.ok, isFalse);
      expect(r.missing, ['PLN', 'CZK']);
    });
  });

  group('convertCurrency (bug #2 wrapper)', () {
    test('returns converted value when rates are present', () {
      expect(
        convertCurrency(amount: 100, from: 'USD', to: 'BYN', rates: rates),
        closeTo(300, 1e-6),
      );
    });

    test('returns unconverted amount when a rate is missing', () {
      expect(
        convertCurrency(amount: 100, from: 'PLN', to: 'BYN', rates: rates),
        100,
      );
    });
  });

  group('getByTaxConstants year table (bug #3)', () {
    test('returns exact constants for a present year', () {
      expect(getByTaxConstants(2024), same(byTaxByYear[2024]));
    });

    test('legacy values reflect the current tax year', () {
      expect(baseValueByn, byTaxByYear[currentTaxYear]!.baseValueByn);
    });

    test('falls back to the latest year for a future, un-filled year', () {
      final latest = byTaxByYear.keys.reduce((a, b) => a > b ? a : b);
      expect(getByTaxConstants(2099), same(byTaxByYear[latest]));
    });

    test('falls back to the earliest year for a year below the table', () {
      final earliest = byTaxByYear.keys.reduce((a, b) => a < b ? a : b);
      expect(getByTaxConstants(1990), same(byTaxByYear[earliest]));
    });
  });
}
