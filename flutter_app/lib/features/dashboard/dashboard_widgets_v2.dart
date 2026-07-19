import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/budget_planner.dart';
import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../models/goal.dart';
import '../../models/habit.dart';
import '../../models/misc.dart';
import '../../services/budget_planner_calc.dart';
import '../../services/finance_calc.dart';
import '../finance/payment_reminders_card.dart';
import '../../state/budget_planner_state.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

/// Phase 14 dashboard analytics widgets — pies, bars, lines, progress bars.
/// Kept in a separate file from `dashboard_charts.dart` so the original
/// lightweight charts continue to compile if `fl_chart` ever changes API.

const _palette = <Color>[
  Color(0xFF6D5CFF),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFF8B5CF6),
  Color(0xFFF97316),
  Color(0xFF06B6D4),
];

/// =============================================================
/// Inbox dashboard widget — quick capture without leaving home.
/// =============================================================
class InboxDashboardWidget extends ConsumerStatefulWidget {
  const InboxDashboardWidget({super.key});

  @override
  ConsumerState<InboxDashboardWidget> createState() =>
      _InboxDashboardWidgetState();
}

class _InboxDashboardWidgetState extends ConsumerState<InboxDashboardWidget> {
  final TextEditingController _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    final item = InboxItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: text,
      createdAt: DateTime.now().toIso8601String(),
    );
    await ref.read(inboxProvider.notifier).add(item);
    _ctl.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = ref.watch(inboxProvider);
    final recent = items.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inbox_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Входящие',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (items.isNotEmpty)
                  Text('${items.length}',
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700)),
                IconButton(
                  tooltip: 'Открыть инбокс',
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => context.go('/inbox'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(
                      hintText: 'Захвати мысль или дело…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _add,
                  icon: const Icon(Icons.send, size: 18),
                ),
              ],
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final r in recent)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: scheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// =============================================================
/// Habits overview — pie (good vs bad), weekday bar, top streak rows.
/// =============================================================
class HabitsOverviewWidget extends ConsumerWidget {
  const HabitsOverviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final logs = ref.watch(habitLogsProvider);
    final scheme = Theme.of(context).colorScheme;
    final goodCount =
        habits.where((h) => h.type == HabitTypeKind.good).length;
    final badCount =
        habits.where((h) => h.type == HabitTypeKind.bad).length;
    // Week-day completion histogram for last 28 days.
    final byDow = List<int>.filled(7, 0);
    final today = DateTime.now();
    final cutoff = today.subtract(const Duration(days: 28));
    for (final l in logs) {
      if (l.status != HabitLogStatus.done) continue;
      final dt = DateTime.tryParse(l.date);
      if (dt == null || dt.isBefore(cutoff)) continue;
      byDow[dt.weekday - 1] += 1;
    }
    final maxDow = math.max(1, byDow.reduce(math.max));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.donut_large_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Привычки: обзор',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  tooltip: 'К списку привычек',
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  onPressed: () => context.go('/habits'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: (goodCount + badCount) == 0
                      ? Center(
                          child: Text('Нет привычек',
                              style: Theme.of(context).textTheme.bodySmall))
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 26,
                            sections: [
                              if (goodCount > 0)
                                PieChartSectionData(
                                  value: goodCount.toDouble(),
                                  color: const Color(0xFF22C55E),
                                  title: '$goodCount',
                                  radius: 28,
                                  titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12),
                                ),
                              if (badCount > 0)
                                PieChartSectionData(
                                  value: badCount.toDouble(),
                                  color: const Color(0xFFEF4444),
                                  title: '$badCount',
                                  radius: 28,
                                  titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _legendDot(
                          color: const Color(0xFF22C55E),
                          label: 'Хорошие',
                          value: goodCount),
                      const SizedBox(height: 4),
                      _legendDot(
                          color: const Color(0xFFEF4444),
                          label: 'Вредные',
                          value: badCount),
                      const SizedBox(height: 8),
                      Text('Выполнено по дням недели (28д)',
                          style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 36,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < 7; i++) ...[
                              Expanded(
                                child: Tooltip(
                                  message:
                                      '${_dowName(i)}: ${byDow[i]}',
                                  child: Container(
                                    height: 4 + 28 * (byDow[i] / maxDow),
                                    decoration: BoxDecoration(
                                      color: scheme.primary
                                          .withValues(alpha: 0.5 +
                                              0.5 * byDow[i] / maxDow),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                              if (i != 6) const SizedBox(width: 3),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (var i = 0; i < 7; i++) ...[
                            Expanded(
                              child: Text(
                                _dowName(i),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(
      {required Color color, required String label, required int value}) {
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label),
      const Spacer(),
      Text('$value',
          style: const TextStyle(fontWeight: FontWeight.w700)),
    ]);
  }

  String _dowName(int dow) =>
      const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][dow];
}

/// =============================================================
/// Goals overview — pie (status), bar (progress per goal), avg progress
/// =============================================================
class GoalsOverviewWidget extends ConsumerWidget {
  const GoalsOverviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final scheme = Theme.of(context).colorScheme;
    final byStatus = <GoalStatus, int>{};
    for (final g in goals) {
      byStatus[g.status] = (byStatus[g.status] ?? 0) + 1;
    }
    final progresses = goals.map(_goalProgress).toList(growable: false);
    final avg = progresses.isEmpty
        ? 0.0
        : progresses.reduce((a, b) => a + b) / progresses.length;
    final topGoals = [...goals]
      ..sort((a, b) => _goalProgress(b).compareTo(_goalProgress(a)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_outline, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Цели: статусы',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text('${(avg * 100).round()}%',
                    style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700)),
                IconButton(
                  tooltip: 'К целям',
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  onPressed: () => context.go('/goals'),
                ),
              ],
            ),
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Поставь первую цель',
                    style: Theme.of(context).textTheme.bodySmall),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 26,
                        sections: [
                          for (final entry in byStatus.entries)
                            PieChartSectionData(
                              value: entry.value.toDouble(),
                              color: _statusColor(entry.key),
                              title: '${entry.value}',
                              radius: 28,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in byStatus.entries)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: _statusColor(entry.key),
                                      borderRadius:
                                          BorderRadius.circular(3))),
                              const SizedBox(width: 6),
                              Text(_statusLabel(entry.key)),
                              const Spacer(),
                              Text('${entry.value}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            if (goals.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Топ-3 по прогрессу',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              for (final g in topGoals.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(g.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('${(_goalProgress(g) * 100).round()}%',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _goalProgress(g),
                          minHeight: 6,
                          color: _statusColor(g.status),
                          backgroundColor:
                              scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(GoalStatus s) {
    switch (s) {
      case GoalStatus.completed:
        return const Color(0xFF22C55E);
      case GoalStatus.in_progress:
        return const Color(0xFF3B82F6);
      case GoalStatus.not_started:
        return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(GoalStatus s) {
    switch (s) {
      case GoalStatus.completed:
        return 'Готово';
      case GoalStatus.in_progress:
        return 'В работе';
      case GoalStatus.not_started:
        return 'Не начато';
    }
  }
}

double _goalProgress(Goal goal) {
  if (goal.type == GoalType.book && (goal.totalPages ?? 0) > 0) {
    return ((goal.readPages ?? 0) / (goal.totalPages!)).clamp(0.0, 1.0);
  }
  if ((goal.targetValue ?? 0) > 0) {
    return ((goal.currentValue ?? 0) / (goal.targetValue!))
        .toDouble()
        .clamp(0.0, 1.0);
  }
  if (goal.progress != null) {
    return (goal.progress! / 100).clamp(0.0, 1.0);
  }
  if (goal.steps.isNotEmpty) {
    final done = goal.steps.where((s) => s.completed).length;
    return done / goal.steps.length;
  }
  return 0.0;
}

/// =============================================================
/// Finance free funds — daily allowance with loans factored in.
/// =============================================================
class FinanceFreeFundsWidget extends ConsumerWidget {
  const FinanceFreeFundsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final plans = ref.watch(monthlyBudgetPlansProvider);
    final loans = ref.watch(loansProvider);
    final currency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);
    final today = DateTime.now();
    final monthKey =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}';
    final plan = plans.firstWhere(
      (p) => p.monthKey == monthKey,
      orElse: () => MonthlyBudgetPlan(
        id: 'placeholder',
        monthKey: monthKey,
        plannedIncome: 0,
        categoryPlans: const [],
        createdAt: today.toIso8601String(),
        updatedAt: today.toIso8601String(),
      ),
    );

    num convert(num amount, String from, String to) {
      return convertCurrency(
          amount: amount, from: from, to: to, rates: rates);
    }

    final cashflow = buildCashflow(
      month: today,
      plan: plan,
      loans: loans,
      planCurrency: plan.currency ?? currency,
      convert: convert,
    );
    final period = cashflow.periods
            .firstWhere((p) =>
                today.day >= p.startDay && today.day <= p.endDay,
                orElse: () => cashflow.periods.isNotEmpty
                    ? cashflow.periods.first
                    : CashflowPeriod(
                        startDay: 1,
                        endDay: 1,
                        startBalance: 0,
                        endBalance: 0,
                        daysInclusive: 1,
                        dailyAllowance: 0,
                        label: '—',
                      ));
    final loanBurden = monthlyLoanBurden(
      loans: loans,
      currency: plan.currency ?? currency,
      convert: convert,
    );
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: '', decimalDigits: 0);
    final cur = plan.currency ?? currency;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.savings_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Свободно в день',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                tooltip: 'К плану месяца',
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: () => context.go('/finance'),
              ),
            ]),
            const SizedBox(height: 6),
            if (plan.id == 'placeholder' &&
                plan.plannedIncome == 0 &&
                plan.categoryPlans.isEmpty)
              Text(
                'Заполни план месяца — даты доходов/расходов и сумма получаемого. Тогда я посчитаю свободные деньги по периодам с учётом кредитов.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else ...[
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Период ${period.label}',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(
                          '${fmt.format(period.dailyAllowance)} $cur / день',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                    ],
                  ),
                ),
                if (loanBurden > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Платёж по кредитам',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text('${fmt.format(loanBurden)} $cur / мес.',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444))),
                    ],
                  ),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: cashflow.timeline
                            .map((d) => d.balance)
                            .fold<double>(0, (a, b) =>
                                math.min(a, b.toDouble())) -
                        20,
                    maxY: cashflow.timeline
                            .map((d) => d.balance)
                            .fold<double>(0, (a, b) =>
                                math.max(a, b.toDouble())) +
                        20,
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (final d in cashflow.timeline)
                            FlSpot(d.dayOfMonth.toDouble(),
                                d.balance.toDouble())
                        ],
                        isCurved: true,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        color: scheme.primary,
                        belowBarData: BarAreaData(
                          show: true,
                          color: scheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final p in cashflow.periods.take(4))
                    Chip(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      label: Text(
                        '${p.label}: ${fmt.format(p.dailyAllowance)} $cur/д',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// =============================================================
/// Loans overview — total balance, principal-vs-interest pie, payoff bar.
/// =============================================================
class LoansOverviewWidget extends ConsumerWidget {
  const LoansOverviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final loans = ref.watch(loansProvider);
    final currency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);

    num convert(num amount, String from, String to) =>
        convertCurrency(
            amount: amount, from: from, to: to, rates: rates);

    if (loans.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.credit_score_outlined),
          title: const Text('Кредиты'),
          subtitle: const Text('Нет активных кредитов'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () => context.go('/loans'),
        ),
      );
    }

    num totalBalance = 0;
    num totalPrincipal = 0;
    num totalProjectedPayoff = 0;
    num totalProjectedInterest = 0;
    num monthly = 0;
    for (final l in loans) {
      if (l.balance <= 0) continue;
      totalBalance += convert(l.balance, l.currency, currency);
      totalPrincipal += convert(l.principal, l.currency, currency);
      monthly += convert(l.monthlyPayment, l.currency, currency);
      final proj = projectLoan(l);
      totalProjectedPayoff +=
          convert(proj.totalPaid, l.currency, currency);
      totalProjectedInterest +=
          convert(proj.totalInterest, l.currency, currency);
    }
    final progress = totalPrincipal == 0
        ? 0.0
        : (1 - totalBalance / totalPrincipal).clamp(0.0, 1.0).toDouble();
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: '', decimalDigits: 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.credit_score_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Кредиты',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('${(progress * 100).round()}%',
                  style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700)),
              IconButton(
                tooltip: 'К кредитам',
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: () => context.go('/loans'),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 26,
                    sections: [
                      PieChartSectionData(
                        value: math.max(
                            totalProjectedPayoff - totalProjectedInterest,
                            1)
                            .toDouble(),
                        color: const Color(0xFF22C55E),
                        title: 'Тело',
                        radius: 28,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11),
                      ),
                      PieChartSectionData(
                        value:
                            math.max(totalProjectedInterest, 1).toDouble(),
                        color: const Color(0xFFEF4444),
                        title: '%',
                        radius: 28,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _kv('Остаток',
                        '${fmt.format(totalBalance)} $currency'),
                    _kv('Платёж/мес.',
                        '${fmt.format(monthly)} $currency'),
                    _kv('Итог по кредиту',
                        '${fmt.format(totalProjectedPayoff)} $currency'),
                    _kv('Переплата',
                        '${fmt.format(totalProjectedInterest)} $currency',
                        valueColor: const Color(0xFFEF4444)),
                  ],
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Expanded(
            child: Text(k,
                style: const TextStyle(fontSize: 12, color: Colors.grey))),
        Text(v,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: valueColor)),
      ]),
    );
  }
}

