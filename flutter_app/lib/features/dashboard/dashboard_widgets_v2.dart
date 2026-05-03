import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../models/goal.dart';
import '../../models/misc.dart';
import '../../services/finance_calc.dart';
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
