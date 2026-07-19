import 'package:flutter_test/flutter_test.dart';
import 'package:vibesight_tracker/models/enums.dart';
import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/services/payment_reminders.dart';
import 'package:vibesight_tracker/services/recurring.dart';

RegularPayment rule({
  String id = 'r1',
  num amount = 15,
  int dueDate = 1,
  RecurringFrequency frequency = RecurringFrequency.monthly,
  int? weekday,
  int? month,
  String? anchorDate,
  bool isActive = true,
  bool autoConfirm = false,
}) =>
    RegularPayment(
      id: id,
      name: 'Netflix',
      amount: amount,
      category: 'Подписки',
      isActive: isActive,
      type: TransactionType.expense,
      dueDate: dueDate,
      frequency: frequency,
      weekday: weekday,
      month: month,
      anchorDate: anchorDate,
      autoConfirm: autoConfirm,
    );

Loan loan({
  String id = 'l1',
  num balance = 8000,
  num monthlyPayment = 500,
  int? paymentDay = 10,
}) =>
    Loan(
      id: id,
      title: 'Авто',
      principal: 10000,
      balance: balance,
      annualRate: 10,
      monthlyPayment: monthlyPayment,
      startDate: '2026-01-01',
      currency: 'BYN',
      paymentDay: paymentDay,
    );

void main() {
  group('nextDueOccurrence', () {
    test('monthly returns this month when due day ahead', () {
      final occ = nextDueOccurrence(
          rule(frequency: RecurringFrequency.monthly, dueDate: 20),
          '2026-06-10');
      expect(occ!.dateISO, '2026-06-20');
    });

    test('monthly rolls to next month when due day passed', () {
      final occ = nextDueOccurrence(
          rule(frequency: RecurringFrequency.monthly, dueDate: 5),
          '2026-06-10');
      expect(occ!.dateISO, '2026-07-05');
    });

    test('weekly returns next matching weekday', () {
      // 2026-06-26 Friday (Dart weekday 5 → JS 5). Next Monday (1) = 06-29.
      final occ = nextDueOccurrence(
          rule(frequency: RecurringFrequency.weekly, weekday: 1),
          '2026-06-26');
      expect(occ!.dateISO, '2026-06-29');
    });

    test('yearly rolls into next year when month passed', () {
      final occ = nextDueOccurrence(
          rule(frequency: RecurringFrequency.yearly, month: 1, dueDate: 15),
          '2026-06-26');
      expect(occ!.dateISO, '2027-01-15');
    });

    test('biweekly lands on next cadence from anchor', () {
      final occ = nextDueOccurrence(
          rule(frequency: RecurringFrequency.biweekly, anchorDate: '2026-06-01'),
          '2026-06-10');
      expect(occ!.dateISO, '2026-06-15');
    });
  });

  group('getUpcomingReminders', () {
    const today = '2026-06-26';

    test('includes a recurring rule due within window', () {
      final out = getUpcomingReminders([rule(dueDate: 30)], [], today);
      expect(out, hasLength(1));
      expect(out.first.id, 'recurring:r1:2026-06');
      expect(out.first.daysUntil, 4);
    });

    test('excludes rules due beyond window', () {
      final out = getUpcomingReminders([rule(dueDate: 20)], [], today);
      expect(out, isEmpty);
    });

    test('excludes autoConfirm rules', () {
      final out =
          getUpcomingReminders([rule(dueDate: 30, autoConfirm: true)], [], today);
      expect(out, isEmpty);
    });

    test('excludes inactive rules', () {
      final out =
          getUpcomingReminders([rule(dueDate: 30, isActive: false)], [], today);
      expect(out, isEmpty);
    });

    test('includes a loan instalment due within window', () {
      final out = getUpcomingReminders([], [loan(paymentDay: 28)], today);
      expect(out, hasLength(1));
      expect(out.first.kind, ReminderKind.loan);
      expect(out.first.dueISO, '2026-06-28');
    });

    test('excludes repaid loans (balance <= 0)', () {
      final out =
          getUpcomingReminders([], [loan(balance: 0, paymentDay: 28)], today);
      expect(out, isEmpty);
    });

    test('sorts soonest-first across sources', () {
      final out = getUpcomingReminders(
        [rule(id: 'late', dueDate: 30)],
        [loan(id: 'early', paymentDay: 27)],
        today,
      );
      expect(out.map((r) => r.sourceId).toList(), ['early', 'late']);
    });
  });
}
