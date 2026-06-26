import 'package:flutter_test/flutter_test.dart';
import 'package:vibesight_tracker/models/budget_planner.dart';

BudgetPlanConfig _source(String monthKey) => BudgetPlanConfig(
      monthKey: monthKey,
      incomeSources: [
        IncomeSource.blank(
            name: 'Зарплата', type: IncomeSourceType.salary, amount: 1000, dayOfMonth: 15),
        IncomeSource.blank(
            name: 'Аванс', type: IncomeSourceType.advance, amount: 500, dayOfMonth: 30),
      ],
      plannedExpenses: [
        PlannedExpense.blank(name: 'Аренда', amount: 400, dayFrom: 1, dayTo: 5),
      ],
      actualExpenses: [
        ActualExpense.blank(name: 'Кофе', amount: 5, date: '2026-06-10'),
      ],
      linkedAccountIds: const ['acc-1'],
    );

void main() {
  group('BudgetPlanStore.copyForward (P2)', () {
    test('copies recurring income & expenses into N future months', () {
      final store = BudgetPlanStore(
        months: [_source('2026-06')],
        selectedMonthKey: '2026-06',
      );

      final result = store.copyForward('2026-06', 3);

      expect(result.copied, 3);
      expect(result.store.months.length, 4);
      for (final key in ['2026-07', '2026-08', '2026-09']) {
        final m = result.store.months.firstWhere((mm) => mm.monthKey == key);
        expect(m.incomeSources.length, 2);
        expect(m.plannedExpenses.length, 1);
        expect(m.plannedExpenses.first.amount, 400);
        // Fresh month carries no facts and starts unpaid.
        expect(m.actualExpenses, isEmpty);
        expect(m.plannedExpenses.first.isPaid, false);
      }
    });

    test('assigns fresh ids so months are independent for overrides', () {
      final store = BudgetPlanStore(
        months: [_source('2026-06')],
        selectedMonthKey: '2026-06',
      );
      final result = store.copyForward('2026-06', 1);
      final src = store.months.first;
      final dst = result.store.months.firstWhere((m) => m.monthKey == '2026-07');
      expect(dst.incomeSources.first.id, isNot(src.incomeSources.first.id));
      expect(dst.plannedExpenses.first.id, isNot(src.plannedExpenses.first.id));
    });

    test('skips months that already have a plan when overwrite is false', () {
      final existing = BudgetPlanConfig(
        monthKey: '2026-07',
        incomeSources: [
          IncomeSource.blank(
              name: 'Своё', type: IncomeSourceType.additional, amount: 99),
        ],
        plannedExpenses: [],
        actualExpenses: [
          ActualExpense.blank(name: 'Факт', amount: 12, date: '2026-07-03'),
        ],
      );
      final store = BudgetPlanStore(
        months: [_source('2026-06'), existing],
        selectedMonthKey: '2026-06',
      );

      final result = store.copyForward('2026-06', 2);

      // 2026-07 preserved (override kept), 2026-08 newly created.
      expect(result.copied, 1);
      final july = result.store.months.firstWhere((m) => m.monthKey == '2026-07');
      expect(july.incomeSources.single.name, 'Своё');
      expect(july.actualExpenses.single.name, 'Факт');
      expect(
        result.store.months.any((m) => m.monthKey == '2026-08'),
        isTrue,
      );
    });

    test('overwrite replaces plan but preserves facts & account links', () {
      final existing = BudgetPlanConfig(
        monthKey: '2026-07',
        incomeSources: [
          IncomeSource.blank(
              name: 'Старое', type: IncomeSourceType.additional, amount: 1),
        ],
        plannedExpenses: [],
        actualExpenses: [
          ActualExpense.blank(name: 'Факт', amount: 12, date: '2026-07-03'),
        ],
        linkedAccountIds: const ['acc-9'],
      );
      final store = BudgetPlanStore(
        months: [_source('2026-06'), existing],
        selectedMonthKey: '2026-06',
      );

      final result = store.copyForward('2026-06', 1, overwrite: true);

      expect(result.copied, 1);
      final july = result.store.months.firstWhere((m) => m.monthKey == '2026-07');
      // Plan replaced with the source's recurring items…
      expect(july.incomeSources.length, 2);
      expect(july.plannedExpenses.single.name, 'Аренда');
      // …but real facts and account links survive.
      expect(july.actualExpenses.single.name, 'Факт');
      expect(july.linkedAccountIds, ['acc-9']);
    });

    test('rolls over the year boundary', () {
      final store = BudgetPlanStore(
        months: [_source('2026-11')],
        selectedMonthKey: '2026-11',
      );
      final result = store.copyForward('2026-11', 3);
      expect(
        result.store.months.map((m) => m.monthKey),
        containsAll(['2026-12', '2027-01', '2027-02']),
      );
    });

    test('count < 1 is a no-op', () {
      final store = BudgetPlanStore(
        months: [_source('2026-06')],
        selectedMonthKey: '2026-06',
      );
      final result = store.copyForward('2026-06', 0);
      expect(result.copied, 0);
      expect(result.store.months.length, 1);
    });
  });
}