// Tiny placeholder kept for parity with palette consumers — the actual
// shared palette lives in `dashboard_widgets_v2.dart` (see `_palette` const
// at the top of this file).
List<Color> dashboardChartPalette() => List<Color>.unmodifiable(_palette);

/// Phase 15: Challenges overview — list of active challenges with progress.
class ChallengesOverviewWidget extends ConsumerWidget {
  const ChallengesOverviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(challengesProvider);
    final checkIns = ref.watch(challengeCheckInsProvider);
    final active =
        challenges.where((c) => !c.archived).toList(growable: false);
    if (challenges.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.emoji_events_outlined),
          title: const Text('Челленджи'),
          subtitle:
              const Text('Поставь себе вызов: 30 дней без, 21 день делать'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/challenges'),
        ),
      );
    }
    var done = 0;
    var failed = 0;
    var total = 0;
    final entries = <_ChallengeRow>[];
    for (final c in active) {
      final stats = _quickStats(c, checkIns);
      done += stats.done;
      failed += stats.failed;
      total += c.durationDays;
      entries.add(_ChallengeRow(
        title: c.title,
        icon: c.icon ?? (c.kind == 'avoid' ? '🚫' : '✅'),
        color: c.color != null ? Color(c.color!) : const Color(0xFF6D5CFF),
        fraction: c.durationDays == 0
            ? 0
            : (stats.done / c.durationDays).clamp(0.0, 1.0),
        sub: '${stats.dayIndex} / ${c.durationDays} дн., серия ${stats.streak}',
      ));
    }
    final pending =
        (total - done - failed).clamp(0, double.infinity).toInt();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/challenges'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.emoji_events_outlined),
                const SizedBox(width: 8),
                Text('Челленджи',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text('$done / $total',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ]),
              const SizedBox(height: 8),
              if (active.isNotEmpty)
                SizedBox(
                  height: 80,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 16,
                      sections: [
                        if (done > 0)
                          PieChartSectionData(
                            value: done.toDouble(),
                            color: const Color(0xFF22C55E),
                            title: '',
                            radius: 16,
                          ),
                        if (failed > 0)
                          PieChartSectionData(
                            value: failed.toDouble(),
                            color: const Color(0xFFEF4444),
                            title: '',
                            radius: 16,
                          ),
                        if (pending > 0)
                          PieChartSectionData(
                            value: pending.toDouble(),
                            color: const Color(0xFF94A3B8),
                            title: '',
                            radius: 16,
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              for (final e in entries.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(e.icon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        Text('${(e.fraction * 100).round()}%',
                            style: TextStyle(
                                color: e.color,
                                fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: e.fraction.toDouble(),
                          minHeight: 6,
                          color: e.color,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(e.sub,
                            style:
                                Theme.of(context).textTheme.labelSmall),
                      ),
                    ],
                  ),
                ),
              if (entries.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('+ ещё ${entries.length - 4}',
                      style: Theme.of(context).textTheme.labelSmall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengeRow {
  _ChallengeRow({
    required this.title,
    required this.icon,
    required this.color,
    required this.fraction,
    required this.sub,
  });
  final String title;
  final String icon;
  final Color color;
  final num fraction;
  final String sub;
}

class _ChallengeQuickStats {
  _ChallengeQuickStats({
    required this.dayIndex,
    required this.done,
    required this.failed,
    required this.streak,
  });
  final int dayIndex;
  final int done;
  final int failed;
  final int streak;
}

_ChallengeQuickStats _quickStats(
    Challenge c, List<ChallengeCheckIn> checkIns) {
  final start = DateTime.tryParse(c.startDate);
  if (start == null) {
    return _ChallengeQuickStats(
        dayIndex: 0, done: 0, failed: 0, streak: 0);
  }
  final today = DateTime.now();
  final byDate = <String, ChallengeCheckIn>{
    for (final ci in checkIns.where((x) => x.challengeId == c.id))
      ci.date: ci,
  };
  final dayIndex = (today
              .difference(DateTime(start.year, start.month, start.day))
              .inDays +
          1)
      .clamp(0, c.durationDays);
  var done = 0;
  var failed = 0;
  var streak = 0;
  for (var i = 0; i < c.durationDays; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    if (d.isAfter(today)) break;
    final ci = byDate[DateFormat('yyyy-MM-dd').format(d)];
    if (ci?.status == 'done') {
      done++;
      streak++;
    } else if (ci?.status == 'failed') {
      failed++;
      streak = 0;
    } else if (ci?.status != 'skip') {
      streak = 0;
    }
  }
  return _ChallengeQuickStats(
      dayIndex: dayIndex, done: done, failed: failed, streak: streak);
}

// ════════════════════════════════════════════════════════════════════════════
// Phase 16 — WOW dashboard: rolling daily budget, animated hero, all-goals
// roadmap, yearly habits heatmap, progress dashboard.
//
// These widgets share a few small helpers (palette, gradient cards, animated
// ring painter). Each is fully self-contained — they don't replace existing
// widgets, they complement them.
// ════════════════════════════════════════════════════════════════════════════

const _wowGradientA = LinearGradient(
  colors: [Color(0xFF6D5CFF), Color(0xFF3B82F6), Color(0xFF06B6D4)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
// ignore: unused_element
const _wowGradientB = LinearGradient(
  colors: [Color(0xFF22C55E), Color(0xFF10B981)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
// ignore: unused_element
const _wowGradientC = LinearGradient(
  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final _wowFmt = NumberFormat('#,##0.00', 'ru_RU');
final _wowFmtShort = NumberFormat.compact(locale: 'ru_RU');

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ───────────────────────────────────────────────────────────────────────────
// 1. Rolling Daily Budget widget
//
// Shows yesterday vs today: how much you spent, how much you saved, and how
// much is available right now. The current cycle's `dailyBudget` already
// recalculates daily from real cash on hand, so simply pinning yesterday's
// expense totals against that target gives the user the rolling view they
// asked for: "if I didn't spend yesterday, today I have more".
// ───────────────────────────────────────────────────────────────────────────

class RollingDailyBudgetWidget extends ConsumerWidget {
  const RollingDailyBudgetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(budgetPlannerProvider);
    final txs = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final loans = ref.watch(loansProvider);
    final loanPayments = ref.watch(loanPaymentsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);

    num convert(num amount, String from, String to) =>
        convertCurrency(amount: amount, from: from, to: to, rates: rates);

    // Dashboard is global: span every month's plan instead of the selected
    // tab, so a future month's "once" expense never lands in the current cycle.
    final cycles = computeGlobalBudgetCycles(
      months: store.months,
      transactions: txs,
      accounts: accounts,
      loans: loans,
      loanPayments: loanPayments,
      convert: convert,
      baseCurrency: baseCurrency,
    );

    if (cycles.isEmpty) {
      return _emptyCard(context,
          icon: Icons.account_balance_wallet_outlined,
          title: 'Ежедневный бюджет',
          subtitle: 'Настройте источник дохода в Планировщике бюджета');
    }

    final cycle = cycles.first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    num spentOn(DateTime d) {
      final iso = _iso(d);
      var sum = 0.0;
      for (final t in txs) {
        if (t.type != TransactionType.expense) continue;
        if (!t.date.startsWith(iso)) continue;
        sum += convert(t.amount, accounts
                    .firstWhere((a) => a.id == t.accountId,
                        orElse: () => Account(
                            id: '',
                            name: '',
                            type: AccountType.card,
                            currency: baseCurrency,
                            initialBalance: 0,
                            color: '#000',
                            createdAt: ''))
                    .currency, baseCurrency)
            .toDouble();
      }
      return sum;
    }

    final spentYesterday = spentOn(yesterday).toDouble();
    final spentToday = spentOn(today).toDouble();
    final targetDaily = cycle.dailyBudget.toDouble();
    final savedYesterday = (targetDaily - spentYesterday);
    final todayAvailable =
        (targetDaily + (savedYesterday > 0 ? savedYesterday : 0) - spentToday)
            .clamp(-1e9, 1e9)
            .toDouble();
    final progressToday = targetDaily > 0
        ? (spentToday / (targetDaily + (savedYesterday > 0 ? savedYesterday : 0)))
            .clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(gradient: _wowGradientA),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  const Text('Бюджет на сегодня',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('d MMM', 'ru_RU').format(today),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _AnimatedRing(
                    progress: progressToday,
                    color: progressToday > 0.85
                        ? const Color(0xFFFCA5A5)
                        : Colors.white,
                    trackColor: Colors.white.withAlpha(50),
                    size: 92,
                    strokeWidth: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_wowFmtShort.format(todayAvailable),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const Text('сегодня',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv('Норма / день',
                            '${_wowFmt.format(targetDaily)} $baseCurrency'),
                        const SizedBox(height: 6),
                        _kv('Вчера потратил',
                            '${_wowFmt.format(spentYesterday)} $baseCurrency'),
                        const SizedBox(height: 6),
                        _kv(
                          savedYesterday >= 0
                              ? 'Сэкономил вчера'
                              : 'Перерасход вчера',
                          '${savedYesterday >= 0 ? '+' : ''}${_wowFmt.format(savedYesterday)} $baseCurrency',
                          highlight: savedYesterday >= 0
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFFCA5A5),
                        ),
                        const SizedBox(height: 6),
                        _kv('Сегодня потратил',
                            '${_wowFmt.format(spentToday)} $baseCurrency'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressToday,
                  minHeight: 8,
                  backgroundColor: Colors.white.withAlpha(40),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressToday > 0.85
                        ? const Color(0xFFFCA5A5)
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                savedYesterday > 0
                    ? 'Не потратили вчера → +${_wowFmt.format(savedYesterday)} в копилку сегодня'
                    : (savedYesterday < 0
                        ? 'Перерасход вчера съел часть сегодняшнего бюджета'
                        : 'Бюджет идёт ровно — держим темп!'),
                style: TextStyle(
                    color: Colors.white.withAlpha(220), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {Color? highlight}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(v,
            style: TextStyle(
                color: highlight ?? Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// 2. Finance hero — rotating ring + counters around the budget cycle.
// ───────────────────────────────────────────────────────────────────────────

class FinanceHeroWidget extends ConsumerStatefulWidget {
  const FinanceHeroWidget({super.key});

  @override
  ConsumerState<FinanceHeroWidget> createState() => _FinanceHeroWidgetState();
}

class _FinanceHeroWidgetState extends ConsumerState<FinanceHeroWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(budgetPlannerProvider);
    final config = store.currentMonth;
    final txs = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final loans = ref.watch(loansProvider);
    final loanPayments = ref.watch(loanPaymentsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);
    num convert(num a, String f, String t) =>
        convertCurrency(amount: a, from: f, to: t, rates: rates);
    final facts = computeBudgetFacts(
      monthKey: store.selectedMonthKey,
      transactions: txs,
      accounts: accounts,
      convert: convert,
      baseCurrency: baseCurrency,
      linkedAccountIds: config.linkedAccountIds,
    );
    // Global dashboard: span every month's plan, not just the selected tab.
    final cycles = computeGlobalBudgetCycles(
      months: store.months,
      transactions: txs,
      accounts: accounts,
      loans: loans,
      loanPayments: loanPayments,
      convert: convert,
      baseCurrency: baseCurrency,
    );

    final cycle = cycles.isNotEmpty ? cycles.first : null;
    final dueReminders = ref.watch(upcomingRemindersProvider).length;
    final balance = facts.accountBalance.toDouble();
    final daysLeft = cycle?.daysLeft ?? 0;
    final daily = (cycle?.dailyBudget ?? 0).toDouble();
    final spentPct = cycle != null && cycle.remainingAfterExpenses > 0
        ? (cycle.actualSpent / cycle.remainingAfterExpenses)
            .clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(gradient: _wowGradientA),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (_, __) {
                  return CustomPaint(
                    painter: _RotatingHeroRingPainter(
                      progress: spentPct.toDouble(),
                      rotation: _spin.value * 2 * math.pi,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.savings_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(height: 2),
                          Text(_wowFmtShort.format(daily),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          const Text('в день',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Финансовая магия',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${_wowFmt.format(balance)} $baseCurrency',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  _heroChip('Циклы', '${cycles.length}'),
                  const SizedBox(height: 4),
                  _heroChip('До конца', '$daysLeft дн.'),
                  const SizedBox(height: 4),
                  _heroChip('Кредиты', '${loans.where((l) => l.balance > 0).length}'),
                  if (dueReminders > 0) ...[
                    const SizedBox(height: 4),
                    _heroChip('Скоро оплата', '$dueReminders'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroChip(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(k,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 10)),
          const SizedBox(width: 6),
          Text(v,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RotatingHeroRingPainter extends CustomPainter {
  _RotatingHeroRingPainter({required this.progress, required this.rotation});
  final double progress;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final track = Paint()
      ..color = Colors.white.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFA7F3D0),
          Color(0xFFFFE08A),
          Color(0xFFFFFFFF),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.05, 1.0),
      false,
      arc,
    );
    canvas.restore();

    // tiny sparkle dot
    final dotAngle = -math.pi / 2 + 2 * math.pi * progress + rotation;
    final dot = Offset(center.dx + radius * math.cos(dotAngle),
        center.dy + radius * math.sin(dotAngle));
    canvas.drawCircle(
        dot,
        4,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2));
  }

  @override
  bool shouldRepaint(covariant _RotatingHeroRingPainter old) =>
      old.rotation != rotation || old.progress != progress;
}

// ───────────────────────────────────────────────────────────────────────────
// 3. Goals Roadmap — Gantt of all active goals on a single timeline.
// ───────────────────────────────────────────────────────────────────────────

class GoalsRoadmapWidget extends ConsumerWidget {
  const GoalsRoadmapWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final active = goals
        .where((g) => g.status != GoalStatus.completed && g.deadline != null)
        .toList();
    if (active.isEmpty) {
      return _emptyCard(context,
          icon: Icons.timeline,
          title: 'Дорожная карта целей',
          subtitle: 'Добавьте цели с дедлайнами — увидите весь маршрут.');
    }

    DateTime? parse(String? s) {
      if (s == null) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    final entries = <_RoadmapEntry>[];
    for (final g in active) {
      final start = parse(g.createdAt) ?? DateTime.now();
      final end = parse(g.deadline);
      if (end == null) continue;
      double progress = (g.progress?.toDouble() ?? 0).clamp(0.0, 1.0);
      if (progress == 0 && g.steps.isNotEmpty) {
        progress =
            g.steps.where((s) => s.completed).length / g.steps.length;
      }
      entries.add(_RoadmapEntry(
        title: g.title,
        start: start,
        end: end,
        progress: progress,
        status: g.status,
      ));
    }

    if (entries.isEmpty) {
      return _emptyCard(context,
          icon: Icons.timeline,
          title: 'Дорожная карта целей',
          subtitle: 'Нет целей с корректными датами.');
    }

    final timelineStart = entries
        .map((e) => e.start)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final timelineEnd = entries
        .map((e) => e.end)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, size: 18),
                const SizedBox(width: 6),
                const Text('Дорожная карта целей',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                const Spacer(),
                Text(
                    '${DateFormat('d MMM', 'ru_RU').format(timelineStart)} → ${DateFormat('d MMM yy', 'ru_RU').format(timelineEnd)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            for (final e in entries) ...[
              _RoadmapRow(
                  entry: e,
                  start: timelineStart,
                  end: timelineEnd),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            _RoadmapAxis(start: timelineStart, end: timelineEnd),
          ],
        ),
      ),
    );
  }
}

class _RoadmapEntry {
  _RoadmapEntry({
    required this.title,
    required this.start,
    required this.end,
    required this.progress,
    required this.status,
  });
  final String title;
  final DateTime start;
  final DateTime end;
  final double progress;
  final GoalStatus status;
}

class _RoadmapRow extends StatelessWidget {
  const _RoadmapRow(
      {required this.entry, required this.start, required this.end});
  final _RoadmapEntry entry;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalMs = end.difference(start).inMilliseconds;
    final ratioStart = totalMs <= 0
        ? 0.0
        : entry.start.difference(start).inMilliseconds / totalMs;
    final ratioEnd = totalMs <= 0
        ? 1.0
        : entry.end.difference(start).inMilliseconds / totalMs;
    final color = entry.status == GoalStatus.in_progress
        ? const Color(0xFF6D5CFF)
        : entry.status == GoalStatus.completed
            ? const Color(0xFF22C55E)
            : entry.status == GoalStatus.not_started
                ? const Color(0xFFF59E0B)
                : scheme.primary;

    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final left = (ratioStart.clamp(0.0, 1.0) * width).toDouble();
      final barW = ((ratioEnd - ratioStart).clamp(0.02, 1.0) * width).toDouble();
      return SizedBox(
        height: 32,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 14,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Positioned(
              left: left,
              top: 11,
              child: Container(
                width: barW,
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    color.withAlpha(150),
                    color,
                  ]),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                        color: color.withAlpha(80),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: entry.progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(80),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: left.clamp(0, width - 120).toDouble(),
              top: 0,
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Text(
                '${(entry.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _RoadmapAxis extends StatelessWidget {
  const _RoadmapAxis({required this.start, required this.end});
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mid = DateTime.fromMillisecondsSinceEpoch(
      (start.millisecondsSinceEpoch + end.millisecondsSinceEpoch) ~/ 2,
    );
    final fmt = DateFormat('d MMM', 'ru_RU');
    return Row(
      children: [
        Text(fmt.format(start),
            style: TextStyle(
                fontSize: 10, color: scheme.onSurfaceVariant)),
        Expanded(
          child: Center(
            child: Text(fmt.format(mid),
                style: TextStyle(
                    fontSize: 10, color: scheme.onSurfaceVariant)),
          ),
        ),
        Text(fmt.format(end),
            style: TextStyle(
                fontSize: 10, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// 4. Habits Year Heatmap — GitHub-style annual grid (52 weeks × 7 days).
// ───────────────────────────────────────────────────────────────────────────

class HabitsYearHeatmapWidget extends ConsumerWidget {
  const HabitsYearHeatmapWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final logs = ref.watch(habitLogsProvider);
    if (habits.isEmpty) {
      return _emptyCard(context,
          icon: Icons.grid_on,
          title: 'Карта года',
          subtitle: 'Создайте привычки — здесь появится годовая сетка.');
    }

    final today = DateTime.now();
    final dayCount = 52 * 7; // 52 weeks back from today
    // Anchor on Sunday so the rightmost column aligns with the current week.
    final endAnchor = today.subtract(Duration(days: today.weekday % 7));
    final start = endAnchor.subtract(Duration(days: dayCount - 1));

    // Total good-habit completions per day across all habits.
    final dailyCount = <String, int>{};
    for (final l in logs) {
      if (l.status != HabitLogStatus.done) continue;
      dailyCount.update(l.date, (v) => v + 1, ifAbsent: () => 1);
    }
    final maxCount = dailyCount.values.fold<int>(0, math.max);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_on, size: 18),
                const SizedBox(width: 6),
                const Text('Карта года',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                const Spacer(),
                _legendDot(0),
                _legendDot(0.25),
                _legendDot(0.5),
                _legendDot(0.75),
                _legendDot(1.0),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var w = 0; w < 52; w++)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Column(
                        children: [
                          for (var d = 0; d < 7; d++) ...[
                            () {
                              final dayOffset = w * 7 + d;
                              final day = start.add(Duration(days: dayOffset));
                              if (day.isAfter(today)) {
                                return const SizedBox(
                                    width: 11, height: 11);
                              }
                              final iso = _iso(day);
                              final v = dailyCount[iso] ?? 0;
                              final intensity =
                                  maxCount == 0 ? 0.0 : v / maxCount;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: _intensityColor(intensity),
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }(),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Всего отметок: ${dailyCount.values.fold<int>(0, (a, b) => a + b)} за год · максимум за день: $maxCount',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(double intensity) => Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _intensityColor(intensity),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

Color _intensityColor(double intensity) {
  if (intensity <= 0) return const Color(0xFFE5E7EB);
  if (intensity < 0.25) return const Color(0xFFBBF7D0);
  if (intensity < 0.5) return const Color(0xFF86EFAC);
  if (intensity < 0.75) return const Color(0xFF34D399);
  if (intensity < 1.0) return const Color(0xFF22C55E);
  return const Color(0xFF15803D);
}

// ───────────────────────────────────────────────────────────────────────────
// 5. Progress Dashboard — animated rings for goals + streak chips for habits.
// ───────────────────────────────────────────────────────────────────────────

class ProgressDashboardWidget extends ConsumerStatefulWidget {
  const ProgressDashboardWidget({super.key});

  @override
  ConsumerState<ProgressDashboardWidget> createState() =>
      _ProgressDashboardWidgetState();
}

class _ProgressDashboardWidgetState
    extends ConsumerState<ProgressDashboardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  double _goalProgress(Goal g) {
    if (g.progress != null) return g.progress!.toDouble().clamp(0.0, 1.0);
    if (g.steps.isNotEmpty) {
      return (g.steps.where((s) => s.completed).length / g.steps.length)
          .clamp(0.0, 1.0);
    }
    if (g.targetValue != null && g.targetValue! > 0 && g.currentValue != null) {
      return (g.currentValue! / g.targetValue!).toDouble().clamp(0.0, 1.0);
    }
    return 0;
  }

  int _habitStreak(Habit h, List<HabitLog> logs) {
    final byDate = <String, HabitLog>{
      for (final l in logs.where((l) => l.habitId == h.id)) l.date: l,
    };
    var streak = 0;
    var day = DateTime.now();
    while (true) {
      final iso = _iso(day);
      final log = byDate[iso];
      if (log != null && log.status == HabitLogStatus.done) {
        streak++;
        day = day.subtract(const Duration(days: 1));
        if (streak > 366) break;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref
        .watch(goalsProvider)
        .where((g) => g.status != GoalStatus.completed)
        .toList();
    final habits = ref.watch(habitsProvider);
    final logs = ref.watch(habitLogsProvider);

    if (goals.isEmpty && habits.isEmpty) {
      return _emptyCard(context,
          icon: Icons.show_chart,
          title: 'Прогресс-дашборд',
          subtitle: 'Добавьте цели или привычки — увидите кольца и стрики.');
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.show_chart, size: 18),
                SizedBox(width: 6),
                Text('Прогресс-дашборд',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            if (goals.isNotEmpty) ...[
              const Text('Цели',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: goals.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final g = goals[i];
                    final p = _goalProgress(g);
                    return SizedBox(
                      width: 78,
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _anim,
                            builder: (_, __) {
                              return _AnimatedRing(
                                progress: p * _anim.value,
                                color: _palette[i % _palette.length],
                                trackColor: _palette[i % _palette.length]
                                    .withAlpha(40),
                                size: 60,
                                strokeWidth: 6,
                                child: Text(
                                  '${(p * 100 * _anim.value).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          _palette[i % _palette.length]),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            g.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (habits.isNotEmpty) ...[
              const Text('Стрики привычек',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < habits.length; i++)
                    _StreakChip(
                      title: habits[i].title,
                      streak: _habitStreak(habits[i], logs),
                      color: _palette[i % _palette.length],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({
    required this.title,
    required this.streak,
    required this.color,
  });
  final String title;
  final int streak;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(40), color.withAlpha(15)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department,
              size: 14, color: streak > 0 ? color : Colors.grey),
          const SizedBox(width: 4),
          Text(title,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withAlpha(60),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$streak',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Shared helpers
// ───────────────────────────────────────────────────────────────────────────

class _AnimatedRing extends StatelessWidget {
  const _AnimatedRing({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.size,
    required this.strokeWidth,
    required this.child,
  });
  final double progress;
  final Color color;
  final Color trackColor;
  final double size;
  final double strokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          color: color,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}

Widget _emptyCard(BuildContext context,
    {required IconData icon,
    required String title,
    required String subtitle}) {
  final scheme = Theme.of(context).colorScheme;
  return Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(icon, size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Suppress unused-import lint when a model file is only referenced via
/// downstream code paths (kept here intentionally because some widgets in
/// this file rely on the model types being visible to other files that
/// import this module via `dashboard_widgets_v2.dart`).
// ignore: unused_element
void _wow_unused_imports_anchor(BudgetCycle a, IncomeSource b, PlannedExpense c) {}

/// Compact dashboard widget that links to the Claude chat. We don't load
/// conversation history here — just a one-tap shortcut with a few preset
/// prompts to make the entrypoint discoverable.
class ClaudeChatLauncherWidget extends StatelessWidget {
  const ClaudeChatLauncherWidget({super.key});

  static const _quickPrompts = <_QuickPrompt>[
    _QuickPrompt('План тренировок', 'Составь план тренировок на неделю.'),
    _QuickPrompt('Бюджет', 'Помоги сократить расходы на 10%.'),
    _QuickPrompt('Привычки', 'Подбери 3 новые полезные привычки.'),
    _QuickPrompt('Задачи',
        'Помоги разложить большую цель на задачи по SMART.'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/chat'),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                scheme.tertiaryContainer,
                scheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome,
                        size: 20, color: scheme.onPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Claude чат',
                            style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        Text('Личный коуч по финансам, спорту и привычкам',
                            style: TextStyle(
                                color: scheme.onPrimaryContainer
                                    .withValues(alpha: 0.85),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 14, color: scheme.onPrimaryContainer),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in _quickPrompts)
                    InputChip(
                      label: Text(p.label),
                      onPressed: () => context.go('/chat'),
                      backgroundColor: scheme.surface.withValues(alpha: 0.55),
                      side: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.2)),
                      labelStyle: TextStyle(
                          color: scheme.onSurface, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPrompt {
  const _QuickPrompt(this.label, this.prompt);
  final String label;
  // The full prompt is intentionally unused for now — the launcher is a
  // shortcut into chat. Kept for a future "prefill" wiring.
  // ignore: unused_element
  final String prompt;
}
