import 'package:flutter_test/flutter_test.dart';
import 'package:vibesight_tracker/models/enums.dart';
import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/services/recurring.dart';

RegularPayment rule({
  String id = 'r1',
  TransactionType type = TransactionType.expense,
  num amount = 10,
  int dueDate = 1,
  RecurringFrequency frequency = RecurringFrequency.monthly,
  int? weekday,
  int? month,
  String? anchorDate,
  bool isActive = true,
}) =>
    RegularPayment(
      id: id,
      name: 'Test',
      amount: amount,
      category: 'Связь',
      isActive: isActive,
      type: type,
      dueDate: dueDate,
      frequency: frequency,
      weekday: weekday,
      month: month,
      anchorDate: anchorDate,
    );

Transaction txn(String ref) => Transaction(
      id: 't_$ref',
      type: TransactionType.expense,
      amount: 10,
      category: 'x',
      date: '2026-06-05',
      recurringRef: ref,
    );

void main() {
  group('lastDueOccurrence monthly', () {
    test('returns this month when due day passed', () {
      final occ = lastDueOccurrence(
          rule(frequency: RecurringFrequency.monthly, dueDate: 10),
          '2026-06-20');
      expect(occ!.dateISO, '2026-06-10');
      expect(occ.periodKey, '2026-06');
    });

    test('falls back to previous month when due day ahead', () {
      final occ = lastDueOccurrence(
          rule(frequency: RecurringFrequency.monthly, dueDate: 25),
          '2026-06-10');
      expect(occ!.dateISO, '2026-05-25');
      expect(occ.periodKey, '2026-05');
    });

    test('clamps day 31 to last day of short month', () {
      final occ = lastDueOccurrence(
          rule(frequency: RecurringFrequency.monthly, dueDate: 31),
          '2026-02-28');
      expect(occ!.dateISO, '2026-02-28');
    });
  });

  group('lastDueOccurrence weekly/biweekly/yearly', () {
    test('weekly returns most recent matching weekday', () {
      // 2026-06-26 is Friday (Dart weekday 5). Target Wednesday (JS 3).
      final occ = lastDueOccurrence(
          rule(frequency: RecurringFrequency.weekly, weekday: 3),
          '2026-06-26');
      expect(occ!.dateISO, '2026-06-24');
    });

    test('weekly returns today when weekday matches', () {
      final occ = lastDueOccurrence(
          rule(frequency: RecurringFrequency.weekly, weekday: 5),
          '2026-06-26');
      expect(occ!.dateISO, '2026-06-26');
    });

    test('biweekly lands on cadence from anchor', () {
      final occ = lastDueOccurrence(
          rule(frequency: RecurringFrequency.biweekly, anchorDate: '2026-06-01'),
          '2026-06-20');
      expect(occ!.dateISO, '2026-06-15');
    });

    test('biweekly returns null when anchor in future', () {
      final occ = lastDueOccurrence(
          rule(frequency: RecurringFrequency.biweekly, anchorDate: '2026-07-01'),
          '2026-06-20');
      expect(occ, isNull);
    });

    test('yearly falls back across year boundary', () {
      final occ = lastDueOccurrence(
          rule(frequency: RecurringFrequency.yearly, month: 12, dueDate: 31),
          '2026-06-26');
      expect(occ!.dateISO, '2025-12-31');
      expect(occ.periodKey, '2025');
    });
  });

  group('getDueRecurring', () {
    const today = '2026-06-26';

    test('surfaces active due unposted unskipped rule', () {
      final due = getDueRecurring(
          [rule(id: 'rent', dueDate: 5)], [], [], today);
      expect(due, hasLength(1));
      expect(due.first.ref, refFor('rent', '2026-06'));
    });

    test('skips inactive rules', () {
      final due = getDueRecurring(
          [rule(id: 'rent', isActive: false)], [], [], today);
      expect(due, isEmpty);
    });

    test('excludes already-posted occurrences', () {
      final due = getDueRecurring(
          [rule(id: 'rent', dueDate: 5)],
          [txn(refFor('rent', '2026-06'))],
          [],
          today);
      expect(due, isEmpty);
    });

    test('excludes skipped occurrences', () {
      final due = getDueRecurring(
          [rule(id: 'rent', dueDate: 5)],
          [],
          [RecurringSkip(ruleId: 'rent', periodKey: '2026-06')],
          today);
      expect(due, isEmpty);
    });

    test('sorts by date ascending', () {
      final due = getDueRecurring([
        rule(id: 'late', dueDate: 20),
        rule(id: 'early', dueDate: 3),
      ], [], [], today);
      expect(due.map((d) => d.rule.id).toList(), ['early', 'late']);
    });
  });

  test('RegularPayment json round-trips new fields', () {
    final r = rule(
      type: TransactionType.income,
      frequency: RecurringFrequency.biweekly,
      anchorDate: '2026-01-01',
    ).copyWith(accountId: 'acc1', autoConfirm: true);
    final back = RegularPayment.fromJson(r.toJson());
    expect(back.type, TransactionType.income);
    expect(back.frequency, RecurringFrequency.biweekly);
    expect(back.anchorDate, '2026-01-01');
    expect(back.accountId, 'acc1');
    expect(back.autoConfirm, true);
  });
}
