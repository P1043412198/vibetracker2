import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/finance/by_holidays.dart';

void main() {
  String radonitsa(int year) => getBYHolidays(year)
      .firstWhere((h) => h.name == 'Радаўніца')
      .date;

  group('Belarus Radonitsa (Orthodox Easter + 9 days)', () {
    // Known official Belarus Radonitsa dates.
    test('2024 → 2024-05-14', () => expect(radonitsa(2024), '2024-05-14'));
    test('2025 → 2025-04-29', () => expect(radonitsa(2025), '2025-04-29'));
    test('2026 → 2026-04-21', () => expect(radonitsa(2026), '2026-04-21'));
    test('2027 → 2027-05-11', () => expect(radonitsa(2027), '2027-05-11'));
  });

  test('fixed holidays are present', () {
    final hs = getBYHolidays(2025).map((h) => h.date).toList();
    expect(hs, contains('2025-01-01'));
    expect(hs, contains('2025-07-03'));
    expect(hs, contains('2025-12-25'));
  });
}
